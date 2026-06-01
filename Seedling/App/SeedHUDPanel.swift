import SwiftUI
import AppKit

// MARK: - SeedHUD
//
// A transient, borderless, non-activating panel that plays the seed-growth
// animation when a seed happens with no popover open (i.e. from the Finder
// "Seed this folder" Service). It fades in, plays the animation, then fades out
// and closes itself — the whole thing is the confirmation, no banner required.
//
@MainActor
final class SeedHUD {
    /// The currently-visible HUD, if any. Held so it isn't deallocated mid-animation.
    private static var live: SeedHUD?

    private let panel: NSPanel

    /// Present the growth HUD centered on the active screen. Replaces any HUD
    /// already on screen.
    static func present(message: String, theme: KikaTheme, colorScheme: ColorScheme?) {
        live?.dismissNow()
        let hud = SeedHUD(message: message, theme: theme, colorScheme: colorScheme)
        live = hud
        hud.show()
    }

    private init(message: String, theme: KikaTheme, colorScheme: ColorScheme?) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let root = SeedHUDContent(message: message) { [weak self] in
            self?.fadeOutAndClose()
        }
        .environment(\.kikaTheme, theme)
        .preferredColorScheme(colorScheme)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 220)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    private func show() {
        centerOnActiveScreen()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }
    }

    private func fadeOutAndClose() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.dismissNow()
        })
    }

    private func dismissNow() {
        panel.orderOut(nil)
        if SeedHUD.live === self { SeedHUD.live = nil }
    }

    private func centerOnActiveScreen() {
        guard let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                     y: frame.midY - size.height / 2))
    }
}

// MARK: - HUD content

private struct SeedHUDContent: View {
    let message: String
    let onDone: () -> Void

    @Environment(\.kikaTheme) private var theme

    var body: some View {
        VStack(spacing: KikaSpacing.sm) {
            SeedGrowthView(mode: .growth, onComplete: onDone)
            Text(message)
                .font(KikaFont.caption)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(KikaSpacing.lg)
        .frame(width: 200, height: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
