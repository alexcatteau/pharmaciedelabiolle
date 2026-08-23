import SwiftUI

/// L'écran de progrès ne montre **ni XP, ni ligue, ni badge**.
///
/// Les métriques de jeu marchent sur des enfants et sur des débutants ; sur un
/// adulte qui sait déjà qu'il stagne, elles sonnent faux et cassent la crédibilité
/// de l'outil. On montre trois choses vraies à la place : l'écart
/// compréhension/production qui se referme, le temps de latence qui baisse, et le
/// temps réellement passé à parler.
struct ProgressView_Parla: View {
    @Environment(AppState.self) private var appState
    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if let profile = appState.profile {
                        gapCard(profile)
                    }

                    latencyCard
                    volumeCard
                    history
                    settings
                }
                .padding(Layout.gutter)
            }
            .screenBackground()
            .navigationTitle("Progrès")
            .confirmationDialog(
                "Tout effacer ?",
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Effacer profil, carnet et historique", role: .destructive) {
                    appState.reset()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    // MARK: - Écart

    private func gapCard(_ profile: UserProfile) -> some View {
        CardSurface(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Ton écart",
                    subtitle: "La distance entre ce que tu comprends et ce que tu arrives à dire."
                )

                HStack(spacing: 0) {
                    levelColumn("Tu comprends", profile.comprehension, Palette.inkSecondary)
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(width: 1, height: 44)
                    levelColumn("Tu produis", profile.production, Palette.accent)
                }

                if profile.fluencyGap > 0 {
                    Text("\(profile.fluencyGap) niveau\(profile.fluencyGap > 1 ? "x" : "") d'écart. C'est exactement ce que Parla travaille — et le seul chiffre qui doit bouger.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Ton écart est refermé. Tu peux monter ton niveau de compréhension cible dans les réglages.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.success)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func levelColumn(_ label: String, _ level: CEFRLevel, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(level.label)
                .font(Typography.metric(30))
                .foregroundStyle(color)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Latence

    @ViewBuilder
    private var latencyCard: some View {
        let trend = appState.latencyTrend
        if trend.count >= 2 {
            CardSurface(padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        title: "Temps avant de répondre",
                        subtitle: "Sur tes dernières conversations."
                    )

                    SparkLine(values: trend).frame(height: 64)

                    HStack {
                        Text("\(trend.first?.secondsLabel ?? "—") s")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkTertiary)
                        Spacer()
                        Text("\(trend.last?.secondsLabel ?? "—") s")
                            .font(Typography.captionEmphasis)
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
        }
    }

    // MARK: - Volume

    private var volumeCard: some View {
        CardSurface(padding: 20) {
            HStack(alignment: .top, spacing: 12) {
                MetricTile(
                    value: String(appState.sessions.count),
                    unit: nil,
                    label: "conversations"
                )
                MetricTile(
                    value: appState.totalSpeakingTime.minutesLabel,
                    unit: nil,
                    label: "passées à parler"
                )
                MetricTile(
                    value: String(appState.cards.count),
                    unit: nil,
                    label: "tournures au carnet"
                )
            }
        }
    }

    // MARK: - Historique

    @ViewBuilder
    private var history: some View {
        if !appState.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Historique")

                ForEach(appState.sessions.prefix(10)) { session in
                    HStack(spacing: 12) {
                        Image(systemName: (session.debrief?.objectiveAchieved ?? false)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle((session.debrief?.objectiveAchieved ?? false)
                                             ? Palette.success : Palette.inkTertiary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ScenarioLibrary.scenario(id: session.scenarioID)?.title ?? "Conversation")
                                .font(Typography.body)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkTertiary)
                        }

                        Spacer()

                        if let latency = session.debrief?.metrics?.averageLatency {
                            Text("\(latency.secondsLabel) s")
                                .font(Typography.captionEmphasis)
                                .foregroundStyle(Palette.inkSecondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.vertical, 6)
                    Divider().overlay(Palette.hairline)
                }
            }
        }
    }

    // MARK: - Réglages

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Réglages")
            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                HStack {
                    Text("Tout réinitialiser").font(Typography.body)
                    Spacer()
                    Image(systemName: "trash")
                }
                .foregroundStyle(Palette.accent)
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 8)
    }
}
