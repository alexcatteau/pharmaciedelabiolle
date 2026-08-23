import Foundation

/// Le profil Parla est délibérément **asymétrique**.
///
/// Toutes les apps de langue posent une seule question — « quel est ton niveau ? » —
/// et rangent l'utilisateur sur un axe unique A1→C2. C'est exactement ce qui rate
/// notre utilisateur : il est C1 en compréhension et A2 en production. Un parcours
/// calibré sur la moyenne des deux l'ennuie ET le laisse muet.
///
/// On stocke donc deux niveaux séparés, et on ne fait progresser que celui qui bloque.
struct UserProfile: Codable, Equatable {
    var language: TargetLanguage
    var variantID: String

    /// Auto-déclaré à l'onboarding, jamais réévalué à la baisse : ce que la personne
    /// comprend est stable et ce n'est pas là qu'on veut la faire travailler.
    var comprehension: CEFRLevel

    /// Le seul niveau qui bouge. Recalculé à partir des débriefs réels.
    var production: CEFRLevel

    /// La raison réelle d'être là. Sert à sélectionner les scénarios : « parler à
    /// ma belle-famille » et « tenir une réunion » ne demandent pas le même lexique.
    var motivations: Set<Motivation>

    /// Ce que la personne rate le plus souvent, appris au fil des sessions.
    /// Alimenté par les débriefs, injecté dans le prompt système de l'interlocuteur.
    var recurringWeaknesses: [String]

    var dailyGoalMinutes: Int
    var createdAt: Date
    var streakDays: Int
    var lastSessionDate: Date?

    static func makeDefault(language: TargetLanguage) -> UserProfile {
        UserProfile(
            language: language,
            variantID: language.variants.first?.id ?? "standard",
            comprehension: .b2,
            production: .a2,
            motivations: [],
            recurringWeaknesses: [],
            dailyGoalMinutes: 10,
            createdAt: Date(),
            streakDays: 0,
            lastSessionDate: nil
        )
    }

    /// L'écart compréhension/production. C'est LE chiffre que l'app met en avant :
    /// il nomme le problème que l'utilisateur n'arrivait pas à formuler.
    var fluencyGap: Int {
        max(0, comprehension.rank - production.rank)
    }
}

enum CEFRLevel: String, Codable, CaseIterable, Comparable, Identifiable {
    case a1, a2, b1, b2, c1, c2

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var rank: Int { CEFRLevel.allCases.firstIndex(of: self) ?? 0 }

    var description: String {
        switch self {
        case .a1: "Quelques mots, des phrases apprises par cœur"
        case .a2: "Je me débrouille, mais je cherche mes mots"
        case .b1: "Je tiens une conversation simple sans bloquer"
        case .b2: "Je discute de tout, avec des maladresses"
        case .c1: "Je m'exprime avec nuance, presque comme un natif"
        case .c2: "Indistinguable d'un natif"
        }
    }

    static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool { lhs.rank < rhs.rank }
}

enum Motivation: String, Codable, CaseIterable, Identifiable {
    case family
    case travel
    case work
    case admin
    case dating
    case identity

    var id: String { rawValue }

    var label: String {
        switch self {
        case .family: "Parler à ma famille"
        case .travel: "Ne plus galérer sur place"
        case .work: "Le travail"
        case .admin: "L'administratif, les commerces"
        case .dating: "Rencontres, amitiés"
        case .identity: "Me réapproprier ma langue"
        }
    }

    var icon: String {
        switch self {
        case .family: "house.fill"
        case .travel: "airplane"
        case .work: "briefcase.fill"
        case .admin: "doc.text.fill"
        case .dating: "heart.fill"
        case .identity: "person.fill.questionmark"
        }
    }
}
