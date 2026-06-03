import SwiftUI
import AppKit

// MARK: - SeedCeremonyView
//
// The zen ceremony window body. A seed in the dark, one name field, and the
// growth. States: onboarding (Projects home unset) → rest → growing → alive.
// Naming a project births `projectsHome/<name>` and seeds it. The view asks the
// host window to dismiss via `onFinish` once the moment has played.
//
struct SeedCeremonyView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.kikaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when the ceremony is over (success or Esc) so the panel fades out.
    let onFinish: () -> Void

    enum Phase { case onboarding, rest, growing, alive, failed }
    @State private var phase: Phase = .rest
    @State private var name: String = ""
    @State private var pendingResult: SeedResult?
    @State private var grownFolder: URL?
    @State private var growthDone = false
    @State private var failureMessage: String = ""
    @State private var nudge = false
    @FocusState private var nameFocused: Bool

    private let size: CGFloat = 300

    private var destinationLine: String {
        guard let home = settings.projectsHomeURL else { return "" }
        let safe = ProjectSeeder.sanitize(name)
        let base = home.lastPathComponent
        return safe.isEmpty ? "planting in  \(base)" : "planting in  \(base)/\(safe)"
    }

    var body: some View {
        content
            .frame(width: size)
            .padding(.vertical, KikaSpacing.lg)
            .padding(.horizontal, KikaSpacing.lg)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .onAppear { configureInitialPhase() }
            .onExitCommand { onFinish() }   // Esc closes the resting window
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .onboarding: onboarding
        case .rest:       rest
        case .growing:    growing
        case .alive:      alive
        case .failed:     failed
        }
    }

    // MARK: Onboarding (Projects home unset)

    private var onboarding: some View {
        VStack(spacing: KikaSpacing.md) {
            seedGlyph
            Text("Where do your projects grow?")
                .font(KikaFont.title)
                .foregroundStyle(theme.textPrimary)
            Button("Choose a folder…") { chooseProjectsHome() }
                .buttonStyle(KikaPrimaryButtonStyle())
        }
    }

    // MARK: Rest

    private var rest: some View {
        VStack(spacing: KikaSpacing.md) {
            seedGlyph
                .offset(y: nudge ? -2 : 0)
            HStack(spacing: KikaSpacing.md) {
                TextField("name your project", text: $name)
                    .textFieldStyle(.plain)
                    .font(KikaFont.body)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .focused($nameFocused)
                    .onSubmit { attemptGrow() }
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

    // MARK: Growing

    private var growing: some View {
        VStack(spacing: KikaSpacing.sm) {
            SeedGrowthView(mode: .growth, size: 120) {
                growthDone = true
                finalizeIfReady()
            }
            Text("growing…")
                .font(KikaFont.caption)
                .foregroundStyle(theme.accent)
                .textCase(.uppercase)
        }
    }

    // MARK: Alive

    private var alive: some View {
        VStack(spacing: KikaSpacing.sm) {
            SeedGrowthView(mode: .growth, size: 120)
                .allowsHitTesting(false)
            Text("\(ProjectSeeder.sanitize(name)) is alive")
                .font(KikaFont.title)
                .foregroundStyle(theme.textPrimary)
            if let r = pendingResult {
                Text(aliveSubline(r))
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private func aliveSubline(_ r: SeedResult) -> String {
        let n = r.plantedCount
        let seeds = "\(n) seed\(n == 1 ? "" : "s") planted"
        if r.skipped.isEmpty { return "\(seeds) · revealing…" }
        return "\(seeds) · \(r.skipped.count) already there · revealing…"
    }

    // MARK: Failed

    private var failed: some View {
        VStack(spacing: KikaSpacing.sm) {
            seedGlyph
            Text(failureMessage.isEmpty ? "Couldn't plant that one." : failureMessage)
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Button("Try again") { phase = .rest }
                .buttonStyle(KikaSecondaryButtonStyle())
        }
    }

    // MARK: Seed glyph (resting seed)

    private var seedGlyph: some View {
        Circle()
            .fill(theme.accent)
            .frame(width: 12, height: 12)
            .frame(height: 80)
            .accessibilityHidden(true)
    }

    // MARK: Actions

    private func configureInitialPhase() {
        phase = settings.projectsHomeURL == nil ? .onboarding : .rest
    }

    private func chooseProjectsHome() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.level = .modalPanel
        if panel.runModal() == .OK, let url = panel.url {
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
        guard let home = settings.projectsHomeURL else { phase = .onboarding; return }
        phase = .growing
        growthDone = false
        pendingResult = nil

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

    /// Move to the alive beat only once both the I/O and the growth animation
    /// have finished, then reveal + dismiss.
    private func finalizeIfReady() {
        guard growthDone, let result = pendingResult, let folder = grownFolder, phase == .growing else { return }
        phase = .alive
        AccessibilityNotification.Announcement("\(ProjectSeeder.sanitize(name)) is alive. \(result.headline).").post()
        NSWorkspace.shared.open(folder)   // default file manager, not hard-coded Finder
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { onFinish() }
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
