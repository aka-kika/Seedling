import SwiftUI
import AppKit

// MARK: - KeyablePanel
//
// A borderless NSPanel that is still allowed to become key, so the SwiftUI
// text field inside can take keyboard focus.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - CeremonyWindowController
//
// Owns the centered, borderless, glass ceremony panel that hosts
// SeedCeremonyView. Fades in centered on the active screen, takes key focus,
// and fades out when the ceremony finishes, on Esc, or on an outside click.
//
@MainActor
final class CeremonyWindowController {
    private let settings: AppSettings
    private let onSettings: () -> Void
    private var panel: KeyablePanel?
    private var outsideClickMonitor: Any?

    init(settings: AppSettings, onSettings: @escaping () -> Void = {}) {
        self.settings = settings
        self.onSettings = onSettings
    }

    var isShown: Bool { panel != nil }

    /// Show the window if hidden; bring it forward + refocus if already shown.
    func summon() {
        NSApp.activate(ignoringOtherApps: true)
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let (theme, scheme) = resolveTheme()
        let root = SeedCeremonyView(onFinish: { [weak self] in self?.dismiss() },
                                    onSettings: onSettings)
            .environmentObject(settings)
            .environment(\.kikaTheme, theme)
            .preferredColorScheme(scheme)

        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        // Clip the panel's content backing to the same rounded shape as the glass,
        // otherwise the square content layer shows a faint "cut" at the corners on
        // a light desktop (the glass is rounded but its backing isn't).
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.cornerRadius = 22
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        self.panel = panel

        centerOnActiveScreen(panel)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }
        installOutsideClickMonitor()
    }

    func toggle() {
        if isShown { dismiss() } else { summon() }
    }

    func dismiss() {
        guard let panel else { return }
        removeOutsideClickMonitor()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                self?.panel = nil
            }
        })
    }

    // MARK: Helpers

    private func centerOnActiveScreen(_ panel: NSPanel) {
        guard let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                     y: frame.midY - size.height / 2))
    }

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // Ignore clicks while a folder picker is up. A sandboxed NSOpenPanel
            // runs out-of-process, so its clicks arrive here as "other app"
            // events and would otherwise dismiss the ceremony mid-onboarding.
            guard NSApp.modalWindow == nil else { return }
            self?.dismiss()
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor {
            NSEvent.removeMonitor(m)
            outsideClickMonitor = nil
        }
    }

    /// Resolve the KIKA theme + SwiftUI color scheme honoring the user's
    /// appearance preference (mirrors AppDelegate's HUD theme resolution).
    private func resolveTheme() -> (KikaTheme, ColorScheme?) {
        let preferred = settings.appearance.colorScheme
        let scheme: ColorScheme
        if let preferred {
            scheme = preferred
        } else {
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            scheme = (match == .darkAqua) ? .dark : .light
        }
        return (KikaTheme.resolve(scheme: scheme), preferred)
    }
}
