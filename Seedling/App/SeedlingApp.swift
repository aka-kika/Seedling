//
//  SeedlingApp.swift
//  Seedling
//
//  Menu bar app that creates default markdown files in a chosen folder.
//  Built on the KIKA Design System v2 (calm, premium, dark-first with light mode).
//
//  Architecture:
//  - The `AppDelegate` owns an `NSStatusItem`.
//  - Left-click on the leaf icon / ⌥⌘S → centered ceremony window (CeremonyWindowController).
//  - Right-click on the leaf icon → NSMenu (About / Settings / Quit).
//  - Settings opens the standard SwiftUI `Settings` scene.
//  - `Commands` adds the standard App menu (About / Settings / Quit) so the
//    app behaves correctly when activated (e.g. focus moves to Settings).
//

import SwiftUI

@main
struct SeedlingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A valid scene is required, but we never surface the SwiftUI Settings
        // window — its opener (`showSettingsWindow:`) is deprecated/broken for
        // accessory apps on macOS 14+. Settings is shown via our own
        // SettingsWindowController instead (see AppDelegate.openSettings()).
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button("About Seedling") {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.orderFrontStandardAboutPanel(nil)
                    }
                }
                // Route the standard ⌘, / "Settings…" item to our own window.
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { appDelegate.openSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
