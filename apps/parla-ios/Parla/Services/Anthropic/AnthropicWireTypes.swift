import Foundation

// MARK: - Requête

/// Corps d'une requête `POST /v1/messages`.
/// Les noms de champs suivent le wire format de l'API ; les `CodingKeys`
/// font la conversion depuis le camelCase Swift.
struct MessagesRequest: Encodable {
    var model: String
    var maxTokens: Int
    var messages: [APIMessage]
    var system: [SystemBlock]?
    var stream: Bool?
    var thinking: ThinkingConfig?
    var outputConfig: OutputConfig?

    /// Repli côté serveur en cas de refus du classifieur.
    /// `"default"` laisse l'API router selon la catégorie de refus — on n'a donc
    /// aucune liste de modèles à maintenir dans l'app.
    var fallbacks: String?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case stream
        case thinking
        case outputConfig = "output_config"
        case fallbacks
    }
}

struct SystemBlock: Encodable {
    var type: String = "text"
    var text: String
    var cacheControl: CacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }

    struct CacheControl: Encodable {
        var type: String = "ephemeral"
    }

    /// Marque ce bloc comme fin du préfixe stable : tout ce qui précède est mis
    /// en cache. Sur une conversation, le prompt système (persona + scénario +
    /// profil) est identique à chaque tour — le cacher divise le coût d'entrée.
    static func cached(_ text: String) -> SystemBlock {
        SystemBlock(text: text, cacheControl: CacheControl())
    }
}

struct APIMessage: Encodable {
    let role: String
    let content: String

    static func user(_ text: String) -> APIMessage { APIMessage(role: "user", content: text) }
    static func assistant(_ text: String) -> APIMessage { APIMessage(role: "assistant", content: text) }
}

struct ThinkingConfig: Encodable {
    var type: String = "adaptive"
    /// `omitted` par défaut côté API. On ne demande jamais le résumé ici :
    /// l'app n'affiche pas le raisonnement, et le transmettre coûte de la latence.
    var display: String?
}

struct OutputConfig: Encodable {
    /// `low` pour les tours de conversation (la latence prime), `high` pour le
    /// débrief (la qualité d'analyse prime, et l'utilisateur a déjà raccroché).
    var effort: String?
    var format: OutputFormat?

    struct OutputFormat: Encodable {
        var type: String = "json_schema"
        var schema: JSONValue
    }
}

// MARK: - Réponse

struct MessagesResponse: Decodable {
    let id: String
    let model: String
    let content: [ContentBlock]
    let stopReason: String?
    let stopDetails: StopDetails?
    let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id, model, content, usage
        case stopReason = "stop_reason"
        case stopDetails = "stop_details"
    }

    /// Concaténation des blocs `text`. Les blocs `thinking` sont ignorés.
    var text: String {
        content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
    }

    /// `stop_details` n'est renseigné **que** sur un refus — d'où le garde-fou.
    var refusal: StopDetails? {
        stopReason == "refusal" ? stopDetails : nil
    }
}

struct ContentBlock: Decodable {
    let type: String
    let text: String?
}

struct StopDetails: Decodable {
    let type: String?
    let category: String?
    let explanation: String?
}

struct Usage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
    }
}

// MARK: - Événements de streaming

/// Vue simplifiée du flux SSE : l'app n'a besoin que du texte qui arrive,
/// du motif d'arrêt et des erreurs.
enum StreamEvent {
    case textDelta(String)
    case stop(reason: String?, details: StopDetails?)
    case error(String)
}

// MARK: - Erreurs

enum AnthropicError: LocalizedError {
    case missingCredentials
    case http(status: Int, body: String)
    case decoding(String)
    case refused(category: String?, explanation: String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Aucune clé API ni URL de proxy configurée. Voir README → Configuration."
        case .http(let status, let body):
            "Erreur réseau \(status) : \(body)"
        case .decoding(let detail):
            "Réponse illisible : \(detail)"
        case .refused(let category, let explanation):
            "Requête refusée (\(category ?? "inconnu")) : \(explanation ?? "—")"
        case .emptyResponse:
            "Réponse vide."
        }
    }
}
