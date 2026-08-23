import Foundation

/// Produit le débrief d'une session terminée, puis en dérive les cartes de révision.
struct DebriefService {
    let client: AnthropicClient

    func analyze(
        session: ConversationSession,
        scenario: Scenario,
        profile: UserProfile
    ) async throws -> Debrief {
        var debrief: Debrief = try await client.structured(
            system: Prompts.debriefSystem(scenario: scenario, profile: profile),
            messages: [.user(Prompts.transcript(session, scenario: scenario))],
            schema: Prompts.debriefSchema,
            as: Debrief.self
        )
        // Les métriques sont calculées localement et greffées après coup :
        // le modèle n'a pas à inventer des chiffres qu'on mesure déjà.
        debrief.metrics = FluencyAnalyzer.metrics(for: session)
        return debrief
    }

    /// Transforme un débrief en cartes. Les erreurs `minor` ne deviennent pas des
    /// cartes : réviser un détail au même titre qu'un blocage dilue la file et
    /// fait perdre confiance dans l'outil.
    func makeCards(from debrief: Debrief, session: ConversationSession) -> [ErrorCard] {
        let fromCorrections = debrief.corrections
            .filter { $0.severity != .minor }
            .map { ErrorCard.from(correction: $0, language: session.language, sessionID: session.id) }

        let fromAvoided = debrief.avoidedExpressions
            .map { ErrorCard.from(avoided: $0, language: session.language, sessionID: session.id) }

        return fromCorrections + fromAvoided
    }

    /// Met à jour le niveau de production. On ne bouge que d'un cran à la fois et
    /// on ne redescend jamais sur une seule mauvaise session : un adulte qui voit
    /// son niveau baisser après une soirée fatiguée arrête l'app.
    func updatedProduction(current: CEFRLevel, estimate: CEFRLevel) -> CEFRLevel {
        guard estimate.rank > current.rank else { return current }
        let next = min(current.rank + 1, CEFRLevel.allCases.count - 1)
        return CEFRLevel.allCases[next]
    }
}
