import Foundation

/// Un tour de parole. On garde le texte **et** les métriques temporelles :
/// le débrief a besoin de savoir combien de temps la personne a hésité avant
/// de répondre, pas seulement ce qu'elle a fini par dire.
struct ConversationTurn: Codable, Identifiable, Hashable {
    enum Speaker: String, Codable, Hashable {
        case user
        case interlocutor
    }

    let id: UUID
    let speaker: Speaker
    var text: String

    /// Temps entre la fin du tour précédent et le premier mot prononcé.
    /// Le meilleur indicateur unique du blocage à l'oral.
    var latencyBeforeSpeaking: TimeInterval?

    /// Durée effective de la prise de parole.
    var duration: TimeInterval?

    let timestamp: Date

    init(
        id: UUID = UUID(),
        speaker: Speaker,
        text: String,
        latencyBeforeSpeaking: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.latencyBeforeSpeaking = latencyBeforeSpeaking
        self.duration = duration
        self.timestamp = timestamp
    }
}

/// Une session complète, telle qu'elle est archivée après le raccrochage.
struct ConversationSession: Codable, Identifiable, Hashable {
    let id: UUID
    let scenarioID: String
    let language: TargetLanguage
    let startedAt: Date
    var endedAt: Date?
    var turns: [ConversationTurn]
    var debrief: Debrief?

    /// Nombre de fois où l'utilisateur a demandé de l'aide (bouton « je bloque »).
    /// On ne le punit pas : on le mesure, parce que sa décroissance est la vraie
    /// courbe de progression.
    var rescueCount: Int

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var userTurns: [ConversationTurn] {
        turns.filter { $0.speaker == .user }
    }

    init(
        id: UUID = UUID(),
        scenarioID: String,
        language: TargetLanguage,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        turns: [ConversationTurn] = [],
        debrief: Debrief? = nil,
        rescueCount: Int = 0
    ) {
        self.id = id
        self.scenarioID = scenarioID
        self.language = language
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.turns = turns
        self.debrief = debrief
        self.rescueCount = rescueCount
    }
}

/// Ce que l'écran de conversation affiche à un instant t.
enum ConversationPhase: Equatable {
    case idle
    case connecting
    /// L'interlocuteur parle (synthèse vocale en cours).
    case interlocutorSpeaking
    /// À l'utilisateur. C'est la phase qui compte : le micro est ouvert.
    case listening
    /// L'utilisateur a fini, on attend la réponse du modèle.
    case thinking
    case ended
    case failed(String)
}
