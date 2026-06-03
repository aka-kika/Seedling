import SwiftUI
import AppKit

// MARK: - Settings window (tabbed)

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: AppSettings

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

        TabView {
            rootTab(theme: theme)
                .tabItem { Label("Root", systemImage: "leaf") }
            gardenTab(theme: theme)
                .tabItem { Label("Garden", systemImage: "tree") }
            appearanceTab(theme: theme)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            keyboardTab(theme: theme)
                .tabItem { Label("Keyboard", systemImage: "command") }
            aboutTab(theme: theme)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 440)
        .environment(\.kikaTheme, theme)
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    // MARK: - Root tab (the seed source)

    private func rootTab(theme: KikaTheme) -> some View {
        VStack(spacing: KikaSpacing.md) {
            folderHero(
                theme: theme,
                icon: isCustomTemplates ? "folder.badge.gearshape" : "tray",
                title: isCustomTemplates ? "Your seeds" : "Built-in seeds",
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
                note: "The folder with your .md files — the seeds planted into each new project. The built-in library is used when no folder is set."
            )
            Spacer(minLength: 0)
        }
        .padding(KikaSpacing.lg)
    }

    // MARK: - Garden tab (where projects grow)

    private func gardenTab(theme: KikaTheme) -> some View {
        VStack(spacing: KikaSpacing.md) {
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
                note: "New projects grow as subfolders in your garden. Naming a project creates a folder with that name and plants the seeds inside it."
            )
            Spacer(minLength: 0)
        }
        .padding(KikaSpacing.lg)
    }

    // MARK: - Appearance tab

    private func appearanceTab(theme: KikaTheme) -> some View {
        VStack(alignment: .leading, spacing: KikaSpacing.md) {
            KikaRow(icon: "paintbrush", label: "Theme") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { appearance in
                        Image(systemName: appearance.symbolName)
                            .tag(appearance)
                            .accessibilityLabel(appearance.title)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
                .labelsHidden()
                .accessibilityLabel("Theme")
            }
            Spacer(minLength: 0)
        }
        .padding(KikaSpacing.lg)
    }

    // MARK: - Keyboard tab

    private func keyboardTab(theme: KikaTheme) -> some View {
        VStack(alignment: .leading, spacing: KikaSpacing.sm) {
            KikaRow(icon: "command", label: "Summon Seedling") {
                HStack(spacing: KikaSpacing.sm) {
                    keyCap("⌥⌘S", theme: theme)
                    Toggle("", isOn: $settings.globalHotKeyEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Summon with Option Command S")
                }
            }
            shortcutRow("Grow · enter the garden", "⏎", theme: theme)
            shortcutRow("Dismiss", "esc", theme: theme)
            shortcutRow("Settings", "⌘,", theme: theme)
            shortcutRow("Quit", "⌘Q", theme: theme)
            Text("Summon works from anywhere; turn it off if it conflicts with another app.")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, KikaSpacing.sm)
            Spacer(minLength: 0)
        }
        .padding(KikaSpacing.lg)
    }

    // MARK: - About tab

    private func aboutTab(theme: KikaTheme) -> some View {
        VStack(spacing: KikaSpacing.md) {
            Spacer(minLength: 0)
            // The real app icon (falls back to the generic one until an AppIcon
            // asset is added — it then appears here automatically).
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Seedling")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Version 3.0 (build 1)")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
                    .textSelection(.enabled)
            }

            Text("A calm app for seeding new projects with the right markdown files. Built on the KIKA Design System v2.")
                .font(KikaFont.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KikaSpacing.lg)

            Text("© 2026 Seedling")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(KikaSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("About Seedling. Version 3.0. A calm app for seeding new projects with the right markdown files.")
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
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
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
            }
            buttons()
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
        .frame(minHeight: 28)
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
