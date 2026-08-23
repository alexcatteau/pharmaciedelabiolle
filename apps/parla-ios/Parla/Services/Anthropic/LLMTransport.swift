import Foundation

/// Abstraction du transport pour découpler l'app du chemin réseau.
///
/// Elle existe pour une raison précise, pas par goût de l'abstraction :
/// **une clé API Anthropic n'a rien à faire dans un binaire iOS distribué.**
/// Tout ce qui est livré sur l'App Store est extractible. Le transport direct
/// est donc réservé au développement, et la production passe par un proxy que
/// tu contrôles (voir README → « Ne shippe pas ta clé »).
protocol LLMTransport {
    func send(_ request: MessagesRequest) async throws -> MessagesResponse
    func stream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

// MARK: - Transport direct (développement uniquement)

/// Appelle `api.anthropic.com` directement depuis l'appareil.
/// Pratique pour itérer au simulateur ; interdit en production.
final class DirectAnthropicTransport: LLMTransport {
    private let apiKey: String
    private let session: URLSession
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Bêtas activées sur chaque requête.
    /// `server-side-fallback-2026-07-01` permet à `fallbacks: "default"` de
    /// rerouter automatiquement quand un classifieur refuse la requête — ça
    /// arrive sur des scénarios de dispute ou de santé, qui sont légitimes ici.
    private let betaHeader = "server-side-fallback-2026-07-01"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    private func makeRequest(_ body: MessagesRequest) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONEncoder().encode(body)
        // Une conversation orale qui met plus de 60 s à répondre est morte de toute façon.
        request.timeoutInterval = 60
        return request
    }

    func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        let urlRequest = try makeRequest(request)
        let (data, response) = try await session.data(for: urlRequest)
        try AnthropicHTTP.validate(response: response, data: data)
        return try AnthropicHTTP.decodeResponse(data)
    }

    func stream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        var streaming = request
        streaming.stream = true
        return AnthropicHTTP.streamSSE(makeURLRequest: { try self.makeRequest(streaming) }, session: session)
    }
}

// MARK: - Transport par proxy (production)

/// Appelle **ton** backend, qui détient la clé et applique tes quotas.
/// Le corps envoyé est exactement celui de l'API Messages : ton proxy peut donc
/// se contenter de le relayer après avoir vérifié l'utilisateur.
final class ProxyTransport: LLMTransport {
    private let baseURL: URL
    private let session: URLSession
    /// Jeton de **ton** service (pas une clé Anthropic) identifiant l'utilisateur.
    private let userTokenProvider: () -> String?

    init(baseURL: URL, session: URLSession = .shared, userTokenProvider: @escaping () -> String?) {
        self.baseURL = baseURL
        self.session = session
        self.userTokenProvider = userTokenProvider
    }

    private func makeRequest(_ body: MessagesRequest) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = userTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 60
        return request
    }

    func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        let urlRequest = try makeRequest(request)
        let (data, response) = try await session.data(for: urlRequest)
        try AnthropicHTTP.validate(response: response, data: data)
        return try AnthropicHTTP.decodeResponse(data)
    }

    func stream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        var streaming = request
        streaming.stream = true
        return AnthropicHTTP.streamSSE(makeURLRequest: { try self.makeRequest(streaming) }, session: session)
    }
}

// MARK: - Plomberie HTTP partagée

enum AnthropicHTTP {
    static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw AnthropicError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? "<binaire>"
            )
        }
    }

    static func decodeResponse(_ data: Data) throws -> MessagesResponse {
        do {
            let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
            // `stop_details` n'est peuplé que sur un refus : on teste `stop_reason` d'abord.
            if let refusal = decoded.refusal {
                throw AnthropicError.refused(category: refusal.category, explanation: refusal.explanation)
            }
            return decoded
        } catch let error as AnthropicError {
            throw error
        } catch {
            throw AnthropicError.decoding(error.localizedDescription)
        }
    }

    /// Lit un flux SSE ligne par ligne et n'en ressort que ce dont l'app a besoin.
    static func streamSSE(
        makeURLRequest: @escaping () throws -> URLRequest,
        session: URLSession
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeURLRequest()
                    let (bytes, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        // Sur erreur, le corps est du JSON classique, pas du SSE.
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw AnthropicError.http(status: http.statusCode, body: body)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !payload.isEmpty, payload != "[DONE]" else { continue }
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let event = parseStreamPayload(data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private struct RawStreamEvent: Decodable {
        struct Delta: Decodable {
            let type: String?
            let text: String?
            let stopReason: String?

            enum CodingKeys: String, CodingKey {
                case type, text
                case stopReason = "stop_reason"
            }
        }
        struct ErrorPayload: Decodable {
            let type: String?
            let message: String?
        }

        let type: String
        let delta: Delta?
        let error: ErrorPayload?
        let stopDetails: StopDetails?

        enum CodingKeys: String, CodingKey {
            case type, delta, error
            case stopDetails = "stop_details"
        }
    }

    private static func parseStreamPayload(_ data: Data) -> StreamEvent? {
        guard let raw = try? JSONDecoder().decode(RawStreamEvent.self, from: data) else { return nil }
        switch raw.type {
        case "content_block_delta":
            // Seuls les `text_delta` nous intéressent ; les `thinking_delta` sont ignorés.
            guard raw.delta?.type == "text_delta", let text = raw.delta?.text else { return nil }
            return .textDelta(text)
        case "message_delta":
            return .stop(reason: raw.delta?.stopReason, details: raw.stopDetails)
        case "error":
            return .error(raw.error?.message ?? "erreur inconnue")
        default:
            return nil
        }
    }
}
