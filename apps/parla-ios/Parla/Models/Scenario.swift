import Foundation

/// Un scénario, c'est une **situation où la personne a déjà échoué dans la vraie vie**.
/// Pas un thème de vocabulaire. La différence est tout le produit : « Le restaurant /
/// 20 mots à retenir » ne prépare à rien ; « le serveur t'a mal compris et tu dois
/// te reprendre » prépare exactement au moment qui fait peur.
struct Scenario: Codable, Identifiable, Hashable {
    let id: String
    let category: ScenarioCategory

    /// Titre côté utilisateur, en français, formulé du point de vue de la peur.
    let title: String

    /// Ce que la personne va devoir réussir. Affiché avant de décrocher.
    let situation: String

    /// Qui est en face : c'est ce persona que le modèle incarne, pas « un professeur ».
    let interlocutor: Interlocutor

    /// L'objectif concret de la conversation. Sert au débrief pour dire « atteint / pas atteint ».
    let objective: String

    /// Difficulté de production requise, pas de compréhension.
    let productionLevel: CEFRLevel

    /// Les motivations auxquelles ce scénario répond (filtrage à l'accueil).
    let motivations: [Motivation]

    /// Langues pour lesquelles ce scénario a du sens. Vide = toutes.
    let languages: [TargetLanguage]

    /// Les « pièges » que l'interlocuteur doit tendre : interruptions, question
    /// inattendue, demande de reformulation. C'est ce qui empêche l'utilisateur
    /// de réciter un script préparé, et donc ce qui l'oblige à produire vraiment.
    let curveballs: [String]

    /// Durée cible en minutes. Court exprès : mieux vaut 4 minutes tous les jours
    /// que 30 minutes une fois par mois.
    let targetMinutes: Int

    func isAvailable(for profile: UserProfile) -> Bool {
        languages.isEmpty || languages.contains(profile.language)
    }
}

struct Interlocutor: Codable, Hashable {
    /// Prénom, dans la langue cible. L'app ne parle jamais de « l'IA » à l'écran.
    let name: String

    /// Ce que le modèle doit incarner : âge, humeur, débit, patience.
    /// Injecté tel quel dans le prompt système.
    let persona: String

    /// Le registre attendu. Un cousin ne parle pas comme un guichetier.
    let register: Register

    /// Débit de parole de la synthèse vocale, en fraction du débit normal.
    let speechRate: Double
}

enum Register: String, Codable, Hashable {
    case familiar
    case neutral
    case formal

    var promptDescription: String {
        switch self {
        case .familiar: "très familier, tu tutoies, tu coupes la parole, tu utilises de l'argot courant"
        case .neutral: "courant, ni soutenu ni familier"
        case .formal: "soutenu et professionnel, tu vouvoies"
        }
    }
}

enum ScenarioCategory: String, Codable, CaseIterable, Identifiable {
    case family
    case everyday
    case work
    case admin
    case conflict
    case social

    var id: String { rawValue }

    var label: String {
        switch self {
        case .family: "Famille"
        case .everyday: "Quotidien"
        case .work: "Travail"
        case .admin: "Démarches"
        case .conflict: "Situations tendues"
        case .social: "Vie sociale"
        }
    }

    var icon: String {
        switch self {
        case .family: "figure.2.and.child.holdinghands"
        case .everyday: "cart.fill"
        case .work: "briefcase.fill"
        case .admin: "building.columns.fill"
        case .conflict: "exclamationmark.bubble.fill"
        case .social: "person.3.fill"
        }
    }

    /// Pourquoi cette catégorie existe. Affiché en sous-titre : l'app explique
    /// toujours à quoi sert un exercice, parce que l'adulte motivé décroche
    /// dès qu'il a l'impression de faire du remplissage.
    var rationale: String {
        switch self {
        case .family: "Là où le blocage fait le plus mal — et où on te pardonne le moins de répondre en français."
        case .everyday: "Les micro-interactions qu'on évite : commander, demander, se reprendre."
        case .work: "Le registre qu'on n'apprend jamais en famille."
        case .admin: "Le vocabulaire précis qui manque toujours au guichet."
        case .conflict: "Se défendre, dire non, réclamer. Le vrai plafond de verre."
        case .social: "Raconter, blaguer, avoir de la répartie. Le niveau au-dessus."
        }
    }
}
