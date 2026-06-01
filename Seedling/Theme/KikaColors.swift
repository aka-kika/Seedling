import SwiftUI

// MARK: - Color tokens (KIKA Design System v2)

enum KikaColors {
    // Dark
    static let backgroundDark  = Color(hex: 0x0D0D0D)
    static let surfaceDark     = Color(hex: 0x161616)
    static let elevatedDark    = Color(hex: 0x1F1F1F)
    static let borderDark      = Color(hex: 0x2A2A2A)
    static let textPrimaryDark = Color(hex: 0xD9D9D9)
    static let textSecondDark  = Color(hex: 0xBFBFBF)
    static let textTertDark    = Color(hex: 0x8C8C8C)
    static let accentDark      = Color(hex: 0x6D80A6)

    // Light
    static let backgroundLight  = Color(hex: 0xF8F8F8)
    static let surfaceLight     = Color.white
    static let elevatedLight    = Color(hex: 0xF0F0F0)
    static let borderLight      = Color(hex: 0xE0E0E0)
    static let textPrimaryLight = Color(hex: 0x1A1A1A)
    static let textSecondLight  = Color(hex: 0x4A4A4A)
    static let textTertLight    = Color(hex: 0x6B6B6B)
    static let accentLight      = Color(hex: 0x5A6E94)
}

enum KikaSpacing {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
}

enum KikaFont {
    static let title   = Font.system(size: 18, weight: .semibold)
    static let body    = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 11, weight: .regular)
}

// MARK: - Theme

struct KikaTheme {
    let background: Color
    let surface: Color
    let elevated: Color
    let border: Color
    let divider: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color

    static func resolve(scheme: ColorScheme) -> KikaTheme {
        switch scheme {
        case .dark:
            return KikaTheme(
                background:    KikaColors.backgroundDark,
                surface:       KikaColors.surfaceDark,
                elevated:      KikaColors.elevatedDark,
                border:        KikaColors.borderDark,
                divider:       Color.white.opacity(0.08),
                textPrimary:   KikaColors.textPrimaryDark,
                textSecondary: KikaColors.textSecondDark,
                textTertiary:  KikaColors.textTertDark,
                accent:        KikaColors.accentDark
            )
        default:
            return KikaTheme(
                background:    KikaColors.backgroundLight,
                surface:       KikaColors.surfaceLight,
                elevated:      KikaColors.elevatedLight,
                border:        KikaColors.borderLight,
                divider:       KikaColors.borderLight,
                textPrimary:   KikaColors.textPrimaryLight,
                textSecondary: KikaColors.textSecondLight,
                textTertiary:  KikaColors.textTertLight,
                accent:        KikaColors.accentLight
            )
        }
    }
}

private struct KikaThemeKey: EnvironmentKey {
    static let defaultValue: KikaTheme = .resolve(scheme: .light)
}

extension EnvironmentValues {
    var kikaTheme: KikaTheme {
        get { self[KikaThemeKey.self] }
        set { self[KikaThemeKey.self] = newValue }
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex         & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
