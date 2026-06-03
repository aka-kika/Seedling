import SwiftUI
import AppKit

// MARK: - SettingsWindowController
//
// Self-managed AppKit window hosting `SettingsView`. We don't use the SwiftUI
// `Settings` scene's opener (`showSettingsWindow:`) — Apple deprecated it in
// macOS 14+ and it silently no-ops for accessory (menu-bar) apps. Owning a plain
// NSWindow here is reliable and consistent with CeremonyWindowController.
//
@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            window.center()
            return
        }
        let hosting = NSHostingController(
            rootView: SettingsView().environmentObject(settings)
        )
        let win = NSWindow(contentViewController: hosting)
        win.title = "Seedling Settings"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        self.window = win
        win.makeKeyAndOrderFront(nil)
    }
}
