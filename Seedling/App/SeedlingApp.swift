//
//  SeedlingApp.swift
//  Seedling
//
//  Menu bar app that creates default markdown files in a chosen folder.
//  Built on the KIKA Design System v2 (calm, premium, dark-first with light mode).
//
//  Architecture:
//  - The `AppDelegate` owns an `NSStatusItem`.
//  - Left-click on the leaf icon → SwiftUI popover (seed workflow).
//  - Right-click on the leaf icon → NSMenu (About / Settings / Theme / Quit).
//  - Settings opens the standard SwiftUI `Settings` scene.
//  - `Commands` adds the standard App menu (About / Settings / Quit) so the
//    app behaves correctly when activated (e.g. focus moves to Settings).
//

import SwiftUI

@main
struct SeedlingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
        }
        .windowResizability(.contentSize)

        // Add the standard App menu items. The Settings scene already wires ⌘,
        // to "Settings…", and the system provides Quit, but we make the App
        // menu explicit so VoiceOver / menu discoverability work correctly.
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Seedling") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}
