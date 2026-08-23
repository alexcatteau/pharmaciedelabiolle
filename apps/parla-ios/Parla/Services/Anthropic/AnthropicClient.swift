import Foundation

/// Façade au-dessus du transport. Le reste de l'app ne connaît que ce type :
/// personne d'autre ne manipule des `MessagesRequest`.
final class AnthropicClient {
    /// Modèle unique pour toute l'app. La qualité de la correction linguistique
    /// est le produit — c'est le dernier endroit où il faut économiser.
    /// La latence se règle avec `effort`, pas en descendant de modèle.
    static let model = "claude-opus-5"

    private let transport: LLMTransport

    init(transport: LLMTransport) {
        self.transport = transport
    }

    // MARK: - Tour de conversation (streaming)

    /// Un tour de parole de l'interlocuteur, streamé.
    ///
    /// `effort: "low"` est délibéré : dans un dialogue oral, deux secondes de
    /// silence en trop cassent l'illusion et remettent l'utilisateur dans la
    /// posture « exercice ». Répondre vite vaut mieux que répondre finement.
    func streamReply(
        system: String,
        messages: [APIMessage]
    ) -> AsyncThrowingStream<String, Error> {
        let request = MessagesRequest(
            model: Self.model,
            // Un tour parlé fait deux ou trois phrases. Plafond bas assumé :
            // il empêche aussi le modèle de partir en monologue de professeur.
            maxTokens: 1024,
            messages: messages,
            system: [SystemBlock.cached(system)],
            outputConfig: OutputConfig(effort: "low"),
            fallbacks: "default"
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in transport.stream(request) {
                        switch event {
                        case .textDelta(let text):
                            continuation.yield(text)
                        case .error(let message):
                            throw AnthropicError.decoding(message)
                        case .stop(let reason, let details):
                            if reason == "refusal" {
                                throw AnthropicError.refused(
                                    category: details?.category,
                                    explanation: details?.explanation
                                )
                            }
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

    // MARK: - Sortie structurée

    /// Requête dont la réponse est garantie conforme au schéma fourni.
    /// Utilisé pour le débrief : l'app décode directement dans ses types.
    ///
    /// `effort: "high"` ici, à l'inverse des tours de parole : l'utilisateur a
    /// raccroché, il attend un rapport, et c'est la qualité de l'analyse qui
    /// fait revenir.
    func structured<T: Decodable>(
        system: String,
        messages: [APIMessage],
        schema: JSONValue,
        as type: T.Type,
        effort: String = "high"
    ) async throws -> T {
        let request = MessagesRequest(
            model: Self.model,
            maxTokens: 16000,
            messages: messages,
            system: [SystemBlock.cached(system)],
            outputConfig: OutputConfig(
                effort: effort,
                format: OutputConfig.OutputFormat(schema: schema)
            ),
            fallbacks: "default"
        )

        let response = try await transport.send(request)
        let text = response.text
        guard !text.isEmpty, let data = text.data(using: .utf8) else {
            throw AnthropicError.emptyResponse
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AnthropicError.decoding("\(error) — reçu : \(text.prefix(400))")
        }
    }

    // MARK: - Requête simple

    func complete(system: String, messages: [APIMessage], effort: String = "low") async throws -> String {
        let request = MessagesRequest(
            model: Self.model,
            maxTokens: 4096,
            messages: messages,
            system: [SystemBlock.cached(system)],
            outputConfig: OutputConfig(effort: effort),
            fallbacks: "default"
        )
        let response = try await transport.send(request)
        guard !response.text.isEmpty else { throw AnthropicError.emptyResponse }
        return response.text
    }
}
