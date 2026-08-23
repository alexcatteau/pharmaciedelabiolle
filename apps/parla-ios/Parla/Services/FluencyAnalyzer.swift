import Foundation

/// Calcule les métriques de fluidité **sur l'appareil**, à partir des tours.
/// Aucun appel réseau : ce sont des mesures, pas des jugements, et le modèle
/// n'a rien à apporter ici.
enum FluencyAnalyzer {
    static func metrics(for session: ConversationSession) -> FluencyMetrics {
        let userTurns = session.userTurns

        let totalWords = userTurns.reduce(0) { $0 + wordCount($1.text) }
        let totalSpeaking = userTurns.reduce(0.0) { $0 + ($1.duration ?? 0) }
        let latencies = userTurns.compactMap(\.latencyBeforeSpeaking)

        let wordsPerMinute = totalSpeaking > 0 ? Double(totalWords) / (totalSpeaking / 60) : 0

        return FluencyMetrics(
            wordsPerMinute: wordsPerMinute,
            averageLatency: latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count),
            longestLatency: latencies.max() ?? 0,
            totalSpeakingTime: totalSpeaking,
            turnCount: userTurns.count,
            rescueCount: session.rescueCount,
            averageWordsPerTurn: userTurns.isEmpty ? 0 : Double(totalWords) / Double(userTurns.count)
        )
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Repère naturel de débit par langue, pour situer l'utilisateur sans le
    /// comparer à une moyenne d'app.
    static func nativeReferenceWPM(for language: TargetLanguage) -> Double {
        switch language {
        case .italian: 145
        case .spanish: 155
        case .portuguese: 140
        case .arabic: 130
        case .turkish: 135
        case .polish: 130
        }
    }
}
