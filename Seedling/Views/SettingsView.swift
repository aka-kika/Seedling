import SwiftUI
import AppKit

// MARK: - Settings window

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: AppSettings

    private var templatesPath: String {
        settings.templatesFolderURL?.path ?? "Built-in library"
    }

    private var isCustomTemplates: Bool {
        settings.templatesFolderURL != nil
    }

    private var mainPath: String {
        settings.mainPathURL?.path ?? "Not set"
    }

    var body: some View {
        let theme = KikaTheme.resolve(scheme: colorScheme)

        // HIG: Use `Form` for settings windows — gives the proper Mac label
        // alignment, vertical rhythm, and keyboard focus order out of the box.
        Form {
            Section {
                templatesHero(theme: theme)
            } header: {
                Text("Templates folder")
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                KikaRow(icon: "folder", label: "Location") {
                    Text(mainPath)
                        .font(KikaFont.caption)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Button("Change…") {
                    pickMainPath()
                }
                .buttonStyle(KikaSecondaryButtonStyle())
                .accessibilityLabel("Change main path")
            } header: {
                Text("Main path")
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                KikaRow(icon: "sun.max", label: "Theme") {
                    themePicker(theme: theme)
                }
            } header: {
                Text("Appearance")
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                KikaRow(icon: "command", label: "Summon with ⌥⌘S") {
                    Toggle("", isOn: $settings.globalHotKeyEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Summon with Option Command S")
                }
                Text("Open Seedling from anywhere with a global keyboard shortcut. Turn this off if it conflicts with another app.")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Shortcut")
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                aboutBlock(theme: theme)
            } header: {
                Text("About")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 480)
        // HIG: settings windows are typically not user-resizable.
        .environment(\.kikaTheme, theme)
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    // MARK: - Templates hero

    private func templatesHero(theme: KikaTheme) -> some View {
        VStack(alignment: .leading, spacing: KikaSpacing.sm) {
            HStack(spacing: KikaSpacing.md) {
                Image(systemName: isCustomTemplates ? "folder.badge.gearshape" : "tray")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCustomTemplates ? "Custom templates" : "Built-in library")
                        .font(KikaFont.body)
                        .foregroundStyle(theme.textPrimary)
                    Text(templatesPath)
                        .font(KikaFont.caption)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            HStack(spacing: KikaSpacing.sm) {
                if isCustomTemplates {
                    Button("Clear") { settings.templatesFolderURL = nil }
                        .buttonStyle(KikaSecondaryButtonStyle())
                        .accessibilityLabel("Clear templates folder")
                }
                Button(isCustomTemplates ? "Change…" : "Choose…") {
                    pickTemplatesFolder()
                }
                .buttonStyle(KikaSecondaryButtonStyle())
                .accessibilityLabel(isCustomTemplates ? "Change templates folder" : "Choose templates folder")
            }

            Text("Markdown files in this folder are the seed files written into new projects when you click Seed. The built-in library is used when no folder is set.")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KikaSpacing.md)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Templates folder. \(isCustomTemplates ? "Custom" : "Built-in library").")
    }

    // MARK: - Theme picker

    private func themePicker(theme: KikaTheme) -> some View {
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

    // MARK: - About

    private func aboutBlock(theme: KikaTheme) -> some View {
        VStack(spacing: KikaSpacing.md) {
            // Centered leaf hero — the focal point of the About section.
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 44, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
            }
            .padding(.top, KikaSpacing.sm)
            .accessibilityHidden(true)  // the leaf is decorative; the name+version below carries the label

            VStack(spacing: 4) {
                Text("Seedling")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Version 2.0 (build 1)")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
                    .textSelection(.enabled)
            }

            Text("A calm menu bar app for seeding new projects with the right markdown files. Built on the KIKA Design System v2.")
                .font(KikaFont.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KikaSpacing.sm)

            Text("© 2026 Seedling")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .padding(.top, KikaSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KikaSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("About Seedling. Version 1.6. A calm menu bar app for seeding new projects with the right markdown files.")
    }

    private func pickTemplatesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            settings.setTemplatesFolder(from: url)
        }
    }

    private func pickMainPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            settings.setMainPath(url)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
