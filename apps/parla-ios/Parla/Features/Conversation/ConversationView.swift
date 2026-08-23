import SwiftUI

/// L'écran d'appel. Trois principes, tous contre-intuitifs pour une app de langue :
///
/// 1. **Pas de transcription mise en avant.** Le texte de l'interlocuteur est
///    masqué par défaut : lire au lieu d'écouter est la béquille numéro un, et
///    elle empêche exactement le travail qu'on vient faire.
/// 2. **Pas de bouton « parler ».** Le micro s'ouvre et se ferme tout seul.
/// 3. **Aucune correction affichée.** Rien, jusqu'au raccrochage.
@MainActor
struct ConversationView: View {
    let scenario: Scenario
    let profile: UserProfile

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var engine: ConversationEngine?
    @State private var stage: Stage = .briefing
    @State private var showsSubtitles = false
    @State private var elapsed: TimeInterval = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Stage: Equatable {
        case briefing
        case live
        case analyzing
        case debrief(Debrief, ConversationSession)
        case failed(String)

        static func == (lhs: Stage, rhs: Stage) -> Bool {
            switch (lhs, rhs) {
            case (.briefing, .briefing), (.live, .live), (.analyzing, .analyzing): true
            case (.debrief, .debrief): true
            case (.failed, .failed): true
            default: false
            }
        }
    }

    var body: some View {
        Group {
            switch stage {
            case .briefing:
                briefing
            case .live:
                liveCall
            case .analyzing:
                analyzing
            case .debrief(let debrief, let session):
                DebriefView(debrief: debrief, session: session, scenario: scenario) {
                    dismiss()
                }
            case .failed(let message):
                failure(message)
            }
        }
        .screenBackground()
        .onReceive(ticker) { _ in
            if stage == .live { elapsed += 1 }
        }
    }

    // MARK: - Briefing

