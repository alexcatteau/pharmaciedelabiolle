import SwiftUI
import UIKit

/// Direction artistique : **adulte, chaude, non gamifiée**.
///
/// C'est un choix produit, pas décoratif. Les couleurs vives, les mascottes et les
/// confettis signalent « application pour enfants » et sont la première raison
/// pour laquelle un adulte de 30 ans abandonne une app de langue. Ici : papier
/// crème, encre profonde, un seul accent chaud, aucune illustration.
enum Palette {
    static let ink = adaptive(light: 0x1A1614, dark: 0xF2EDE6)
    static let inkSecondary = adaptive(light: 0x6B625C, dark: 0x9E948C)
    static let inkTertiary = adaptive(light: 0x9A918B, dark: 0x6E6660)

    static let canvas = adaptive(light: 0xFBF8F4, dark: 0x121010)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1E1B19)
    static let surfaceRaised = adaptive(light: 0xF4EFE8, dark: 0x2A2624)

    static let accent = adaptive(light: 0xE84A5C, dark: 0xF25D6B)
    static let accentSoft = adaptive(light: 0xFCE9EB, dark: 0x3A2226)

    /// Vert sobre pour les réussites. Jamais saturé : on félicite discrètement.
    static let success = adaptive(light: 0x2E7D5B, dark: 0x4CAF87)
    static let warning = adaptive(light: 0xB8760E, dark: 0xE0A343)

    static let hairline = adaptive(light: 0xE6DFD6, dark: 0x322D2A)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum Typography {
    /// Sérif sur les titres : c'est le signal le plus économique pour dire
    /// « outil sérieux » plutôt que « jeu ».
    static func display(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static let body = Font.system(size: 16, weight: .regular)
    static let bodyEmphasis = Font.system(size: 16, weight: .semibold)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionEmphasis = Font.system(size: 13, weight: .semibold)

    /// Chiffres tabulaires arrondis pour les métriques : elles doivent être
    /// lisibles d'un coup d'œil et ne pas « sauter » quand elles changent.
    static func metric(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

enum Layout {
    static let gutter: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let controlRadius: CGFloat = 14
    static let stackSpacing: CGFloat = 14
}
