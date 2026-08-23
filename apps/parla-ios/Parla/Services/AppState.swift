import Foundation
import Observation

/// État global de l'app. Injecté dans l'environnement SwiftUI, unique source
/// de vérité pour le profil, les cartes et l'historique.
@MainActor
@Observable
final class AppState {
    private(set) var profile: UserProfile?
    private(set) var cards: [ErrorCard] = []
    private(set) var sessions: [ConversationSession] = []

    /// `true` quand aucune clé ni proxy n'est configuré : l'app tourne alors sur
    /// des réponses simulées et le dit clairement à l'écran.
    let isDemoMode: Bool

    let client: AnthropicClient
    let debriefService: DebriefService

    private let store = Store()

    init() {
        let transport = AppConfiguration.makeTransport()
        let client = AnthropicClient(transport: transport)
        self.client = client
        self.debriefService = DebriefService(client: client)
        self.isDemoMode = AppConfiguration.isRunningOnMock

        profile = store.load(UserProfile.self, from: .profile)
        cards = store.load([ErrorCard].self, from: .cards) ?? []
        sessions = store.load([ConversationSession].self, from: .sessions) ?? []
    }

    var isOnboarded: Bool { profile != nil }

    // MARK: - Profil

    func completeOnboarding(with profile: UserProfile) {
        self.profile = profile
        store.save(profile, to: .profile)
    }

    func updateProfile(_ transform: (inout UserProfile) -> Void) {
        guard var profile else { return }
        transform(&profile)
        self.profile = profile
        store.save(profile, to: .profile)
    }

    // MARK: - Sessions

    /// Archive une session terminée, greffe ses cartes et fait progresser le profil.
    func record(session: ConversationSession, debrief: Debrief) {
        var stored = session
        stored.debrief = debrief
        sessions.insert(stored, at: 0)
        store.save(sessions, to: .sessions)

        let newCards = debriefService.makeCards(from: debrief, session: stored)
        cards.append(contentsOf: newCards)
        store.save(cards, to: .cards)

        updateProfile { profile in
            profile.production = debriefService.updatedProduction(
                current: profile.production,
                estimate: debrief.productionEstimate
            )
            // Le prochain point à travailler devient un axe que l'interlocuteur
            // exploitera dès la session suivante.
            profile.recurringWeaknesses = Array(
                ([debrief.nextFocus] + profile.recurringWeaknesses).prefix(3)
            )
            profile.streakDays = Self.updatedStreak(
                current: profile.streakDays,
                lastSession: profile.lastSessionDate
            )
            profile.lastSessionDate = Date()
        }
    }

    // MARK: - Cartes

    var dueCards: [ErrorCard] { SRSScheduler.dueCards(from: cards) }

    func review(card: ErrorCard, quality: RecallQuality) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index] = SRSScheduler.schedule(card: cards[index], quality: quality)
        store.save(cards, to: .cards)
    }

    func deleteCard(_ card: ErrorCard) {
        cards.removeAll { $0.id == card.id }
        store.save(cards, to: .cards)
    }

    // MARK: - Statistiques

    /// Latence moyenne des cinq dernières sessions. C'est le chiffre mis en avant
    /// dans l'app : il descend vite, il est concret, et il mesure exactement ce
    /// que l'utilisateur est venu corriger.
    var recentAverageLatency: TimeInterval? {
        let values = sessions.prefix(5).compactMap { $0.debrief?.metrics?.averageLatency }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var latencyTrend: [TimeInterval] {
        sessions.prefix(10).compactMap { $0.debrief?.metrics?.averageLatency }.reversed()
    }

    var totalSpeakingTime: TimeInterval {
        sessions.compactMap { $0.debrief?.metrics?.totalSpeakingTime }.reduce(0, +)
    }

    func reset() {
        store.wipe()
        profile = nil
        cards = []
        sessions = []
    }

    private static func updatedStreak(current: Int, lastSession: Date?) -> Int {
        guard let lastSession else { return 1 }
        let calendar = Calendar.current
        if calendar.isDateInToday(lastSession) { return max(current, 1) }
        if calendar.isDateInYesterday(lastSession) { return current + 1 }
        return 1
    }
}
