import Foundation
import Observation

/// Chef d'orchestre d'une conversation : enchaîne synthèse → micro → modèle → synthèse.
///
/// La boucle est volontairement **mains libres**. Dès que l'interlocuteur a fini de
/// parler, le micro s'ouvre tout seul ; dès que l'utilisateur se tait, son tour est
/// envoyé. Aucun bouton à presser pour parler : c'est ce qui fait la différence
/// entre « je fais un exercice » et « je suis en conversation », et c'est
/// précisément la bascule dont notre utilisateur a besoin.
@MainActor
@Observable
final class ConversationEngine {
    private(set) var phase: ConversationPhase = .idle
    private(set) var turns: [ConversationTurn] = []
    /// Le texte de l'interlocuteur au fil de son arrivée (sous-titres optionnels).
    private(set) var streamingReply: String = ""
    private(set) var rescueSuggestions: [String] = []
    private(set) var rescueCount: Int = 0
    private(set) var errorMessage: String?

    let scenario: Scenario
    let profile: UserProfile
    let recognizer: SpeechRecognizer
    let synthesizer: SpeechSynthesizer

    private let client: AnthropicClient
    private let startedAt = Date()
    private var replyTask: Task<Void, Never>?
    /// Instant où l'interlocuteur a fini de parler — origine de la mesure de latence.
    private var micOpenedAt: Date?

    init(
        scenario: Scenario,
        profile: UserProfile,
        client: AnthropicClient
    ) {
        self.scenario = scenario
        self.profile = profile
        self.client = client
        self.recognizer = SpeechRecognizer()
        self.synthesizer = SpeechSynthesizer()

        recognizer.configure(for: profile.language)
        recognizer.onTurnEnded = { [weak self] text in
            self?.handleUserTurn(text)
        }
        synthesizer.onFinishedSpeaking = { [weak self] in
            self?.openMicrophone()
        }
    }

    // MARK: - Cycle de vie

    func start() async {
        phase = .connecting
        await recognizer.requestAuthorization()

        guard recognizer.authorization == .granted else {
            phase = .failed("Parla a besoin du micro et de la reconnaissance vocale pour fonctionner. Active-les dans Réglages.")
            return
        }

        do {
            try AudioSessionManager.activateConversationMode()
        } catch {
            phase = .failed("Impossible d'ouvrir l'audio : \(error.localizedDescription)")
            return
        }

        requestInterlocutorTurn()
    }

    func end() -> ConversationSession {
        replyTask?.cancel()
        recognizer.stopListening()
        synthesizer.stop()
        AudioSessionManager.deactivate()
        phase = .ended

        return ConversationSession(
            scenarioID: scenario.id,
            language: profile.language,
            startedAt: startedAt,
            endedAt: Date(),
            turns: turns,
            rescueCount: rescueCount
        )
    }

    // MARK: - Tour de l'interlocuteur

    private func requestInterlocutorTurn() {
        replyTask?.cancel()
        streamingReply = ""
        phase = .interlocutorSpeaking

        let system = Prompts.interlocutor(scenario: scenario, profile: profile)
        let messages = apiMessages()
        let rate = scenario.interlocutor.speechRate

        replyTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await chunk in client.streamReply(system: system, messages: messages) {
                    if Task.isCancelled { return }
                    self.streamingReply += chunk
                    // On parle dès la première phrase complète plutôt que
                    // d'attendre la fin : c'est ce qui supprime le blanc entre
                    // les tours et rend l'échange crédible.
                    self.synthesizer.feed(chunk, language: self.profile.language, rate: rate)
                }
                self.synthesizer.flush(language: self.profile.language, rate: rate)

                let text = self.streamingReply.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    self.turns.append(ConversationTurn(speaker: .interlocutor, text: text))
                }
                // Le micro ne s'ouvre pas ici : on attend que la voix ait
                // réellement fini, sinon l'app s'enregistre elle-même.
                if !self.synthesizer.isSpeaking {
                    self.openMicrophone()
                }
            } catch is CancellationError {
                return
            } catch {
                self.phase = .failed(error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Tour de l'utilisateur

    private func openMicrophone() {
        guard phase != .ended, phase != .listening else { return }
        rescueSuggestions = []
        micOpenedAt = Date()
        phase = .listening
        recognizer.startListening()
    }

    private func handleUserTurn(_ text: String) {
        guard phase == .listening else { return }

        let now = Date()
        let latency = recognizer.latencyBeforeFirstWord
        // Durée de parole = temps micro ouvert moins le temps d'hésitation initial.
        let duration = micOpenedAt.map { now.timeIntervalSince($0) - (latency ?? 0) }

        turns.append(
            ConversationTurn(
                speaker: .user,
                text: text,
                latencyBeforeSpeaking: latency,
                duration: duration.map { max(0.5, $0) }
            )
        )

        phase = .thinking
        requestInterlocutorTurn()
    }

    /// Bouton « je bloque ». Volontairement sans pénalité affichée : le but est
    /// que la personne continue de parler, pas qu'elle se sente en examen.
    /// On compte quand même les usages, parce que leur décroissance est la
    /// meilleure preuve de progrès qu'on puisse lui montrer.
    func requestRescue() {
        guard let lastLine = turns.last(where: { $0.speaker == .interlocutor })?.text else { return }
        rescueCount += 1

        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await client.complete(
                    system: Prompts.rescue(
                        scenario: scenario,
                        profile: profile,
                        lastInterlocutorLine: lastLine
                    ),
                    messages: [.user("Donne les deux amorces.")]
                )
                self.rescueSuggestions = response
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } catch {
                self.rescueSuggestions = ["Reformule avec les mots que tu as. Même approximatif, dis-le."]
            }
        }
    }

    /// Coupe l'interlocuteur pour reprendre la parole — comme dans une vraie
    /// conversation. Sans ça, l'utilisateur attend poliment et perd le fil.
    func interrupt() {
        replyTask?.cancel()
        synthesizer.stop()
        openMicrophone()
    }

    // MARK: - Historique

    private func apiMessages() -> [APIMessage] {
        // L'API exige que l'historique commence par un tour `user` ; or ici c'est
        // l'interlocuteur qui ouvre la scène. On amorce donc avec une didascalie.
        var messages: [APIMessage] = [.user("[La scène commence. Prends la parole en premier.]")]

        for turn in turns {
            switch turn.speaker {
            case .interlocutor: messages.append(.assistant(turn.text))
            case .user: messages.append(.user(turn.text))
            }
        }

        // Si le dernier tour est celui de l'interlocuteur, on n'a rien à envoyer :
        // ce cas n'arrive que sur une reprise après erreur.
        if messages.last?.role == "assistant" {
            messages.append(.user("[Silence. Relance la conversation.]"))
        }

        return messages
    }
}
