import SwiftUI
import AppKit
import Combine

// MARK: - AppDelegate
//
// Owns the NSStatusItem that lives in the menu bar.
// - Left-click: toggles the SwiftUI popover (the seed workflow)
// - Right-click: shows an NSMenu with About / Settings / Theme submenu / Quit
//
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    /// Strong reference to the settings object (also injected into SwiftUI scenes).
    let settings = AppSettings()

    private var eventMonitor: Any?

    /// System-wide ⌥⌘S summon hotkey (Carbon-backed, no Accessibility prompt).
    private let hotKey = GlobalHotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()
        installOutsideClickMonitor()
        updateStatusItemIcon()

        // Register Seedling as a Services provider so Finder shows
        // "Seed this folder" on a selected folder.
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSeedDidComplete),
            name: .seedlingDidSeed,
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

    @objc private func handleSeedDidComplete() {
        // Close the popover after a longer delay so the user has time to read
        // the result, scan the file list, or click a file to reveal it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.popover.performClose(nil)
        }
    }

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

    // MARK: - Popover

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 340, height: 380)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContent()
                .environmentObject(settings)
        )
    }

    // MARK: - Outside click monitor
    // Ensures the popover dismisses when the user clicks anywhere outside it
    // (the transient behavior is close-but-not-quite — this is belt + suspenders).
    private func installOutsideClickMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if self.popover.isShown {
                self.popover.performClose(nil)
            }
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Button handler

    @objc private func handleButtonPress(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Global hotkey

    private func refreshHotKey() {
        if settings.globalHotKeyEnabled {
            hotKey.register { [weak self] in self?.summonPopover() }
        } else {
            hotKey.unregister()
        }
    }

    /// Bring Seedling forward (so the popover can take keyboard focus even when
    /// another app is frontmost) and toggle the popover.
    private func summonPopover() {
        NSApp.activate(ignoringOtherApps: true)
        togglePopover()
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
                self.settings.recordSeed(
                    folder: folder,
                    projectName: folder.lastPathComponent,
                    tagline: ""
                )
                let (theme, scheme) = self.currentThemeForHUD()
                SeedHUD.present(
                    message: "\(result.headline) · \(folder.lastPathComponent)",
                    theme: theme,
                    colorScheme: scheme
                )
                AccessibilityNotification.Announcement(result.headline).post()
                if !result.created.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(result.created)
                }
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

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // The standard Settings scene is opened with ⌘,; the same call works programmatically.
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
