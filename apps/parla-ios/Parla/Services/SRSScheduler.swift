import Foundation

/// Ordonnancement des révisions, variante de SM-2.
///
/// Une seule adaptation, mais elle change tout : **une carte n'est validée que
/// si elle a été dite à voix haute**. Reconnaître une réponse dans une liste ne
/// prouve rien sur la capacité à la produire, et c'est précisément ce décalage
/// qui a amené l'utilisateur ici.
enum SRSScheduler {
    static func schedule(card: ErrorCard, quality: RecallQuality) -> ErrorCard {
        var updated = card

        if quality == .blocked {
            // Échec : on repart de zéro, la carte revient dans la journée.
            updated.repetitions = 0
            updated.intervalDays = 0
            updated.dueDate = Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date()
        } else {
            updated.repetitions += 1
            updated.spokenSuccesses += 1
            updated.intervalDays = switch updated.repetitions {
            case 1: 1
            case 2: 4
            default: Int((Double(updated.intervalDays) * updated.easeFactor).rounded())
            }
            updated.dueDate = Calendar.current.date(
                byAdding: .day,
                value: max(1, updated.intervalDays),
                to: Date()
            ) ?? Date()
        }

        // Ajustement du facteur de facilité (formule SM-2).
        let q = Double(quality.rawValue)
        let delta = 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)
        updated.easeFactor = max(1.3, updated.easeFactor + delta)

        return updated
    }

    /// La file du jour. On plafonne volontairement : une file de 60 cartes fait
    /// abandonner, et l'objectif quotidien de l'app se compte en minutes.
    static func dueCards(from cards: [ErrorCard], limit: Int = 12) -> [ErrorCard] {
        cards
            .filter(\.isDue)
            // Les erreurs bloquantes et les calques d'abord : ce sont celles qui
            // coûtent réellement quelque chose en conversation.
            .sorted { lhs, rhs in
                if lhs.kind == .calque, rhs.kind != .calque { return true }
                if rhs.kind == .calque, lhs.kind != .calque { return false }
                return lhs.dueDate < rhs.dueDate
            }
            .prefix(limit)
            .map { $0 }
    }
}
