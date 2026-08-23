import SwiftUI

/// L'accueil ne propose **qu'une seule chose à faire** : la conversation du jour.
/// Une grille de dix exercices déclenche la paralysie du choix et transforme
/// l'app en catalogue qu'on ne finit jamais. Le reste est accessible, mais plus bas.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedScenario: Scenario?
    @State private var showsAllScenarios = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if appState.isDemoMode { DemoModeBanner() }

                    header

                    if let scenario = todaysScenario {
                        todayCard(scenario)
                    }

                    if !appState.dueCards.isEmpty {
                        notebookCard
                    }

                    otherScenarios
                }
                .padding(Layout.gutter)
            }
            .screenBackground()
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $selectedScenario) { scenario in
                if let profile = appState.profile {
                    ConversationView(scenario: scenario, profile: profile)
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(greeting)
                    .font(Typography.display(30))
                    .foregroundStyle(Palette.ink)
                Spacer()
                if let profile = appState.profile, profile.streakDays > 1 {
                    Pill(text: "\(profile.streakDays) jours", color: Palette.accent, background: Palette.accentSoft)
                }
            }

            if let latency = appState.recentAverageLatency {
                Text("Tu mets en moyenne **\(latency.secondsLabel) s** avant de répondre. C'est le chiffre qu'on fait baisser.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                Text("Une conversation. Cinq minutes. À voix haute.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    private func todayCard(_ scenario: Scenario) -> some View {
        Button {
            selectedScenario = scenario
        } label: {
            CardSurface(padding: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Pill(text: scenario.category.label, color: Palette.accent, background: Palette.accentSoft)
                        Pill(text: "\(scenario.targetMinutes) min")
                        Spacer()
                    }

                    Text(scenario.title)
                        .font(Typography.title(21))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(scenario.situation)
                        .font(Typography.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(Palette.inkTertiary)
                        Text("Avec \(scenario.interlocutor.name)")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkSecondary)
                        Spacer()
                        Image(systemName: "phone.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Palette.accent)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var notebookCard: some View {
        NavigationLink {
            DrillView()
        } label: {
            CardSurface {
                HStack(spacing: 14) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(appState.dueCards.count) tournures à réviser")
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(Palette.ink)
                        Text("Tes propres erreurs, à redire à voix haute.")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.inkTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var otherScenarios: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation { showsAllScenarios.toggle() }
            } label: {
                HStack {
                    SectionHeader(title: "Autres situations")
                    Image(systemName: showsAllScenarios ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .buttonStyle(.plain)

            if showsAllScenarios {
                ForEach(ScenarioCategory.allCases) { category in
                    let scenarios = availableScenarios.filter { $0.category == category }
                    if !scenarios.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.label)
                                .font(Typography.captionEmphasis)
                                .foregroundStyle(Palette.ink)
                            Text(category.rationale)
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkTertiary)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(scenarios) { scenario in
                                Button { selectedScenario = scenario } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(scenario.title)
                                                .font(Typography.body)
                                                .foregroundStyle(Palette.ink)
                                                .multilineTextAlignment(.leading)
                                            Text("\(scenario.productionLevel.label) · \(scenario.targetMinutes) min")
                                                .font(Typography.caption)
                                                .foregroundStyle(Palette.inkTertiary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.inkTertiary)
                                    }
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().overlay(Palette.hairline)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    // MARK: - Données

    private var availableScenarios: [Scenario] {
        guard let profile = appState.profile else { return [] }
        return ScenarioLibrary.all.filter { $0.isAvailable(for: profile) }
    }

    /// Un scénario par jour, stable dans la journée : rouvrir l'app ne doit pas
    /// changer la proposition, sinon elle perd son caractère d'engagement.
    private var todaysScenario: Scenario? {
        guard let profile = appState.profile else { return nil }
        let candidates = ScenarioLibrary.recommended(for: profile)
        guard !candidates.isEmpty else { return availableScenarios.first }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return candidates[day % candidates.count]
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Ce matin" : (hour < 18 ? "Cet après-midi" : "Ce soir")
    }
}
