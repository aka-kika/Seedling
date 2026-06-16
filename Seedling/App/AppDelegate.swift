import SwiftUI
import AppKit
import Combine

// MARK: - AppDelegate
//
// Owns the NSStatusItem that lives in the menu bar.
// - Click: pops the leaf menu (Open Seedling / Settings… / Quit). macOS 27 stopped
//   delivering right-clicks to status items, so the menu *is* the primary gesture.
// - Open Seedling / ⌥⌘S: summons the centered ceremony window (the seed workflow).
//
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    /// Strong reference to the settings object (also injected into SwiftUI scenes).
    let settings = AppSettings()

    /// The centered ceremony window (replaces the old menu-bar popover).
    private lazy var ceremony = CeremonyWindowController(settings: settings)

    /// Self-managed settings window (the SwiftUI Settings opener is broken on macOS 14+).
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    /// System-wide ⌥⌘S summon hotkey (Carbon-backed, no Accessibility prompt).
    private let hotKey = GlobalHotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the Dock/app icon from the asset catalog at runtime. Launch
        // Services stubbornly caches the generic icon for dev builds run from
        // DerivedData; assigning applicationIconImage bypasses that cache so the
        // real icon shows in the Dock (while Settings/About is open) and About.
        if let icon = NSImage(named: "AppIcon")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap({ NSImage(contentsOf: $0) }) {
            NSApp.applicationIconImage = icon
        }

        configureStatusItem()
        updateStatusItemIcon()

        // Register Seedling as a Services provider so Finder shows
        // "Seed this folder" on a selected folder.
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        // Return to menu-bar-only (no Dock icon) once Settings/About closes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        // React to templates folder changes by swapping the status item icon.
        settings.$templatesFolderURL
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItemIcon() }
            .store(in: &cancellables)

        // Register / unregister the global hotkey as the user toggles it.
        settings.$globalHotKeyEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshHotKey() }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Status item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleButtonPress(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItemIcon()
    }

    /// `leaf` for the default state, `leaf.fill` when the user has configured a
    /// custom templates folder. A subtle status signal.
    private func updateStatusItemIcon() {
        guard let button = statusItem.button else { return }
        let hasTemplates = settings.templatesFolderURL != nil
        let symbolName = hasTemplates ? "leaf.fill" : "leaf"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Seedling")
        image?.isTemplate = true
        button.image = image
    }

    // MARK: - Button handler

    @objc private func handleButtonPress(_ sender: NSStatusBarButton) {
        // Any click pops the leaf menu. macOS 27 stopped delivering right-mouse
        // events to status items, so we no longer branch on the gesture — the
        // menu carries "Open Seedling" as its first item.
        showLeafMenu(from: sender)
    }

    // MARK: - Global hotkey

    private func refreshHotKey() {
        if settings.globalHotKeyEnabled {
            hotKey.register { [weak self] in self?.ceremony.summon() }
        } else {
            hotKey.unregister()
        }
    }

    // MARK: - Finder Service ("Seed this folder")

    /// Services entry point. Declared in Info.plist as NSMessage = "seedFolderFromService";
    /// the runtime calls `seedFolderFromService:userData:error:`.
    @objc func seedFolderFromService(_ pboard: NSPasteboard,
                                     userData: String,
                                     error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        // Resolve the first URL that is actually a directory on disk. We can't rely
        // on URL.hasDirectoryPath here — the directory hint is lost across the
        // pasteboard round-trip a Service performs.
        let folder = urls.first { url in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
        guard let folder else {
            NSLog("[Seedling] Service: no directory URL on pasteboard (got \(urls.count) urls)")
            return
        }
        performHeadlessSeed(into: folder)
    }

    /// Seed a folder with no popover open (the Service path). Reuses the same
    /// engine + settings the popover uses, then confirms with the growth HUD and
    /// reveals the new files in Finder.
    private func performHeadlessSeed(into folder: URL) {
        let didStart = folder.startAccessingSecurityScopedResource()
        let files = settings.resolveSeedFiles()
        let options = ProjectOptions(
            folderURL: folder,
            projectName: folder.lastPathComponent,
            tagline: ""
        )
        DispatchQueue.global(qos: .userInitiated).async {
            let result: SeedResult?
            do {
                result = try Seedling.seed(files, into: folder, options: options)
            } catch {
                NSLog("[Seedling] Finder Service seed failed: \(error.localizedDescription)")
                result = nil
            }
            DispatchQueue.main.async {
                if didStart { folder.stopAccessingSecurityScopedResource() }
                guard let result else { return }
                let (theme, scheme) = self.currentThemeForHUD()
                SeedHUD.present(
                    message: "\(result.headline) · \(folder.lastPathComponent)",
                    theme: theme,
                    colorScheme: scheme
                )
                AccessibilityNotification.Announcement(result.headline).post()
                NSWorkspace.shared.open(folder)   // default file manager, not hard-coded Finder
            }
        }
    }

    /// Resolve the KIKA theme + SwiftUI color scheme the HUD should use, honoring
    /// the user's appearance preference (falling back to the system appearance).
    private func currentThemeForHUD() -> (KikaTheme, ColorScheme?) {
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

    // MARK: - Leaf menu
    //
    // The leaf's click pops this menu. "Open Seedling" summons the ceremony;
    // Settings/Quit live here permanently. We assemble + popUp the menu in the
    // action (rather than assigning statusItem.menu and re-driving performClick,
    // which went dark on macOS 27) — popUp is the path that still tracks there.

    private func showLeafMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Open Seedling — first item, so it's the default target. Summons (not
        // toggles) so picking it always brings the ceremony forward.
        let open = NSMenuItem(title: "Open Seedling", action: #selector(openCeremony), keyEquivalent: "")
        open.target = self
        // Show ⌥⌘S as a hint only when that global hotkey is actually live.
        if settings.globalHotKeyEnabled {
            open.keyEquivalent = "s"
            open.keyEquivalentModifierMask = [.command, .option]
        }
        menu.addItem(open)

        menu.addItem(NSMenuItem.separator())

        // Settings… (About now lives in a Settings tab)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quit = NSMenuItem(title: "Quit Seedling", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Light the leaf while the menu tracks, like a native status menu. popUp
        // is modal, so the highlight clears as soon as it returns.
        button.highlight(true)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 6), in: button)
        button.highlight(false)
    }

    // MARK: - Menu actions

    /// Open the settings window. We manage our own NSWindow (SettingsWindowController)
    /// because the SwiftUI `Settings` scene opener (`showSettingsWindow:`) is
    /// deprecated in macOS 14+ and no-ops for accessory apps. Briefly become a
    /// regular app so the window comes to the front; `handleWindowClose` drops
    /// back to `.accessory` when it closes.
    @objc func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.show()
    }

    /// "Open Seedling" menu item. Summon (not toggle) so the menu never closes
    /// the ceremony — picking it always shows and focuses the window.
    @objc private func openCeremony() {
        ceremony.summon()
    }

    /// When the last titled window (Settings/About) closes, return to being a
    /// pure menu-bar app (no Dock icon).
    @objc private func handleWindowClose(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            let titledVisible = NSApp.windows.contains {
                $0.styleMask.contains(.titled) && $0.isVisible
            }
            if !titledVisible {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
