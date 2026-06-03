import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted when Seed completes successfully. The menu controller listens
    /// for this to auto-dismiss the popover.
    static let seedlingDidSeed = Notification.Name("SeedlingDidSeed")
}// MARK: - Menu bar popover

struct MenuBarContent: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    @State private var folderURL: URL?
    @State private var projectName: String = ""
    @State private var tagline: String = ""
    @State private var lastResult: SeedResult?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var didRestore = false
    /// Plays the "seed is born" beat when a folder is first chosen.
    @State private var birthPlaying = false
    /// Bumped on every successful seed so the growth animation replays from scratch.
    @State private var seedTick = 0
    /// Drives the fade-rise reveal of the filled state content.
    @State private var contentAppeared = false

    private enum Field { case name, tagline }
    @FocusState private var focusedField: Field?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canSeed: Bool {
        folderURL != nil && !isWorking
    }

    /// Files that will be written when the user hits Seed.
    /// Uses the templates folder if set and non-empty, otherwise built-in defaults.
    private var filesToSeed: [SeedFile] {
        settings.resolveSeedFiles()
    }

    // MARK: - Body

    var body: some View {
        let theme = KikaTheme.resolve(scheme: colorScheme)

        GlassEffectContainer {
            Group {
                if settings.mainPathURL == nil {
                    WelcomeView(onChoose: pickFirstPath)
                } else {
                    filledState(theme: theme)
                }
            }
            .frame(width: 360)
            // Liquid Glass surface — floats over the desktop with depth.
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
        // The "seed is born" beat, played over the popover the first time a
        // folder is chosen, then dismissed to reveal the filled state.
        .overlay {
            if birthPlaying {
                ZStack {
                    Rectangle().fill(.regularMaterial)
                    SeedGrowthView(mode: .birth) {
                        withAnimation(.easeOut(duration: 0.3)) { birthPlaying = false }
                    }
                }
                .transition(.opacity)
            }
        }
        .environment(\.kikaTheme, theme)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onAppear { restoreLastSeed() }
        // HIG: bind Esc to close the popover. SwiftUI routes Esc through
        // .onExitCommand on the popover's root view.
        .onExitCommand { NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil) }
    }

    // MARK: - Filled state

    private func filledState(theme: KikaTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: KikaSpacing.md) {
                    projectBlock(theme: theme)
                    sourceBlock(theme: theme)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(KikaFont.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                    if let result = lastResult {
                        resultBlock(result: result, theme: theme)
                    }
                }
                .padding(KikaSpacing.md)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 6)
                .onAppear {
                    guard !contentAppeared else { return }
                    if reduceMotion {
                        contentAppeared = true
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) { contentAppeared = true }
                    }
                }
            }
            // Tall enough that the default flow (project + source + result) shows
            // in one window without scrolling; only an unusually large template
            // set would ever scroll.
            .frame(maxHeight: 480)

            KikaDivider()

            HStack(spacing: KikaSpacing.md) {
                Button {
                    seed()
                } label: {
                    if isWorking {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Text("Seed")
                    }
                }
                .buttonStyle(KikaPrimaryButtonStyle())
                .disabled(!canSeed)
                .opacity(canSeed ? 1.0 : 0.5)
                .keyboardShortcut(.return, modifiers: [.command])
                Spacer()
                Button {
                    pickProjectFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .medium))
                        .imageScale(.medium)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(KikaSecondaryButtonStyle())
                .help("Pick a different folder (⌘O)")
                .keyboardShortcut("o", modifiers: [.command])
                .accessibilityLabel("Pick a different folder")
                .accessibilityInputLabels(["Pick folder", "Change folder", "Choose folder"])

                Button {
                    resetForm()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                        .imageScale(.medium)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(KikaSecondaryButtonStyle())
                .help("Start over")
                .accessibilityLabel("Start over")
                .accessibilityInputLabels(["Reset", "Clear", "Start over"])
            }
            .padding(KikaSpacing.md)
        }
    }

    // MARK: - Project block

    private func projectBlock(theme: KikaTheme) -> some View {
        VStack(alignment: .leading, spacing: KikaSpacing.sm) {
            KikaSectionHeader(title: "Project")
            KikaRow(icon: "folder", label: "Folder") {
                Button("Change") { pickProjectFolder() }
                    .buttonStyle(KikaSecondaryButtonStyle())
            }
            if let url = folderURL {
                Text(url.path)
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 30)
                    .onTapGesture(count: 2) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
            }

            HStack(spacing: KikaSpacing.md) {
                Image(systemName: "textformat")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 18)
                TextField("Project name", text: $projectName)
                    .textFieldStyle(.plain)
                    .font(KikaFont.body)
                    .foregroundStyle(theme.textPrimary)
                    .focused($focusedField, equals: .name)
            }
            .frame(minHeight: 28)
            .focusUnderline(focusedField == .name)

            HStack(spacing: KikaSpacing.md) {
                Image(systemName: "tag")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 18)
                TextField("Tagline", text: $tagline)
                    .textFieldStyle(.plain)
                    .font(KikaFont.body)
                    .foregroundStyle(theme.textPrimary)
                    .focused($focusedField, equals: .tagline)
            }
            .frame(minHeight: 28)
            .focusUnderline(focusedField == .tagline)
        }
    }

    // MARK: - Source block (what'll be seeded)

    private func sourceBlock(theme: KikaTheme) -> some View {
        let count = filesToSeed.count
        let sourceName: String
        if let url = settings.templatesFolderURL {
            sourceName = url.lastPathComponent
        } else {
            sourceName = "Built-in"
        }
        return VStack(alignment: .leading, spacing: KikaSpacing.sm) {
            KikaSectionHeader(title: "Source")
            HStack(spacing: KikaSpacing.md) {
                Image(systemName: "tray.full")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 18)
                Text("\(count) file\(count == 1 ? "" : "s") from \(sourceName)")
                    .font(KikaFont.body)
                    .foregroundStyle(theme.textPrimary)
            }
            .frame(minHeight: 28)
        }
    }

    // MARK: - Result block (post-Seed)

    private func resultBlock(result: SeedResult, theme: KikaTheme) -> some View {
        VStack(alignment: .leading, spacing: KikaSpacing.sm) {
            KikaSectionHeader(title: "Result")
            if !result.created.isEmpty {
                // The growth beat — replays each seed via the seedTick id.
                // Compact so the result fits without scrolling.
                SeedGrowthView(mode: .growth, size: 64)
                    .id(seedTick)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            HStack(spacing: KikaSpacing.md) {
                Image(systemName: result.isAllCreated ? "checkmark.circle.fill" : "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(result.isAllCreated ? theme.accent : theme.textTertiary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.headline)
                        .font(KikaFont.body)
                        .foregroundStyle(theme.textPrimary)
                    if !result.subline.isEmpty {
                        Text(result.subline)
                            .font(KikaFont.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .frame(minHeight: 28, alignment: .top)

            if !result.createdNames.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(result.createdNames, id: \.self) { name in
                        Button {
                            revealFile(name)
                        } label: {
                            HStack(spacing: KikaSpacing.md) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textTertiary)
                                    .frame(width: 18)
                                Text(name)
                                    .font(KikaFont.body)
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Reveal \(name) in Finder")
                    }
                }
                .padding(.top, KikaSpacing.sm)
            }

            if result.createdNames.isEmpty && result.skipped.isEmpty {
                Text("No files selected.")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Actions

    /// Present a folder chooser. We activate the app first: as an accessory
    /// (menu-bar) app, Seedling isn't frontmost when the popover is clicked, so
    /// without this the open panel can open *behind* other windows and the user
    /// sees nothing happen ("stuck"). `.modalPanel` level keeps it above the popover.
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

    private func pickProjectFolder() {
        if let url = chooseDirectory() {
            applyFolder(url)
        }
    }

    private func pickFirstPath() {
        if let url = chooseDirectory() {
            settings.setMainPath(url)
            applyFolder(url)   // sets folderURL + project name, plays the .birth beat
        }
    }

    private func applyFolder(_ url: URL) {
        // Only celebrate the first folder choice (empty hero → filled), not
        // later "Change folder" swaps.
        let wasEmpty = folderURL == nil
        folderURL = url
        errorMessage = nil
        lastResult = nil
        if projectName.isEmpty {
            projectName = url.lastPathComponent
        }
        if wasEmpty {
            withAnimation(.easeIn(duration: 0.2)) { birthPlaying = true }
        }
    }

    private func resetForm() {
        folderURL = settings.mainPathURL
        projectName = settings.mainPathURL?.lastPathComponent ?? ""
        tagline = ""
        lastResult = nil
        errorMessage = nil
    }

    private func seed() {
        guard let folder = folderURL else { return }
        isWorking = true
        errorMessage = nil
        let options = ProjectOptions(
            folderURL: folder,
            projectName: projectName.isEmpty ? folder.lastPathComponent : projectName,
            tagline: tagline
        )
        let files = filesToSeed
        let nameToRemember = projectName
        let taglineToRemember = tagline
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try Seedling.seed(files, into: folder, options: options)
                DispatchQueue.main.async {
                    self.lastResult = result
                    self.isWorking = false
                    self.seedTick += 1
                    self.settings.recordSeed(
                        folder: folder,
                        projectName: nameToRemember.isEmpty ? folder.lastPathComponent : nameToRemember,
                        tagline: taglineToRemember
                    )
                    // VoiceOver live region — announce the result.
                    AccessibilityNotification.Announcement(result.headline).post()
                    NotificationCenter.default.post(name: .seedlingDidSeed, object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isWorking = false
                    AccessibilityNotification.Announcement("Seed failed: \(error.localizedDescription)").post()
                }
            }
        }
    }

    private func revealFile(_ name: String) {
        guard let folder = lastResult?.folderURL else { return }
        let url = folder.appendingPathComponent(name)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Restore last seed (one-shot, on popover appear)

    private func restoreLastSeed() {
        guard !didRestore else { return }
        didRestore = true
        if let url = settings.mainPathURL {
            folderURL = url
            if projectName.isEmpty { projectName = url.lastPathComponent }
        } else if let url = settings.lastFolderURL {
            folderURL = url
        }
        if !settings.lastProjectName.isEmpty {
            projectName = settings.lastProjectName
        }
        if !settings.lastTagline.isEmpty {
            tagline = settings.lastTagline
        }
    }
}

#Preview {
    MenuBarContent()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
        .frame(width: 360, height: 500)
}
