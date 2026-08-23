import Foundation

/// Les langues que Parla adresse en priorité : celles des grandes diasporas en
/// France, où le profil « je comprends tout, je ne parle pas » est le plus fréquent.
///
/// Chaque langue porte deux identifiants de locale distincts, et c'est volontaire :
/// - `recognitionLocale` : ce que `SFSpeechRecognizer` sait transcrire.
/// - `voiceLocale` : la voix `AVSpeechSynthesisVoice` la plus naturelle.
/// Ils ne coïncident pas toujours (l'arabe en est le cas d'école).
enum TargetLanguage: String, Codable, CaseIterable, Identifiable, Hashable {
    case italian
    case spanish
    case portuguese
    case arabic
    case turkish
    case polish

    var id: String { rawValue }

    /// Nom affiché en français (langue d'interface de l'app).
    var displayName: String {
        switch self {
        case .italian: "Italien"
        case .spanish: "Espagnol"
        case .portuguese: "Portugais"
        case .arabic: "Arabe"
        case .turkish: "Turc"
        case .polish: "Polonais"
        }
    }

    /// Endonyme — utilisé partout où l'app bascule dans la langue cible.
    var endonym: String {
        switch self {
        case .italian: "Italiano"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .arabic: "العربية"
        case .turkish: "Türkçe"
        case .polish: "Polski"
        }
    }

    var flag: String {
        switch self {
        case .italian: "🇮🇹"
        case .spanish: "🇪🇸"
        case .portuguese: "🇵🇹"
        case .arabic: "🇲🇦"
        case .turkish: "🇹🇷"
        case .polish: "🇵🇱"
        }
    }

    var recognitionLocale: Locale {
        switch self {
        case .italian: Locale(identifier: "it-IT")
        case .spanish: Locale(identifier: "es-ES")
        case .portuguese: Locale(identifier: "pt-PT")
        case .arabic: Locale(identifier: "ar-SA")
        case .turkish: Locale(identifier: "tr-TR")
        case .polish: Locale(identifier: "pl-PL")
        }
    }

    var voiceLocaleIdentifier: String {
        switch self {
        case .italian: "it-IT"
        case .spanish: "es-ES"
        case .portuguese: "pt-PT"
        case .arabic: "ar-SA"
        case .turkish: "tr-TR"
        case .polish: "pl-PL"
        }
    }

    var isRightToLeft: Bool { self == .arabic }

    /// Variantes régionales proposées à l'onboarding. Un héritier d'une famille
    /// marocaine n'a pas besoin d'apprendre l'italien « de la RAI » : il a besoin
    /// de parler comme les gens à qui il parle réellement.
    var variants: [LanguageVariant] {
        switch self {
        case .italian:
            [.init(id: "standard", label: "Italien standard"),
             .init(id: "sud", label: "Italie du Sud (Naples, Sicile, Calabre)"),
             .init(id: "nord", label: "Italie du Nord")]
        case .spanish:
            [.init(id: "espagne", label: "Espagne"),
             .init(id: "latam", label: "Amérique latine")]
        case .portuguese:
            [.init(id: "portugal", label: "Portugal"),
             .init(id: "bresil", label: "Brésil")]
        case .arabic:
            [.init(id: "darija", label: "Darija marocaine"),
             .init(id: "algerien", label: "Algérien"),
             .init(id: "tunisien", label: "Tunisien"),
             .init(id: "levantin", label: "Levantin (Liban, Syrie)"),
             .init(id: "msa", label: "Arabe littéraire")]
        case .turkish:
            [.init(id: "standard", label: "Turc standard")]
        case .polish:
            [.init(id: "standard", label: "Polonais standard")]
        }
    }
}

struct LanguageVariant: Codable, Identifiable, Hashable {
    let id: String
    let label: String
}
