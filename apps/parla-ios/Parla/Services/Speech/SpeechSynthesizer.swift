import AVFoundation
import Observation

/// Voix de l'interlocuteur.
///
/// Le point non-évident : on **découpe la réponse en phrases au fil du streaming**
/// et on commence à parler dès la première phrase complète. Attendre la réponse
/// entière ajoute une à deux secondes de blanc à chaque tour, et c'est
/// exactement ce qui fait qu'un dialogue synthétique sonne faux.
@MainActor
@Observable
final class SpeechSynthesizer {
    private(set) var isSpeaking: Bool = false
    /// Ce qui est en train d'être prononcé — affiché en sous-titre optionnel.
    private(set) var spokenSoFar: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechSynthesizerDelegate()
    private var pendingBuffer: String = ""

    init() {
        synthesizer.delegate = delegate
        delegate.onStart = { [weak self] in self?.isSpeaking = true }
        delegate.onFinish = { [weak self] in
            guard let self else { return }
            // On ne repasse à « silencieux » qu'une fois la file réellement vide.
            self.isSpeaking = self.synthesizer.isSpeaking
            if !self.isSpeaking { self.onFinishedSpeaking?() }
        }
    }

    /// Appelé quand toute la file a été prononcée : c'est le signal pour
    /// rouvrir le micro.
    var onFinishedSpeaking: (() -> Void)?

    // MARK: - API

    func speak(_ text: String, language: TargetLanguage, rate: Double = 1.0) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        spokenSoFar += (spokenSoFar.isEmpty ? "" : " ") + trimmed
        synthesizer.speak(makeUtterance(trimmed, language: language, rate: rate))
        isSpeaking = true
    }

    /// À appeler à chaque fragment reçu du streaming.
    /// Émet vers la synthèse dès qu'une phrase complète est disponible.
    func feed(_ chunk: String, language: TargetLanguage, rate: Double = 1.0) {
        pendingBuffer += chunk
        while let sentence = Self.extractSentence(from: &pendingBuffer) {
            speak(sentence, language: language, rate: rate)
        }
    }

    /// À appeler à la fin du streaming : vide ce qui reste, même sans ponctuation.
    func flush(language: TargetLanguage, rate: Double = 1.0) {
        let rest = pendingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingBuffer = ""
        if !rest.isEmpty { speak(rest, language: language, rate: rate) }
    }

    func stop() {
        pendingBuffer = ""
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func reset() {
        stop()
        spokenSoFar = ""
    }

    // MARK: - Interne

    private func makeUtterance(_ text: String, language: TargetLanguage, rate: Double) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: language)
        // `AVSpeechUtteranceDefaultSpeechRate` vaut 0.5 : on module autour.
        utterance.rate = Float(Double(AVSpeechUtteranceDefaultSpeechRate) * rate)
        utterance.pitchMultiplier = 1.0
        // Une micro-pause avant chaque phrase : sans elle, deux phrases
        // enchaînées sonnent comme une seule coulée robotique.
        utterance.preUtteranceDelay = 0.08
        return utterance
    }

    /// Préfère une voix « premium »/« enhanced » quand l'utilisateur l'a
    /// téléchargée : l'écart de naturel avec la voix compacte est énorme, et
    /// c'est gratuit.
    private static func bestVoice(for language: TargetLanguage) -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language.voiceLocaleIdentifier.prefix(2))
        }
        let ranked = candidates.sorted { lhs, rhs in
            quality(lhs.quality) > quality(rhs.quality)
        }
        return ranked.first ?? AVSpeechSynthesisVoice(language: language.voiceLocaleIdentifier)
    }

    private static func quality(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: 3
        case .enhanced: 2
        default: 1
        }
    }

    /// Extrait la première phrase complète du tampon, si elle existe.
    private static func extractSentence(from buffer: inout String) -> String? {
        let terminators: Set<Character> = [".", "!", "?", "…", "؟", "。"]
        guard let index = buffer.firstIndex(where: { terminators.contains($0) }) else { return nil }
        let sentence = String(buffer[...index]).trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = String(buffer[buffer.index(after: index)...])
        return sentence.isEmpty ? nil : sentence
    }
}

/// Le délégué est un type distinct, hors de la classe `@MainActor` : on évite de
/// faire cohabiter `@Observable`, l'isolation d'acteur et l'héritage `NSObject`
/// sur le même type — c'est une source classique de diagnostics obscurs.
private final class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let handler = onStart
        Task { @MainActor in handler?() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let handler = onFinish
        Task { @MainActor in handler?() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let handler = onFinish
        Task { @MainActor in handler?() }
    }
}
