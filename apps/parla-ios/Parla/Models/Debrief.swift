import Foundation

/// Le débrief est le vrai produit de Parla.
///
/// Pendant la conversation on ne corrige **jamais** : corriger en direct réinstalle
/// exactement la peur de mal dire qu'on essaie de désamorcer, et casse le seul
/// mécanisme qui fait progresser à l'oral (parler quand même, malgré l'erreur).
/// Tout arrive ici, après avoir raccroché.
struct Debrief: Codable, Hashable {
    /// A-t-elle obtenu ce qu'elle voulait ? Question binaire, posée d'abord,
    /// parce que « tu t'es fait comprendre » prime sur « tu as fait 4 fautes ».
    let objectiveAchieved: Bool

    /// Deux ou trois phrases en français. Le ton est celui d'un pote bilingue,
    /// pas d'un correcteur : direct, mais jamais décourageant.
    let summary: String

    /// Ce qui a marché. Toujours renseigné, toujours affiché en premier.
    let strengths: [String]

    /// Les corrections, triées par gravité réelle (« est-ce que ça t'a coûté
    /// d'être compris ? »), pas par type grammatical.
    let corrections: [Correction]

    /// Le cœur du dispositif pour notre profil : ce que la personne a **voulu**
    /// dire mais a contourné parce qu'elle ne savait pas le dire.
    /// C'est invisible dans une correction classique, et c'est pourtant là que
    /// se situe tout son plafond.
    let avoidedExpressions: [AvoidedExpression]

    /// Estimation du niveau de production sur cette session seule.
    let productionEstimate: CEFRLevel

    /// Une seule chose à travailler d'ici la prochaine session.
    let nextFocus: String

    /// Métriques calculées sur l'appareil, pas par le modèle.
    var metrics: FluencyMetrics?
}

/// Une correction est toujours ternaire : ce que tu as dit → ce qu'un natif aurait
/// dit → pourquoi. Le « pourquoi » est en français et tient en une phrase.
struct Correction: Codable, Hashable, Identifiable {
    var id: String { said + "→" + native }

    let said: String
    let native: String
    let explanation: String
    let severity: Severity
    let kind: Kind

    enum Severity: String, Codable, Hashable, CaseIterable {
        /// A empêché d'être compris, ou a changé le sens.
        case blocking
        /// Compris, mais on entend immédiatement l'étranger.
        case awkward
        /// Détail. Affiché replié.
        case minor

        var label: String {
            switch self {
            case .blocking: "Ça bloque"
            case .awkward: "Ça sonne étranger"
            case .minor: "Détail"
            }
        }

        var rank: Int {
            switch self {
            case .blocking: 0
            case .awkward: 1
            case .minor: 2
            }
        }
    }

    enum Kind: String, Codable, Hashable, CaseIterable {
        case grammar
        case vocabulary
        /// Calque du français — l'erreur signature de notre utilisateur.
        case calque
        case register
        case idiom

        var label: String {
            switch self {
            case .grammar: "Grammaire"
            case .vocabulary: "Vocabulaire"
            case .calque: "Calque du français"
            case .register: "Registre"
            case .idiom: "Tournure"
            }
        }
    }
}

/// « Tu as dit *c'est difficile* — mais tu cherchais *ça me prend la tête*. »
struct AvoidedExpression: Codable, Hashable, Identifiable {
    var id: String { intent }

    /// Ce que la personne voulait dire, en français.
    let intent: String
    /// Comment un natif le dit.
    let native: String
    /// Le contournement qu'elle a utilisé à la place, s'il est identifiable.
    let workaround: String?
}

/// Mesuré sur l'appareil à partir des tours de parole — aucun appel réseau.
struct FluencyMetrics: Codable, Hashable {
    /// Mots par minute pendant la prise de parole effective.
    /// Un natif tourne autour de 130–160 selon la langue.
    let wordsPerMinute: Double

    /// Temps moyen avant de commencer à répondre. L'indicateur qui bouge
    /// le plus vite chez notre profil, et le plus gratifiant à voir baisser.
    let averageLatency: TimeInterval

    /// La plus longue hésitation de la session.
    let longestLatency: TimeInterval

    let totalSpeakingTime: TimeInterval
    let turnCount: Int
    let rescueCount: Int

    /// Longueur moyenne d'un tour, en mots. Un utilisateur qui progresse
    /// répond plus **long**, pas seulement plus vite.
    let averageWordsPerTurn: Double
}
