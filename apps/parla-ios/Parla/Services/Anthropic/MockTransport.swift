import Foundation

/// Transport hors-ligne. Il existe pour trois raisons concrètes :
/// démarrer l'app sans aucune configuration, démontrer le parcours complet
/// sans brûler de tokens, et garder les previews SwiftUI fonctionnelles.
///
/// Il ne cherche pas à être intelligent : il rejoue des réponses crédibles
/// en italien et un débrief complet, pour que chaque écran ait de la matière.
final class MockTransport: LLMTransport {
    private var turnIndex = 0

    private let cannedReplies = [
        "Ciao! Allora, dimmi tutto — come mai sei da queste parti?",
        "Ah, capito. E quanto tempo ti fermi? Guarda che qui d'estate fa un caldo assurdo.",
        "Aspetta, scusa — non ho capito bene l'ultima cosa. Me la ridici?",
        "Ma dai! E tua madre di dov'è esattamente? Perché l'accento tuo mi sa di Sud.",
        "Va bene, allora ci vediamo domani verso le otto. Non fare tardi, eh!"
    ]

    func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        try await Task.sleep(nanoseconds: 600_000_000)

        // Le débrief est la seule requête à sortie structurée de l'app.
        let payload = request.outputConfig?.format != nil ? Self.mockDebriefJSON : "Va bene."

        return MessagesResponse(
            id: "msg_mock",
            model: AnthropicClient.model,
            content: [ContentBlock(type: "text", text: payload)],
            stopReason: "end_turn",
            stopDetails: nil,
            usage: Usage(inputTokens: 0, outputTokens: 0, cacheReadInputTokens: 0, cacheCreationInputTokens: 0)
        )
    }

    func stream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        let reply = cannedReplies[turnIndex % cannedReplies.count]
        turnIndex += 1

        return AsyncThrowingStream { continuation in
            let task = Task {
                // On streame mot à mot pour que l'UI de dictée soit réellement testée.
                for word in reply.split(separator: " ") {
                    try? await Task.sleep(nanoseconds: 55_000_000)
                    if Task.isCancelled { break }
                    continuation.yield(.textDelta(String(word) + " "))
                }
                continuation.yield(.stop(reason: "end_turn", details: nil))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Débrief factice, conforme au schéma de `DebriefService`.
    private static let mockDebriefJSON = """
    {
      "objectiveAchieved": true,
      "summary": "Tu as tenu la conversation du début à la fin sans repasser au français, et c'est le principal. Ce qui se voit, c'est que tu construis tes phrases en français dans ta tête avant de les traduire : le sens passe, mais le rythme trahit. Ton point faible n'est pas le vocabulaire, c'est le passé.",
      "strengths": [
        "Aucun retour au français, même quand tu as buté sur un mot",
        "Ta prononciation ne trahit pas un débutant — on t'entend comme quelqu'un du Sud",
        "Tu as relancé la conversation deux fois toi-même au lieu de subir les questions"
      ],
      "corrections": [
        {
          "said": "Ho andato al mercato",
          "native": "Sono andato al mercato",
          "explanation": "Les verbes de mouvement prennent essere, pas avere. C'est ta faute la plus fréquente depuis trois sessions.",
          "severity": "awkward",
          "kind": "grammar"
        },
        {
          "said": "Sono caldo",
          "native": "Ho caldo",
          "explanation": "Calqué sur le français « j'ai chaud » mal retourné : « sono caldo » veut dire que tu es sexy.",
          "severity": "blocking",
          "kind": "calque"
        },
        {
          "said": "Molto bene, grazie",
          "native": "Tutto a posto, grazie",
          "explanation": "Correct mais scolaire. Personne ne répond « molto bene » à un cousin.",
          "severity": "minor",
          "kind": "register"
        }
      ],
      "avoidedExpressions": [
        {
          "intent": "Ça me prend la tête",
          "native": "Mi sta sulle scatole",
          "workaround": "è difficile"
        },
        {
          "intent": "Je me suis débrouillé",
          "native": "Me la sono cavata",
          "workaround": "ho fatto"
        }
      ],
      "productionEstimate": "b1",
      "nextFocus": "Le passé composé avec essere. Une seule règle, mais elle revient dans une phrase sur trois."
    }
    """
}
