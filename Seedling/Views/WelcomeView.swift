import SwiftUI

/// First-run welcome. The copy arc: title → action → payoff.
/// "Plant your first seed" → [ Choose your path ] → "…and let it grow"
struct WelcomeView: View {
    @Environment(\.kikaTheme) private var theme
    let onChoose: () -> Void

    var body: some View {
        VStack(spacing: KikaSpacing.md) {
            Spacer(minLength: KikaSpacing.lg)
            Image(systemName: "leaf")
                .font(.system(size: 30, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.accent)
            Text("Plant your first seed")
                .font(KikaFont.title)
                .foregroundStyle(theme.textPrimary)
            Button("Choose your path") { onChoose() }
                .buttonStyle(KikaPrimaryButtonStyle())
                .keyboardShortcut("o", modifiers: [.command])
                .accessibilityLabel("Choose your path")
            Text("…and let it grow")
                .font(.system(size: 12, weight: .regular).italic())
                .foregroundStyle(theme.textSecondary)
            Text("⌥⌘S to summon from anywhere")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .padding(.top, KikaSpacing.sm)
            Spacer(minLength: KikaSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, KikaSpacing.lg)
    }
}
