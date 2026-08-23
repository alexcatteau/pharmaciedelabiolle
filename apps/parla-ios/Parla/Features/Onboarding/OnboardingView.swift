import SwiftUI

/// L'onboarding a un seul vrai job : **nommer le problème de l'utilisateur mieux
/// qu'il ne sait le faire lui-même**. Quelqu'un qui lit « tu comprends tout mais
/// tu n'arrives pas à parler » sur le premier écran sait immédiatement que l'app
/// est faite pour lui — c'est la promesse, et c'est aussi la conversion.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    @State private var step: Step = .welcome
    @State private var language: TargetLanguage = .italian
    @State private var variantID: String = "standard"
    @State private var comprehension: CEFRLevel = .b2
    @State private var production: CEFRLevel = .a2
    @State private var motivations: Set<Motivation> = []

    enum Step: Int, CaseIterable {
        case welcome, language, variant, levels, motivations
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                ProgressBar(progress: Double(step.rawValue) / Double(Step.allCases.count - 1))
                    .padding(.horizontal, Layout.gutter)
                    .padding(.top, 8)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    switch step {
                    case .welcome: welcomeStep
                    case .language: languageStep
                    case .variant: variantStep
                    case .levels: levelsStep
                    case .motivations: motivationsStep
                    }
                }
                .padding(Layout.gutter)
            }

            footer
        }
        .screenBackground()
    }

    // MARK: - Étapes

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 40)

            Text("Parla")
                .font(Typography.display(44))
                .foregroundStyle(Palette.ink)

            Text("Tu comprends tout.\nTu n'arrives pas à parler.")
                .font(Typography.display(28))
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)

            Text("""
            C'est un cas très particulier, et aucune app grand public ne le traite. \
            Elles t'apprennent des mots que tu connais déjà, et te font cliquer sur \
            la bonne réponse au lieu de la dire.

            Ici il n'y a qu'un exercice : des conversations à voix haute, avec quelqu'un \
            qui ne ralentit pas et qui ne te corrige jamais pendant que tu parles. \
            Tout le travail arrive après avoir raccroché.
            """)
            .font(Typography.body)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

            if appState.isDemoMode {
                DemoModeBanner()
            }
        }
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Quelle langue ?", subtitle: "Celle que tu entends depuis toujours.")

            ForEach(TargetLanguage.allCases) { candidate in
                SelectableRow(
                    title: candidate.displayName,
                    subtitle: candidate.endonym,
                    leading: candidate.flag,
                    isSelected: language == candidate
                ) {
                    language = candidate
                    variantID = candidate.variants.first?.id ?? "standard"
                }
            }
        }
    }

    private var variantStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(
                title: "Laquelle, exactement ?",
                subtitle: "Tu n'as pas besoin de la langue des journaux télévisés. Tu as besoin de celle qu'on te parle."
            )

            ForEach(language.variants) { variant in
                SelectableRow(
                    title: variant.label,
                    subtitle: nil,
                    leading: nil,
                    isSelected: variantID == variant.id
                ) {
                    variantID = variant.id
                }
            }
        }
    }

    private var levelsStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            SectionHeader(
                title: "Deux niveaux, pas un",
                subtitle: "C'est tout le sujet : le tien n'est pas le même selon qu'on t'écoute ou qu'on te parle."
            )

            LevelPicker(
                title: "Quand on te parle, tu comprends…",
                selection: $comprehension
            )

            LevelPicker(
                title: "Quand c'est à toi de parler…",
                selection: $production
            )

            if comprehension.rank > production.rank {
                CardSurface {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(comprehension.rank - production.rank) niveaux d'écart")
                            .font(Typography.title(17))
                            .foregroundStyle(Palette.accent)
                        Text("C'est exactement le profil que Parla travaille. Tout ce que l'app te proposera vise à combler cet écart, pas à te réapprendre ce que tu comprends déjà.")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var motivationsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(
                title: "Pour quoi faire ?",
                subtitle: "Ça détermine les situations qu'on va te faire vivre. Plusieurs réponses possibles."
            )

            ForEach(Motivation.allCases) { motivation in
                SelectableRow(
                    title: motivation.label,
                    subtitle: nil,
                    leading: nil,
                    icon: motivation.icon,
                    isSelected: motivations.contains(motivation)
                ) {
                    if motivations.contains(motivation) {
                        motivations.remove(motivation)
                    } else {
                        motivations.insert(motivation)
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    private var footer: some View {
        VStack(spacing: 10) {
            PrimaryButton(
                title: step == .motivations ? "Commencer" : "Continuer",
                isEnabled: canContinue
            ) {
                advance()
            }

            if step != .welcome {
                Button("Retour") {
                    withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .welcome }
                }
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(Layout.gutter)
    }

    private var canContinue: Bool {
        step != .motivations || !motivations.isEmpty
    }

    private func advance() {
        if step == .motivations {
            var profile = UserProfile.makeDefault(language: language)
            profile.variantID = variantID
            profile.comprehension = comprehension
            profile.production = production
            profile.motivations = motivations
            appState.completeOnboarding(with: profile)
        } else {
            withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .motivations }
        }
    }
}

// MARK: - Sous-vues

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceRaised)
                Capsule().fill(Palette.accent).frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 3)
        .animation(.easeInOut(duration: 0.25), value: progress)
    }
}

private struct SelectableRow: View {
    let title: String
    var subtitle: String?
    var leading: String?
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let leading {
                    Text(leading).font(.system(size: 26))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundStyle(isSelected ? Palette.accent : Palette.inkTertiary)
                        .frame(width: 26)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typography.bodyEmphasis).foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle).font(Typography.caption).foregroundStyle(Palette.inkSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Palette.accent : Palette.hairline)
            }
            .padding(16)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Layout.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.controlRadius, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Palette.hairline, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LevelPicker: View {
    let title: String
    @Binding var selection: CEFRLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Typography.bodyEmphasis).foregroundStyle(Palette.ink)

            ForEach(CEFRLevel.allCases) { level in
                Button {
                    selection = level
                } label: {
                    HStack(spacing: 12) {
                        Text(level.label)
                            .font(Typography.captionEmphasis)
                            .frame(width: 30)
                            .foregroundStyle(selection == level ? Color.white : Palette.inkSecondary)
                            .padding(.vertical, 5)
                            .background(selection == level ? Palette.accent : Palette.surfaceRaised)
                            .clipShape(Capsule())

                        Text(level.description)
                            .font(Typography.caption)
                            .foregroundStyle(selection == level ? Palette.ink : Palette.inkSecondary)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
