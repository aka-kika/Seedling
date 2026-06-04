import SwiftUI
import AppKit

// MARK: - Settings window (tabbed via a sage segmented control)

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: AppSettings

    private enum Tab: String, CaseIterable, Identifiable {
        case gardening = "Gardening"
        case keyboard  = "Keyboard"
        case about     = "About"
        var id: String { rawValue }
    }
    @State private var tab: Tab = .gardening

    private var templatesPath: String {
        settings.templatesFolderURL?.path ?? "Built-in library"
    }
    private var isCustomTemplates: Bool {
        settings.templatesFolderURL != nil
    }
    private var gardenPath: String {
        settings.projectsHomeURL?.path ?? "Not set"
    }

    var body: some View {
        let theme = KikaTheme.resolve(scheme: colorScheme)

        VStack(spacing: KikaSpacing.md) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            .padding(.top, 16)

            switch tab {
            case .gardening: gardeningTab(theme: theme)
            case .keyboard:  keyboardTab(theme: theme)
            case .about:     aboutTab(theme: theme)
            }
        }
        .frame(width: 440)          // width fixed; height hugs each tab's content
        .tint(theme.accent)         // sage selection everywhere, not the system accent
        .environment(\.kikaTheme, theme)
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    // MARK: - Gardening tab (Root + Garden + theme)

    private func gardeningTab(theme: KikaTheme) -> some View {
        VStack(spacing: KikaSpacing.md) {
            folderHero(
                theme: theme,
                icon: isCustomTemplates ? "folder.badge.gearshape" : "tray",
                title: isCustomTemplates ? "Your seeds — the Root" : "Built-in seeds — the Root",
                path: templatesPath,
                buttons: {
                    HStack(spacing: KikaSpacing.sm) {
                        if isCustomTemplates {
                            Button("Clear") { settings.templatesFolderURL = nil }
                                .buttonStyle(KikaSecondaryButtonStyle())
                                .accessibilityLabel("Clear seed root")
                        }
                        Button(isCustomTemplates ? "Change…" : "Choose…") { pickTemplatesFolder() }
                            .buttonStyle(KikaSecondaryButtonStyle())
                            .accessibilityLabel(isCustomTemplates ? "Change seed root" : "Choose seed root")
                    }
                },
                note: "The folder with your .md files — the seeds planted into every new project."
            )

            folderHero(
                theme: theme,
                icon: "tree",
                title: "Your garden",
                path: gardenPath,
                buttons: {
                    Button("Change…") { pickProjectsHome() }
                        .buttonStyle(KikaSecondaryButtonStyle())
                        .accessibilityLabel("Change garden")
                },
                note: "Where projects grow — each one a named subfolder, seeded on the spot."
            )

            HStack {
                Spacer()
                themePicker
                Spacer()
            }
            .frame(minHeight: 28)
        }
        .padding(KikaSpacing.lg)
    }

    private var themePicker: some View {
        Picker("Theme", selection: $settings.appearance) {
            ForEach(AppSettings.Appearance.allCases) { appearance in
                Image(systemName: appearance.symbolName)
                    .tag(appearance)
                    .accessibilityLabel(appearance.title)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 150)
        .labelsHidden()
        .accessibilityLabel("Theme")
    }

    // MARK: - Keyboard tab

    private func keyboardTab(theme: KikaTheme) -> some View {
        VStack(alignment: .leading, spacing: KikaSpacing.sm) {
            HStack(spacing: KikaSpacing.md) {
                Image(systemName: "command")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 18)
                Text("Summon Seedling")
                    .font(KikaFont.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                keyCap("⌥⌘S", theme: theme)
                Toggle("", isOn: $settings.globalHotKeyEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(theme.accent)
                    .accessibilityLabel("Summon with Option Command S")
            }
            .frame(minHeight: 32)

            shortcutRow("Grow · enter the garden", "⏎", theme: theme)
            shortcutRow("Dismiss", "esc", theme: theme)
            shortcutRow("Settings", "⌘,", theme: theme)
            shortcutRow("Quit", "⌘Q", theme: theme)

            Text("Summon works from anywhere; turn it off if it conflicts with another app.")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, KikaSpacing.sm)
        }
        .padding(KikaSpacing.lg)
    }

    // MARK: - About tab

    private func aboutTab(theme: KikaTheme) -> some View {
        VStack(spacing: KikaSpacing.md) {
            // Load the icon straight from the bundle (.icns) so it shows even if
            // Launch Services has cached the generic icon for this dev build.
            Image(nsImage: appIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
                .padding(.top, KikaSpacing.sm)

            VStack(spacing: 4) {
                Text("Seedling")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Version 3.0 (build 1)")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
                    .textSelection(.enabled)
            }

            Text("A calm app for seeding new projects with the right markdown files.")
                .font(KikaFont.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KikaSpacing.lg)

            Text("© 2026 Seedling")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(KikaSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("About Seedling. Version 3.0. A calm app for seeding new projects with the right markdown files.")
    }

    /// The app icon, loaded from the asset catalog (full-res), then the bundled
    /// `.icns`, then the running app's icon. Bypasses the Launch Services cache.
    private var appIconImage: NSImage {
        if let named = NSImage(named: "AppIcon") { return named }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSApplication.shared.applicationIconImage
    }

    // MARK: - Shared folder hero card

    private func folderHero<Buttons: View>(
        theme: KikaTheme,
        icon: String,
        title: String,
        path: String,
        @ViewBuilder buttons: () -> Buttons,
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: KikaSpacing.sm) {
            HStack(spacing: KikaSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
                    .frame(width: 34, height: 34)
                    .background(theme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KikaFont.body)
                        .foregroundStyle(theme.textPrimary)
                    Text(path)
                        .font(KikaFont.caption)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
                buttons()
            }
            Text(note)
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KikaSpacing.md)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Keyboard shortcut rows

    private func keyCap(_ keys: String, theme: KikaTheme) -> some View {
        Text(keys)
            .font(KikaFont.caption)
            .foregroundStyle(theme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(theme.elevated))
            .accessibilityLabel(keys)
    }

    private func shortcutRow(_ label: String, _ keys: String, theme: KikaTheme) -> some View {
        HStack {
            Text(label)
                .font(KikaFont.body)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            keyCap(keys, theme: theme)
        }
        .frame(minHeight: 30)
    }

    // MARK: - Folder pickers

    private func pickTemplatesFolder() {
        if let url = chooseDirectory() {
            settings.setTemplatesFolder(from: url)
        }
    }

    private func pickProjectsHome() {
        if let url = chooseDirectory() {
            settings.setProjectsHome(url)
        }
    }

    /// Folder chooser, app activated first so the panel comes to the front.
    private func chooseDirectory() -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.level = .modalPanel
        return panel.runModal() == .OK ? panel.url : nil
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