    private var briefing: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundStyle(Palette.inkSecondary)
                }
            }
            .padding(Layout.gutter)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Pill(text: scenario.category.label, color: Palette.accent, background: Palette.accentSoft)
                        Text(scenario.title)
                            .font(Typography.display(28))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    CardSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            briefingRow("La situation", scenario.situation)
                            Divider().overlay(Palette.hairline)
                            briefingRow("En face", "\(scenario.interlocutor.name) — \(scenario.interlocutor.persona)")
                            Divider().overlay(Palette.hairline)
                            briefingRow("Ton objectif", scenario.objective)
                        }
                    }

                    // Les règles sont rappelées à chaque fois, exprès : elles sont
                    // contre-intuitives et ce sont elles qui font marcher le truc.
                    VStack(alignment: .leading, spacing: 10) {
                        rule("mic.fill", "Le micro s'ouvre tout seul. Parle quand tu veux, arrête-toi quand tu veux.")
                        rule("eye.slash.fill", "Tu n'auras pas le texte sous les yeux. C'est le but.")
                        rule("checkmark.shield.fill", "Personne ne te corrigera pendant que tu parles. Dis-le mal, mais dis-le.")
                        rule("hand.raised.fill", "Si tu bloques vraiment, un bouton te souffle un début de phrase.")
                    }
                }
                .padding(Layout.gutter)
            }

            PrimaryButton(title: "Décrocher", icon: "phone.fill") {
                startCall()
            }
            .padding(Layout.gutter)
        }
    }

    private func briefingRow(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
                .kerning(0.8)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Palette.accent)
                .frame(width: 20)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Appel en cours

    @ViewBuilder
    private var liveCall: some View {
        if let engine {
            VStack(spacing: 0) {
                callHeader

                Spacer()

                VStack(spacing: 26) {
                    interlocutorAvatar(engine)
                    phaseIndicator(engine)

                    if showsSubtitles {
                        subtitles(engine)
                    }

                    if !engine.rescueSuggestions.isEmpty {
                        rescuePanel(engine)
                    }
                }
                .padding(.horizontal, Layout.gutter)

                Spacer()

                callControls(engine)
            }
        }
    }

    private var callHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(scenario.interlocutor.name)
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text(elapsed.minutesLabel)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .monospacedDigit()
            }
            Spacer()
            Button {
                withAnimation { showsSubtitles.toggle() }
            } label: {
                Image(systemName: showsSubtitles ? "captions.bubble.fill" : "captions.bubble")
                    .foregroundStyle(showsSubtitles ? Palette.accent : Palette.inkTertiary)
            }
        }
        .padding(Layout.gutter)
    }

    private func interlocutorAvatar(_ engine: ConversationEngine) -> some View {
        ZStack {
            Circle()
                .fill(Palette.accentSoft)
                .frame(width: 132, height: 132)
                .scaleEffect(engine.synthesizer.isSpeaking ? 1.06 : 1)
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: engine.synthesizer.isSpeaking
                )

            Text(String(scenario.interlocutor.name.prefix(1)))
                .font(Typography.display(46))
                .foregroundStyle(Palette.accent)
        }
    }

    private func phaseIndicator(_ engine: ConversationEngine) -> some View {
        VStack(spacing: 14) {
            switch engine.phase {
            case .listening:
                VoiceWave(level: engine.recognizer.audioLevel)
                    .frame(height: 52)
                Text("À toi")
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Palette.accent)

            case .interlocutorSpeaking:
                Text("\(scenario.interlocutor.name) parle…")
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkSecondary)

            case .thinking, .connecting:
                SwiftUI.ProgressView().tint(Palette.inkTertiary)

            case .failed(let message):
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.accent)
                    .multilineTextAlignment(.center)

            default:
                EmptyView()
            }
        }
        .frame(height: 90)
    }

    private func subtitles(_ engine: ConversationEngine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !engine.streamingReply.isEmpty {
                Text(engine.streamingReply)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
            }
            if engine.phase == .listening, !engine.recognizer.transcript.isEmpty {
                Text(engine.recognizer.transcript)
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.layoutDirection, profile.language.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    private func rescuePanel(_ engine: ConversationEngine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Des amorces — à compléter toi-même")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkTertiary)
            ForEach(engine.rescueSuggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func callControls(_ engine: ConversationEngine) -> some View {
        HStack(spacing: 16) {
            controlButton(icon: "hand.raised.fill", label: "Je bloque") {
                engine.requestRescue()
            }

            Button {
                endCall(engine)
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Palette.accent)
                    .clipShape(Circle())
            }

            controlButton(icon: "arrow.turn.up.left", label: "Reprendre") {
                engine.interrupt()
            }
        }
        .padding(.bottom, 30)
    }

    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Palette.surfaceRaised)
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Analyse

    private var analyzing: some View {
        VStack(spacing: 18) {
            SwiftUI.ProgressView().tint(Palette.accent)
            Text("On repasse la conversation…")
                .font(Typography.title(19))
                .foregroundStyle(Palette.ink)
            Text("Ce que tu as dit, ce qu'un natif aurait dit, et surtout ce que tu as évité de dire.")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(Palette.accent)
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            SecondaryButton(title: "Fermer") { dismiss() }
                .padding(.horizontal, 60)
        }
        .padding(Layout.gutter)
    }

    // MARK: - Actions

    private func startCall() {
        let engine = ConversationEngine(scenario: scenario, profile: profile, client: appState.client)
        self.engine = engine
        stage = .live
        elapsed = 0
        Task { await engine.start() }
    }

    private func endCall(_ engine: ConversationEngine) {
        let session = engine.end()
        // Une conversation d'un seul tour n'a rien à analyser : on économise
        // l'appel et on évite un débrief vide qui donnerait l'impression que
        // l'app ne sait rien dire.
        guard session.userTurns.count >= 2 else {
            dismiss()
            return
        }

        stage = .analyzing
        Task {
            do {
                let debrief = try await appState.debriefService.analyze(
                    session: session,
                    scenario: scenario,
                    profile: profile
                )
                appState.record(session: session, debrief: debrief)
                stage = .debrief(debrief, session)
            } catch {
                stage = .failed("L'analyse a échoué : \(error.localizedDescription)")
            }
        }
    }
}
