import SwiftUI

/// Le carnet, c'est le corpus des ratés personnels. Rien n'y entre qui ne vienne
/// d'une conversation réelle de l'utilisateur.
struct NotebookView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: Correction.Kind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if appState.cards.isEmpty {
                        emptyState
                    } else {
                        if !appState.dueCards.isEmpty {
                            NavigationLink { DrillView() } label: {
                                CardSurface {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Réviser \(appState.dueCards.count) tournures")
                                                .font(Typography.bodyEmphasis)
                                                .foregroundStyle(Palette.ink)
                                            Text("À voix haute. Reconnaître ne compte pas.")
                                                .font(Typography.caption)
                                                .foregroundStyle(Palette.inkSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "mic.fill").foregroundStyle(Palette.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        filterBar

                        ForEach(filteredCards) { card in
                            CardRow(card: card)
                        }
                    }
                }
                .padding(Layout.gutter)
            }
            .screenBackground()
            .navigationTitle("Carnet")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Tout", isOn: filter == nil) { filter = nil }
                ForEach(Correction.Kind.allCases, id: \.self) { kind in
                    FilterChip(label: kind.label, isOn: filter == kind) { filter = kind }
                }
            }
        }
    }

    private var filteredCards: [ErrorCard] {
        let cards = appState.cards.sorted { $0.dueDate < $1.dueDate }
        guard let filter else { return cards }
        return cards.filter { $0.kind == filter }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ton carnet est vide")
                .font(Typography.title(20))
                .foregroundStyle(Palette.ink)
            Text("Il se remplira tout seul : chaque conversation y dépose les tournures que tu as ratées et celles que tu as évitées. Aucune liste de vocabulaire générique n'y entrera jamais.")
                .font(Typography.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 40)
    }
}

private struct FilterChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.captionEmphasis)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? .white : Palette.inkSecondary)
                .background(isOn ? Palette.accent : Palette.surfaceRaised)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CardRow: View {
    let card: ErrorCard

    var body: some View {
        CardSurface(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Pill(text: card.kind.label)
                    Spacer()
                    if card.isDue {
                        Pill(text: "à revoir", color: Palette.accent, background: Palette.accentSoft)
                    } else {
                        Text(card.dueDate, style: .relative)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }

                Text(card.target)
                    .font(Typography.title(18))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.prompt)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let mistake = card.originalMistake {
                    Text("tu avais dit « \(mistake) »")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
    }
}
