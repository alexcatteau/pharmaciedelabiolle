import Foundation

/// Une carte de révision née d'une erreur **que l'utilisateur a réellement faite**.
///
/// C'est la deuxième rupture avec Duolingo : le contenu de révision n'est pas un
/// deck générique, c'est le corpus des ratés personnels. Réviser « la mela » quand
/// on sait déjà dire « pomme » est du temps perdu ; réviser la tournure qu'on a
/// contournée hier soir ne l'est pas.
struct ErrorCard: Codable, Identifiable, Hashable {
    let id: UUID
    let language: TargetLanguage

    /// Ce qu'il faut réussir à produire.
    let target: String
    /// L'amorce en français.
    let prompt: String
    /// Ce que la personne avait dit à l'origine. Affiché seulement après la réponse.
    let originalMistake: String?
    let explanation: String
    let kind: Correction.Kind

    /// D'où ça vient — permet de rejouer le contexte.
    let sourceSessionID: UUID?
    let createdAt: Date

    // --- Ordonnancement SM-2 simplifié ---
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var dueDate: Date

    /// Une carte n'est « acquise » que si elle a été **dite à voix haute**
    /// correctement, pas reconnue dans un QCM.
    var spokenSuccesses: Int

    var isDue: Bool { dueDate <= Date() }

    init(
        id: UUID = UUID(),
        language: TargetLanguage,
        target: String,
        prompt: String,
        originalMistake: String? = nil,
        explanation: String,
        kind: Correction.Kind,
        sourceSessionID: UUID? = nil,
        createdAt: Date = Date(),
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        repetitions: Int = 0,
        dueDate: Date = Date(),
        spokenSuccesses: Int = 0
    ) {
        self.id = id
        self.language = language
        self.target = target
        self.prompt = prompt
        self.originalMistake = originalMistake
        self.explanation = explanation
        self.kind = kind
        self.sourceSessionID = sourceSessionID
        self.createdAt = createdAt
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueDate = dueDate
        self.spokenSuccesses = spokenSuccesses
    }

    static func from(correction: Correction, language: TargetLanguage, sessionID: UUID?) -> ErrorCard {
        ErrorCard(
            language: language,
            target: correction.native,
            prompt: correction.explanation,
            originalMistake: correction.said,
            explanation: correction.explanation,
            kind: correction.kind,
            sourceSessionID: sessionID
        )
    }

    static func from(avoided: AvoidedExpression, language: TargetLanguage, sessionID: UUID?) -> ErrorCard {
        ErrorCard(
            language: language,
            target: avoided.native,
            prompt: avoided.intent,
            originalMistake: avoided.workaround,
            explanation: "Tu as contourné cette idée pendant la conversation.",
            kind: .idiom,
            sourceSessionID: sessionID
        )
    }
}

/// Qualité de rappel, telle que l'utilisateur l'auto-évalue après avoir parlé.
enum RecallQuality: Int, Codable, CaseIterable, Identifiable {
    case blocked = 0
    case hesitant = 3
    case fluent = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .blocked: "J'ai bloqué"
        case .hesitant: "Avec du mal"
        case .fluent: "Direct"
        }
    }

    var icon: String {
        switch self {
        case .blocked: "xmark"
        case .hesitant: "tortoise.fill"
        case .fluent: "bolt.fill"
        }
    }
}
