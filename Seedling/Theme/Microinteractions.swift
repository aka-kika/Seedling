import SwiftUI

/// Draws an accent hairline under a focused field. Reduce-motion → no animation.
struct FocusUnderline: ViewModifier {
    @Environment(\.kikaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var active: Bool
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            theme.accent
                .frame(height: 1)
                .scaleEffect(x: active ? 1 : 0, anchor: .leading)
                .opacity(active ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: active)
        }
    }
}

extension View {
    /// Accent hairline that draws in under a focused text field.
    func focusUnderline(_ active: Bool) -> some View { modifier(FocusUnderline(active: active)) }
}
