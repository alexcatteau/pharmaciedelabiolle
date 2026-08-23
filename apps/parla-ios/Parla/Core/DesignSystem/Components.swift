import SwiftUI

// MARK: - Boutons

struct PrimaryButton: View {
    let title: String
    var icon: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).font(Typography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Palette.accent : Palette.surfaceRaised)
            .foregroundStyle(isEnabled ? Color.white : Palette.inkTertiary)
            .clipShape(RoundedRectangle(cornerRadius: Layout.controlRadius, style: .continuous))
        }
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).font(Typography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Palette.ink)
            .background(Palette.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Layout.controlRadius, style: .continuous))
        }
    }
}

// MARK: - Conteneurs

struct CardSurface<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Typography.title(19)).foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle).font(Typography.caption).foregroundStyle(Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Pill: View {
    let text: String
    var color: Color = Palette.inkSecondary
    var background: Color = Palette.surfaceRaised

    var body: some View {
        Text(text)
            .font(Typography.captionEmphasis)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(background)
            .clipShape(Capsule())
    }
}

// MARK: - Métriques

struct MetricTile: View {
    let value: String
    let unit: String?
    let label: String
    var accent: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(Typography.metric(30)).foregroundStyle(accent)
                if let unit {
                    Text(unit).font(Typography.caption).foregroundStyle(Palette.inkTertiary)
                }
            }
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Courbe de tendance minimaliste, sans axes ni grille : on ne cherche pas la
/// lecture précise, seulement la direction.
struct SparkLine: View {
    let values: [Double]
    var color: Color = Palette.accent

    var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints(in: geometry.size)
            ZStack {
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    if let last = points.last {
                        Circle().fill(color).frame(width: 6, height: 6).position(last)
                    }
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let range = max(maximum - minimum, 0.0001)
        let step = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let ratio = (value - minimum) / range
            return CGPoint(x: CGFloat(index) * step, y: size.height * (1 - ratio))
        }
    }
}

// MARK: - Onde vocale

/// Onde réagissant au niveau sonore. Sa seule fonction est de dire
/// « je t'entends » — sans elle, l'utilisateur qui parle dans le vide doute
/// et s'arrête.
struct VoiceWave: View {
    let level: Float
    var color: Color = Palette.accent
    var barCount: Int = 5

    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 5, height: height(for: index))
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let base: CGFloat = 8
        let amplitude = CGFloat(max(0.06, level)) * 44
        // Décalage sinusoïdal pour que les barres ne montent pas toutes ensemble.
        let offset = sin(Double(index) * 0.9 + phase)
        return base + amplitude * CGFloat(0.55 + 0.45 * offset)
    }
}

// MARK: - Divers

struct DemoModeBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode démo").font(Typography.captionEmphasis)
                Text("Réponses simulées. Configure une clé ou un proxy — voir le README.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Palette.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func screenBackground() -> some View {
        self.background(Palette.canvas.ignoresSafeArea())
    }
}

extension TimeInterval {
    /// « 3,4 s » — la latence se lit en dixièmes, c'est là que la progression se voit.
    var secondsLabel: String {
        String(format: "%.1f", self).replacingOccurrences(of: ".", with: ",")
    }

    var minutesLabel: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
