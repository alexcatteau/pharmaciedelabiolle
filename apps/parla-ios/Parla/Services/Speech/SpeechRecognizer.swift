import AVFoundation
import Observation
import Speech

/// Transcription en direct de la parole de l'utilisateur.
///
/// Deux partis pris qui comptent pour le produit :
/// 1. **Reconnaissance sur l'appareil quand elle est disponible** — c'est gratuit,
///    ça marche dans le métro, et la voix de l'utilisateur ne quitte pas le téléphone.
/// 2. **Détection de fin de tour par le silence** — l'utilisateur ne doit pas avoir
///    à appuyer sur un bouton pour finir de parler. Un bouton « j'ai fini » ramène
///    la posture d'exercice ; le silence ramène celle d'une conversation.
@MainActor
@Observable
final class SpeechRecognizer {
    enum Authorization {
        case unknown, granted, denied, restricted
    }

    private(set) var transcript: String = ""
    private(set) var isRecording: Bool = false
    private(set) var authorization: Authorization = .unknown
    /// Niveau sonore normalisé 0→1, pour l'onde animée pendant que l'on parle.
    private(set) var audioLevel: Float = 0
    private(set) var lastError: String?

    /// Appelé quand l'utilisateur s'est tu assez longtemps pour qu'on considère
    /// son tour terminé.
    var onTurnEnded: ((String) -> Void)?

    /// Durée de silence qui clôt un tour. 1,4 s : assez long pour laisser
    /// chercher un mot, assez court pour que l'échange reste vivant.
    var silenceThreshold: TimeInterval = 1.4

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    private var lastSpeechAt: Date?
    private var silenceTimer: Timer?
    /// Instant où le micro a été ouvert — sert à mesurer la latence avant le
    /// premier mot, la métrique la plus parlante du débrief.
    private var openedMicAt: Date?
    private(set) var latencyBeforeFirstWord: TimeInterval?

    func configure(for language: TargetLanguage) {
        recognizer = SFSpeechRecognizer(locale: language.recognitionLocale)
    }

    // MARK: - Autorisations

    func requestAuthorization() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        switch speechStatus {
        case .authorized:
            authorization = micGranted ? .granted : .denied
        case .denied:
            authorization = .denied
        case .restricted:
            authorization = .restricted
        case .notDetermined:
            authorization = .unknown
        @unknown default:
            authorization = .unknown
        }
    }

    // MARK: - Cycle d'enregistrement

    func startListening() {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else {
            lastError = "La reconnaissance vocale n'est pas disponible pour cette langue."
            return
        }

        transcript = ""
        latencyBeforeFirstWord = nil
        lastSpeechAt = nil
        openedMicAt = Date()
        lastError = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Quand le modèle embarqué existe pour cette langue, on le préfère :
        // pas de réseau, pas de latence, pas d'audio qui sort du téléphone.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = Self.normalizedPower(of: buffer)
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty {
                        if self.latencyBeforeFirstWord == nil, let openedAt = self.openedMicAt {
                            self.latencyBeforeFirstWord = Date().timeIntervalSince(openedAt)
                        }
                        if text != self.transcript {
                            self.transcript = text
                            self.lastSpeechAt = Date()
                        }
                    }
                }
                if error != nil {
                    // Une erreur de reconnaissance en fin de tour est normale
                    // (le flux est coupé) : on ne l'affiche pas à l'utilisateur.
                    self.finishTurn()
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
            isRecording = true
            startSilenceWatchdog()
        } catch {
            lastError = "Impossible de démarrer le micro : \(error.localizedDescription)"
            cleanup()
        }
    }

    /// Arrêt manuel (l'utilisateur raccroche, ou appuie sur « j'ai fini »).
    func stopListening() {
        guard isRecording else { return }
        finishTurn()
    }

    private func startSilenceWatchdog() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                // Tant que rien n'a été dit, on n'arme pas le compte à rebours :
                // sinon on couperait la parole à quelqu'un qui réfléchit encore.
                guard let lastSpeechAt = self.lastSpeechAt else { return }
                if Date().timeIntervalSince(lastSpeechAt) >= self.silenceThreshold {
                    self.finishTurn()
                }
            }
        }
    }

    private func finishTurn() {
        let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanup()
        if !finalText.isEmpty {
            onTurnEnded?(finalText)
        }
    }

    private func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        audioLevel = 0
    }

    /// RMS du buffer, ramené sur 0→1 par une courbe logarithmique : l'oreille
    /// et l'œil attendent une réponse logarithmique, pas linéaire.
    private nonisolated static func normalizedPower(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(count))
        let decibels = 20 * log10(max(rms, 1e-7))
        // -50 dB = silence, 0 dB = saturation.
        return max(0, min(1, (decibels + 50) / 50))
    }
}
