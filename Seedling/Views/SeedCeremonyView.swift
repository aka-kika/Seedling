import SwiftUI
import AppKit

// MARK: - SeedCeremonyView
//
// The zen ceremony window body. A seed in the dark, one name field, and the
// growth. Phases: onboarding (first run — choose Root, then Garden) → rest →
// growing → alive. Naming a project births `Garden/<name>` and seeds it.
//
// growing + alive share ONE view subtree so the growth animation plays exactly
// once and then rests on its final frame while the "alive" text/button fade in.
// When it's alive it waits for the user: ⏎ (the button) opens the new folder in
// the default file manager and fades; Esc fades without opening.
//
struct SeedCeremonyView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.kikaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when the ceremony is over (entered the garden, dismissed, or Esc).
    let onFinish: () -> Void

    /// Opens the Settings window. The leaf's right-click menu is unreachable on
    /// macOS 27 (the system swallows right-clicks on status items), so the
    /// ceremony carries its own quiet door to Settings.
    var onSettings: () -> Void = {}

    enum Phase { case onboarding, rest, growing, alive, failed }
    enum OnboardStep { case seeds, garden }

    @State private var phase: Phase = .rest
    @State private var onboardStep: OnboardStep = .seeds
    @State private var name: String = ""
    @State private var pendingResult: SeedResult?
    @State private var grownFolder: URL?
    @State private var growthDone = false
    @State private var failureMessage: String = ""
    @State private var nudge = false
    @State private var seedPump: CGFloat = 1
    @State private var gearHovered = false
    @FocusState private var nameFocused: Bool

    private let size: CGFloat = 300

    private var gardenName: String { settings.projectsHomeURL?.lastPathComponent ?? "garden" }

    private var destinationLine: String {
        guard settings.projectsHomeURL != nil else { return "" }
        let safe = ProjectSeeder.sanitize(name)
        return safe.isEmpty ? "planting in  \(gardenName)" : "planting in  \(gardenName)/\(safe)"
    }

    var body: some View {
        content
            .frame(width: size)
            .padding(.vertical, KikaSpacing.lg)
            .padding(.horizontal, KikaSpacing.lg)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .overlay(alignment: .bottomTrailing) { settingsGear }
            .onAppear { configureInitialPhase() }
            .onExitCommand { onFinish() }   // Esc closes the window (no folder open)
    }

    /// A quiet gear in the corner — the always-reachable path to Settings
    /// (also answers ⌘, while the ceremony is up).
    private var settingsGear: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.textTertiary)
                .opacity(gearHovered ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(",", modifiers: .command)
        .onHover { gearHovered = $0 }
        .padding(KikaSpacing.sm)
        .accessibilityLabel("Settings")
        .help("Settings (⌘,)")
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .onboarding:      onboarding
        case .rest:            rest
        case .growing, .alive: ceremony   // one subtree → growth plays exactly once
        case .failed:          failed
        }
    }

    // MARK: Onboarding — two calm beats

    private var onboarding: some View {
        VStack(spacing: KikaSpacing.md) {
            staticSeed
                .scaleEffect(seedPump)
            Group {
                if onboardStep == .seeds {
                    onboardBeat(title: "where are your seeds?",
                                subtitle: "the folder with your .md files — your Root",
                                choose: chooseSeedsRoot)
                } else {
                    onboardBeat(title: "take me to your garden…",
                                subtitle: "where new projects grow",
                                choose: chooseGarden)
                }
            }
            .id(onboardStep)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 16)),
                removal: .opacity.combined(with: .offset(x: -16))
            ))
        }
        .animation(.easeInOut(duration: 0.35), value: onboardStep)
    }

    private func onboardBeat(title: String, subtitle: String, choose: @escaping () -> Void) -> some View {
        VStack(spacing: KikaSpacing.md) {
            Text(title)
                .font(KikaFont.title)
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Button("Choose…", action: choose)
                .buttonStyle(KikaPrimaryButtonStyle())
        }
    }

    // MARK: Rest

    private var rest: some View {
        VStack(spacing: KikaSpacing.md) {
            staticSeed
                .scaleEffect(seedPump)          // pumps on every keystroke
                .offset(y: nudge ? -2 : 0)
            HStack(spacing: KikaSpacing.md) {
                TextField("name your project", text: $name)
                    .textFieldStyle(.plain)
                    .font(KikaFont.body)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .focused($nameFocused)
                    .onSubmit { attemptGrow() }
                    .onChange(of: name) { _, _ in pumpSeed() }
            }
            .frame(minHeight: 28)
            .focusUnderline(nameFocused)
            .modifier(ShakeEffect(animatableData: nudge ? 1 : 0))

            Text(destinationLine)
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text("⏎ to grow")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { nameFocused = true }
        }
    }

    // MARK: Ceremony (growing + alive share this subtree)

    private var ceremony: some View {
        VStack(spacing: KikaSpacing.md) {
            SeedGrowthView(mode: .growth, size: 120) {
                growthDone = true
                finalizeIfReady()
            }
            .allowsHitTesting(false)

            if phase == .growing {
                Text("growing…")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.accent)
                    .textCase(.uppercase)
            } else {
                VStack(spacing: KikaSpacing.sm) {
                    Text("\(ProjectSeeder.sanitize(name)) is alive")
                        .font(KikaFont.title)
                        .foregroundStyle(theme.textPrimary)
                    if let r = pendingResult {
                        Text(aliveSubline(r))
                            .font(KikaFont.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                    Button("Enter the garden") { openGardenAndFinish() }
                        .buttonStyle(KikaPrimaryButtonStyle())
                        .keyboardShortcut(.return, modifiers: [])
                    Text("⏎ enter · esc later")
                        .font(KikaFont.caption)
                        .foregroundStyle(theme.textTertiary)
                        .textCase(.uppercase)
                }
                .transition(.opacity)
            }
        }
    }

    private func aliveSubline(_ r: SeedResult) -> String {
        let n = r.plantedCount
        let seeds = "\(n) seed\(n == 1 ? "" : "s") planted"
        if r.skipped.isEmpty { return seeds }
        return "\(seeds) · \(r.skipped.count) already there"
    }

    // MARK: Failed

    private var failed: some View {
        VStack(spacing: KikaSpacing.sm) {
            staticSeed
            Text(failureMessage.isEmpty ? "Couldn't plant that one." : failureMessage)
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Button("Try again") { phase = .rest }
                .buttonStyle(KikaSecondaryButtonStyle())
        }
    }

    // MARK: Seed glyph

    private var staticSeed: some View {
        Circle()
            .fill(theme.accent)
            .frame(width: 12, height: 12)
            .frame(height: 80)
            .accessibilityHidden(true)
    }

    // MARK: Actions

    private func configureInitialPhase() {
        if settings.projectsHomeURL == nil {
            phase = .onboarding
            onboardStep = settings.templatesFolderURL == nil ? .seeds : .garden
        } else {
            phase = .rest
        }
    }

    /// A scale bump on the resting seed for each character typed. The first
    /// letter is a modest pump; it grows with the name so the seed gets visibly
    /// more eager as the word forms.
    private func pumpSeed() {
        guard !reduceMotion else { return }
        let count = ProjectSeeder.sanitize(name).count
        let intensity = min(0.55, 0.30 + CGFloat(max(0, count - 1)) * 0.03)
        withAnimation(.easeOut(duration: 0.09)) { seedPump = 1 + intensity }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.45)) { seedPump = 1.0 }
        }
    }

    /// A one-off pulse (used when advancing an onboarding step).
    private func pulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.12)) { seedPump = 1.4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.5)) { seedPump = 1.0 }
        }
    }

    private func choosePanel() -> URL? {
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

    private func chooseSeedsRoot() {
        if let url = choosePanel() {
            settings.setTemplatesFolder(from: url)
            pulse()                 // the seed reacts as the garden beat slides in
            onboardStep = .garden
        }
    }

    private func chooseGarden() {
        if let url = choosePanel() {
            settings.setProjectsHome(url)
            phase = .rest
        }
    }

    private func attemptGrow() {
        let safe = ProjectSeeder.sanitize(name)
        guard !safe.isEmpty else {
            withAnimation(reduceMotion ? nil : .default) { nudge.toggle() }
            return
        }
        guard let home = settings.projectsHomeURL else { phase = .onboarding; onboardStep = .garden; return }
        phase = .growing
        growthDone = false
        pendingResult = nil
        grownFolder = nil

        let files = settings.resolveSeedFiles()
        let typed = name
        DispatchQueue.global(qos: .userInitiated).async {
            let started = home.startAccessingSecurityScopedResource()
            defer { if started { home.stopAccessingSecurityScopedResource() } }
            do {
                let born = try ProjectSeeder.seed(projectName: typed, into: home, files: files)
                DispatchQueue.main.async {
                    self.pendingResult = born.result
                    self.grownFolder = born.folder
                    self.finalizeIfReady()
                }
            } catch {
                DispatchQueue.main.async {
                    self.failureMessage = error.localizedDescription
                    self.phase = .failed
                    AccessibilityNotification.Announcement("Seed failed: \(error.localizedDescription)").post()
                }
            }
        }
    }

    /// Advance to the alive beat only once both the I/O and the growth animation
    /// have finished. No auto-open and no auto-dismiss — the window now waits.
    private func finalizeIfReady() {
        guard growthDone, pendingResult != nil, grownFolder != nil, phase == .growing else { return }
        withAnimation(.easeOut(duration: 0.3)) { phase = .alive }
        AccessibilityNotification.Announcement("\(ProjectSeeder.sanitize(name)) is alive.").post()
    }

    /// ⏎ / button: open the new project in the default file manager, then fade out.
    private func openGardenAndFinish() {
        if let folder = grownFolder {
            NSWorkspace.shared.open(folder)   // default file manager, not hard-coded Finder
        }
        onFinish()
    }
}

// MARK: - Shake (gentle nudge for an empty name)

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = sin(animatableData * .pi * 3) * 4
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

#Preview {
    SeedCeremonyView(onFinish: {})
        .environmentObject(AppSettings())
        .environment(\.kikaTheme, .resolve(scheme: .dark))
        .preferredColorScheme(.dark)
        .padding(40)
        .background(.black)
}
