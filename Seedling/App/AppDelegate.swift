import SwiftUI
import AppKit
import Combine

// MARK: - AppDelegate
//
// Owns the NSStatusItem that lives in the menu bar.
// - Left-click / ⌥⌘S: summons the centered ceremony window (the seed workflow)
// - Right-click: shows an NSMenu with About / Settings / Quit
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
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            ceremony.toggle()
        }
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

    // MARK: - Right-click context menu

    private func showContextMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // About
        let about = NSMenuItem(title: "About Seedling", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        // Settings…
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quit = NSMenuItem(title: "Quit Seedling", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menu actions

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

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
