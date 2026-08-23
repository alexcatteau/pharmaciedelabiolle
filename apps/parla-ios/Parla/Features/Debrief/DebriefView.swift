import SwiftUI

/// Le débrief est l'écran qui fait revenir. Son ordre est délibéré :
/// **objectif → ce qui a marché → ce que tu as évité de dire → corrections → une seule chose à retenir.**
///
/// Les corrections arrivent en quatrième position, pas en première. Ouvrir sur une
/// liste de fautes après un effort de parole est la façon la plus efficace de faire
/// désinstaller une app.
struct DebriefView: View {
    let debrief: Debrief
    let session: ConversationSession
    let scenario: Scenario
    let onClose: () -> Void

    @State private var showsMinorCorrections = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                verdict
                metricsSection
                strengthsSection
                avoidedSection
                correctionsSection
                nextFocusSection
            }
            .padding(Layout.gutter)
            .padding(.bottom, 40)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Terminé") { onClose() }
                .padding(Layout.gutter)
                .background(Palette.canvas)
        }
    }

    // MARK: - Verdict

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: debrief.objectiveAchieved ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(debrief.objectiveAchieved ? Palette.success : Palette.warning)
                Text(debrief.objectiveAchieved ? "Objectif atteint" : "Objectif manqué")
                    .font(Typography.title(20))
                    .foregroundStyle(Palette.ink)
            }

            Text(debrief.summary)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Métriques

    @ViewBuilder
    private var metricsSection: some View {
        if let metrics = debrief.metrics {
            CardSurface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        MetricTile(
                            value: metrics.averageLatency.secondsLabel,
                            unit: "s",
                            label: "avant de répondre",
                            accent: Palette.accent
                        )
                        MetricTile(
                            value: String(Int(metrics.wordsPerMinute)),
                            unit: "m/min",
                            label: "débit (natif ≈ \(Int(FluencyAnalyzer.nativeReferenceWPM(for: session.language))))"
                        )
                        MetricTile(
                            value: String(Int(metrics.averageWordsPerTurn)),
                            unit: nil,
                            label: "mots par prise de parole"
                        )
                    }

                    if metrics.rescueCount > 0 {
                        Text("Tu as demandé de l'aide \(metrics.rescueCount) fois. Ce n'est pas une faute : c'est le compteur qu'on regarde baisser.")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Points forts

    @ViewBuilder
    private var strengthsSection: some View {
        if !debrief.strengths.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Ce qui a marché")
                ForEach(debrief.strengths, id: \.self) { strength in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.success)
                            .padding(.top, 3)
                        Text(strength)
                            .font(Typography.body)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Évitements

    @ViewBuilder
    private var avoidedSection: some View {
        if !debrief.avoidedExpressions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Ce que tu as contourné",
                    subtitle: "Les idées que tu as voulu dire, mais que tu as remplacées par plus simple. C'est là qu'est ton plafond."
                )

                ForEach(debrief.avoidedExpressions) { avoided in
                    CardSurface(padding: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(avoided.intent)
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkSecondary)

                            Text(avoided.native)
                                .font(Typography.title(18))
                                .foregroundStyle(Palette.accent)
                                .fixedSize(horizontal: false, vertical: true)

                            if let workaround = avoided.workaround, !workaround.isEmpty {
                                Text("Tu avais dit « \(workaround) »")
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Corrections

    @ViewBuilder
    private var correctionsSection: some View {
        let sorted = debrief.corrections.sorted { $0.severity.rank < $1.severity.rank }
        let major = sorted.filter { $0.severity != .minor }
        let minor = sorted.filter { $0.severity == .minor }

        if !sorted.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "À corriger")

                ForEach(major) { correction in
                    CorrectionRow(correction: correction)
                }

                if !minor.isEmpty {
                    Button {
                        withAnimation { showsMinorCorrections.toggle() }
                    } label: {
                        HStack {
                            Text("\(minor.count) détails")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkSecondary)
                            Image(systemName: showsMinorCorrections ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.inkTertiary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    if showsMinorCorrections {
                        ForEach(minor) { correction in
                            CorrectionRow(correction: correction)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Prochain focus

    private var nextFocusSection: some View {
        CardSurface(padding: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("UNE SEULE CHOSE POUR LA PROCHAINE FOIS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
                    .kerning(0.8)
                Text(debrief.nextFocus)
                    .font(Typography.title(19))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct CorrectionRow: View {
    let correction: Correction

    var body: some View {
        CardSurface(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Pill(text: correction.severity.label, color: severityColor, background: Palette.surfaceRaised)
                    Pill(text: correction.kind.label)
                    Spacer()
                }

                HStack(alignment: .top, spacing: 8) {
                    Text(correction.said)
                        .font(Typography.body)
                        .foregroundStyle(Palette.inkTertiary)
                        .strikethrough(color: Palette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.accent)
                        .padding(.top, 4)
                    Text(correction.native)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(correction.explanation)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var severityColor: Color {
        switch correction.severity {
        case .blocking: Palette.accent
        case .awkward: Palette.warning
        case .minor: Palette.inkTertiary
        }
    }
}
