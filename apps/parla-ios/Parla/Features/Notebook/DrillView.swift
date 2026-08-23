import SwiftUI

/// La révision se fait **à l'oral, et seulement à l'oral**.
///
/// C'est le point le plus important de tout le module : un QCM mesure la
/// reconnaissance, or notre utilisateur est déjà excellent en reconnaissance.
/// Le seul geste qui compte est de produire le son, sous une contrainte de temps,
/// sans avoir la réponse sous les yeux.
@MainActor
struct DrillView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var recognizer = SpeechRecognizer()
    @State private var queue: [ErrorCard] = []
    @State private var index = 0
    @State private var phase: DrillPhase = .prompt
    @State private var spokenText = ""
    @State private var countdown = 6

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum DrillPhase {
        case prompt      // l'amorce est affichée, le compte à rebours court
        case speaking    // le micro est ouvert
        case reveal      // la cible est révélée, auto-évaluation
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            if phase == .done || queue.isEmpty {
                completion
            } else {
                progressHeader
                Spacer()
                content
                Spacer()
                controls
            }
        }
        .padding(Layout.gutter)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setup)
        .onDisappear { recognizer.stopListening() }
        .onReceive(ticker) { _ in tick() }
    }

    // MARK: - Sous-vues

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceRaised)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: geometry.size.width * Double(index) / Double(max(queue.count, 1)))
                }
            }
            .frame(height: 3)

            Text("\(index + 1) / \(queue.count)")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkTertiary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let card = currentCard {
            VStack(spacing: 26) {
                Text("Dis-le en \(card.language.displayName.lowercased())")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)

                Text(card.prompt)
                    .font(Typography.display(26))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                switch phase {
                case .prompt:
                    // Compte à rebours visible : la contrainte de temps est le
                    // seul moyen de tester l'accès automatique au lexique plutôt
                    // que la capacité à reconstruire une phrase.
                    Text("\(countdown)")
                        .font(Typography.metric(52))
                        .foregroundStyle(countdown <= 2 ? Palette.accent : Palette.inkTertiary)
                        .monospacedDigit()

                case .speaking:
                    VStack(spacing: 14) {
                        VoiceWave(level: recognizer.audioLevel).frame(height: 46)
                        Text(recognizer.transcript.isEmpty ? "…" : recognizer.transcript)
                            .font(Typography.body)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }

                case .reveal:
                    VStack(spacing: 14) {
                        Text(card.target)
                            .font(Typography.title(24))
                            .foregroundStyle(Palette.accent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if !spokenText.isEmpty {
                            Text("tu as dit : \(spokenText)")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkTertiary)
                                .multilineTextAlignment(.center)
                        }

                        Text(card.explanation)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                case .done:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .prompt:
            SecondaryButton(title: "Je suis prêt", icon: "mic.fill") { startSpeaking() }
        case .speaking:
            SecondaryButton(title: "J'ai fini") { finishSpeaking() }
        case .reveal:
            VStack(spacing: 10) {
                Text("C'était comment ?")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
                HStack(spacing: 10) {
                    ForEach(RecallQuality.allCases) { quality in
                        Button {
                            grade(quality)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: quality.icon)
                                Text(quality.label).font(.system(size: 11))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Palette.ink)
                            .background(Palette.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .done:
            EmptyView()
        }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(Palette.success)
            Text("Carnet à jour")
                .font(Typography.title(22))
                .foregroundStyle(Palette.ink)
            Text("Les tournures que tu as bloquées reviendront tout à l'heure. Les autres, dans quelques jours.")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Fermer") { dismiss() }
        }
    }

    // MARK: - Logique

    private var currentCard: ErrorCard? {
        guard index < queue.count else { return nil }
        return queue[index]
    }

    private func setup() {
        queue = appState.dueCards
        guard let language = appState.profile?.language else { return }
        recognizer.configure(for: language)
        recognizer.onTurnEnded = { text in
            spokenText = text
            phase = .reveal
        }
        Task { await recognizer.requestAuthorization() }
    }

    private func tick() {
        guard phase == .prompt else { return }
        if countdown > 0 {
            countdown -= 1
        } else {
            startSpeaking()
        }
    }

    private func startSpeaking() {
        guard phase == .prompt else { return }
        phase = .speaking
        try? AudioSessionManager.activateConversationMode()
        recognizer.startListening()
    }

    private func finishSpeaking() {
        recognizer.stopListening()
        spokenText = recognizer.transcript
        phase = .reveal
    }

    private func grade(_ quality: RecallQuality) {
        if let card = currentCard {
            appState.review(card: card, quality: quality)
        }
        spokenText = ""
        countdown = 6
        if index + 1 < queue.count {
            index += 1
            phase = .prompt
        } else {
            phase = .done
            AudioSessionManager.deactivate()
        }
    }
}
