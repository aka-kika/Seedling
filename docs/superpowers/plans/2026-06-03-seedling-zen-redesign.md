# Seedling Zen Ceremony Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Seedling's menu-bar popover with an intimate, center-screen "ceremony" window where naming a project births a folder and grows a line-art seed into it.

**Architecture:** A centered, borderless, key-accepting `NSPanel` (`CeremonyWindowController`) hosts a SwiftUI `SeedCeremonyView` with a rest → growing → alive state machine. Naming a project creates `ProjectsHome/<name>` (new `ProjectSeeder` helper) and seeds the resolved `.md` files into it (existing never-overwrite engine). The menu-bar leaf and `⌥⌘S` summon the window; the Finder Service side door stays.

**Tech Stack:** Swift, SwiftUI, AppKit (`NSPanel`, `NSStatusItem`), Carbon hotkey, macOS 26 Liquid Glass, security-scoped bookmarks. Engine logic is verified by the inlined `scripts/smoke_test.swift`; UI is verified by clean build + manual QA.

**Design spec:** `docs/superpowers/specs/2026-06-03-seedling-zen-redesign-design.md`

---

## Conventions used in every task

**Clean build check** (the project's definition of "green", from HANDOFF §8):

```bash
xcodebuild -project Seedling.xcodeproj -scheme Seedling -configuration Debug \
  -derivedDataPath ./build build 2>&1 | tee /tmp/seedling_build.log | tail -3
grep -E "warning:|error:" /tmp/seedling_build.log | grep -v "deprecated" | grep -v "AppIntents" \
  || echo "CLEAN"
```
Expected: `** BUILD SUCCEEDED **` and `CLEAN`.

**Smoke test:**
```bash
swift scripts/smoke_test.swift
```
Expected to end with `All smoke tests passed ✅`.

### Sub-procedure A — add a new Swift file to `Seedling.xcodeproj/project.pbxproj`

The project file is hand-maintained (HANDOFF §15). Every new `.swift` file needs **four** lines, each modeled exactly on the existing `Microinteractions.swift` entries (suffix `A010`). Suffixes `A001`–`A010` are in use; new files take `A011`, `A012`, …

For a file with suffix `SUF`, filename `NAME.swift`, in group `GROUP`:

1. **PBXBuildFile** — in the `/* Begin PBXBuildFile section */` block, add a line like the `A010` one:
   ```
   		A1000001000000000000SUF /* NAME.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1000002000000000000SUF /* NAME.swift */; };
   ```
2. **PBXFileReference** — in the `/* Begin PBXFileReference section */` block:
   ```
   		A1000002000000000000SUF /* NAME.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NAME.swift; sourceTree = "<group>"; };
   ```
3. **Group child** — inside the `GROUP` `PBXGroup`'s `children = ( … )`:
   ```
   				A1000002000000000000SUF /* NAME.swift */,
   ```
   Group IDs: App = `A1000005000000000000A004`, Theme = `A005`, Models = `A006`, Engine = `A007`, Views = `A008`.
4. **PBXSourcesBuildPhase** — inside the `Sources` build phase `files = ( … )`:
   ```
   				A1000001000000000000SUF /* NAME.swift in Sources */,
   ```

Verify after editing:
```bash
grep -c "A1000002000000000000SUF" Seedling.xcodeproj/project.pbxproj   # expect 3
grep -c "A1000001000000000000SUF" Seedling.xcodeproj/project.pbxproj   # expect 2
```

### Sub-procedure B — remove a Swift file from `project.pbxproj`

For suffix `SUF`, delete every line containing `A1000001000000000000SUF` or `A1000002000000000000SUF`:
```bash
grep -vE "A100000[12]000000000000SUF" Seedling.xcodeproj/project.pbxproj > /tmp/pbx && mv /tmp/pbx Seedling.xcodeproj/project.pbxproj
grep -c "SUF" Seedling.xcodeproj/project.pbxproj   # expect 0 matches for that suffix
```

---

## File structure

**New files**
- `Seedling/Engine/ProjectSeeder.swift` (A011) — name sanitization + create `home/<name>` + seed into it.
- `Seedling/Views/SeedCeremonyView.swift` (A013) — the zen window body (onboarding / rest / growing / alive / failed).
- `Seedling/App/CeremonyWindowController.swift` (A014) — centered, key-accepting `NSPanel` hosting the view; fade in/out; outside-click + Esc dismissal.
- `Seedling/Models/BookmarkedFolder.swift` (A012) — reusable security-scoped bookmark helper (final refactor task).

**Modified files**
- `Seedling/Engine/Seedling.swift` — add `SeedError.emptyProjectName`; move the `SeedResult` formatting extension here from `MenuBarContent.swift`.
- `Seedling/Models/SeedFile.swift` — add `projectsHomeURL` + `setProjectsHome`; later drop tagline/main-path state.
- `Seedling/Views/SeedGrowthView.swift` — add the completion "bloom" (one breath of light).
- `Seedling/App/AppDelegate.swift` — summon the ceremony window instead of the popover; reveal via default file manager.
- `Seedling/Views/SettingsView.swift` — "Projects home" section; version 3.0.
- `Seedling/App/SeedlingApp.swift` — header comment update.
- `scripts/smoke_test.swift` — add `ProjectSeeder` coverage.
- `Seedling/Resources/Info.plist` — `CFBundleShortVersionString = 3.0`.
- `HANDOFF.md` — update §3 to the ceremony window.

**Deleted files (final task)**
- `Seedling/Views/MenuBarContent.swift` (A002), `Seedling/Views/WelcomeView.swift` (A00F).

---

## Task 1: `ProjectSeeder` — sanitize a name, birth a folder, seed it

**Files:**
- Create: `Seedling/Engine/ProjectSeeder.swift`
- Modify: `Seedling/Engine/Seedling.swift` (add error case)
- Modify: `scripts/smoke_test.swift` (inline mirror + assertions)
- Modify: `Seedling.xcodeproj/project.pbxproj` (Sub-procedure A, suffix `A011`, group Engine)

- [ ] **Step 1: Add the failing tests to the smoke test**

In `scripts/smoke_test.swift`, after the inlined `enum Seedling { … }` block (before `// MARK: - Tests`), add an inlined mirror of `ProjectSeeder`:

```swift
enum ProjectSeeder {
    static func sanitize(_ raw: String) -> String {
        var s = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        s = s.components(separatedBy: .controlCharacters).joined()
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix(".") { s.removeFirst() }
        s = s.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        return s
    }

    static func seed(projectName raw: String, into home: URL, files: [SeedFile]) throws -> (result: SeedResult, folder: URL) {
        let name = sanitize(raw)
        guard !name.isEmpty else { throw SeedError.emptyProjectName }
        let folder = home.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let options = ProjectOptions(folderURL: folder, projectName: name, tagline: "")
        let result = try Seedling.seed(files, into: folder, options: options)
        return (result, folder)
    }
}
```

Add `case emptyProjectName` to the inlined `enum SeedError` and its `errorDescription` (`return "Type a project name first."`).

Then append assertions at the end of the file, before the final `print("\nAll smoke tests passed ✅")`:

```swift
// 7. Name sanitization
precondition(ProjectSeeder.sanitize("aurora") == "aurora", "plain name unchanged")
precondition(ProjectSeeder.sanitize("  spaced out  ") == "spaced out", "trims + collapses whitespace")
precondition(ProjectSeeder.sanitize("a/b:c") == "a-b-c", "path separators become hyphens")
precondition(ProjectSeeder.sanitize("...dotfile") == "dotfile", "strips leading dots")
precondition(ProjectSeeder.sanitize("   ") == "", "whitespace-only becomes empty")
print("✓ Project name sanitization")

// 8. Birth a subfolder and seed it
let home = tmp.appendingPathComponent("home-\(UUID().uuidString)")
try fm.createDirectory(at: home, withIntermediateDirectories: true)
let born = try ProjectSeeder.seed(projectName: "aurora", into: home, files: defaults)
precondition(born.folder.lastPathComponent == "aurora", "subfolder named after the project")
precondition(born.result.created.count == 5, "all 5 seeds planted into the new folder")
let reborn = try ProjectSeeder.seed(projectName: "aurora", into: home, files: defaults)
precondition(reborn.result.created.isEmpty && reborn.result.skipped.count == 5, "re-seed never overwrites")
print("✓ ProjectSeeder births a folder and seeds it (never overwrites)")

// 9. Empty name is rejected
do {
    _ = try ProjectSeeder.seed(projectName: "   ", into: home, files: defaults)
    precondition(false, "should have thrown")
} catch SeedError.emptyProjectName {
    print("✓ Empty project name throws SeedError.emptyProjectName")
}
```

- [ ] **Step 2: Run the smoke test to verify it fails**

Run: `swift scripts/smoke_test.swift`
Expected: FAIL — compile error `type 'SeedError' has no member 'emptyProjectName'` (the inlined `SeedError` gained the case but verify the run gets to the new assertions). If it compiles, it should still run green only after Step 1 is fully applied; if you applied Step 1 partially it fails here.

- [ ] **Step 3: Add `emptyProjectName` to the real engine**

In `Seedling/Engine/Seedling.swift`, add to `enum SeedError`:

```swift
    case emptyProjectName
```

and in `errorDescription`'s switch:

```swift
        case .emptyProjectName:
            return "Type a project name first."
```

- [ ] **Step 4: Create the real `ProjectSeeder`**

Create `Seedling/Engine/ProjectSeeder.swift`:

```swift
import Foundation

// MARK: - ProjectSeeder
//
// Turns a typed project name into a new project folder under the user's
// "Projects home", then seeds the resolved `.md` files into it. The name
// births the folder *and* fills {{PROJECT_NAME}}. Never overwrites (the
// engine's safety property carries through).
//
// Security-scoped access to `home` is the caller's responsibility — this
// helper assumes `home` is already accessible.
enum ProjectSeeder {

    /// Turn raw user input into a filesystem-safe folder name. Replaces path
    /// separators with hyphens, drops control characters and leading dots, and
    /// trims/collapses whitespace. Spaces are preserved (folder names allow them).
    static func sanitize(_ raw: String) -> String {
        var s = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        s = s.components(separatedBy: .controlCharacters).joined()
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix(".") { s.removeFirst() }
        s = s.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        return s
    }

    /// Create `home/<sanitized name>` (if needed) and seed `files` into it.
    /// Returns the seed result and the new folder URL.
    static func seed(projectName raw: String, into home: URL, files: [SeedFile]) throws -> (result: SeedResult, folder: URL) {
        let name = sanitize(raw)
        guard !name.isEmpty else { throw SeedError.emptyProjectName }
        let folder = home.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let options = ProjectOptions(folderURL: folder, projectName: name, tagline: "")
        let result = try Seedling.seed(files, into: folder, options: options)
        return (result, folder)
    }
}
```

- [ ] **Step 5: Wire the file into the Xcode project**

Apply **Sub-procedure A** with suffix `A011`, filename `ProjectSeeder.swift`, group Engine (`A1000005000000000000A007`).

- [ ] **Step 6: Run the smoke test — expect PASS**

Run: `swift scripts/smoke_test.swift`
Expected: ends with `✓ Empty project name throws SeedError.emptyProjectName` then `All smoke tests passed ✅`.

- [ ] **Step 7: Run the clean build — expect green**

Run the **Clean build check**. Expected: `** BUILD SUCCEEDED **` and `CLEAN`.

- [ ] **Step 8: Commit**

```bash
git add Seedling/Engine/ProjectSeeder.swift Seedling/Engine/Seedling.swift scripts/smoke_test.swift Seedling.xcodeproj/project.pbxproj
git commit -m "feat: ProjectSeeder births a named folder and seeds it"
```

---

## Task 2: `AppSettings.projectsHomeURL`

**Files:**
- Modify: `Seedling/Models/SeedFile.swift`

(No automated test — `AppSettings` uses `UserDefaults` + security scope, out of reach of the smoke script. Verified by clean build; exercised in later manual QA.)

- [ ] **Step 1: Add the key + published property**

In `Seedling/Models/SeedFile.swift`, in `AppSettings`, add the key constant next to the others (after `mainPathBookmarkKey`):

```swift
    private let projectsHomeBookmarkKey = "seedling.projectsHomeBookmark"
```

Add the published property after `mainPathURL`:

```swift
    /// Where new projects are born. Set once (first run / Settings); each seed
    /// creates `projectsHome/<name>`. Persisted as a security-scoped bookmark.
    @Published private(set) var projectsHomeURL: URL?
```

- [ ] **Step 2: Resolve the bookmark on init**

In `init(defaults:)`, after the `mainPathBookmarkKey` resolve block, add the same shape for the new key:

```swift
        if let data = defaults.data(forKey: projectsHomeBookmarkKey) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                self.projectsHomeURL = url
            }
        }
```

- [ ] **Step 3: Add the setter**

After `setMainPath(_:)`, add:

```swift
    /// Set (or change) the Projects home. Stores a security-scoped bookmark.
    func setProjectsHome(_ url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        projectsHomeURL = url
        if let data = try? url.bookmarkData(
            options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil
        ) {
            defaults.set(data, forKey: projectsHomeBookmarkKey)
        }
    }

    /// Begin security-scoped access for the Projects home. Caller must end it.
    func beginProjectsHomeAccess() -> Bool {
        guard let url = projectsHomeURL else { return false }
        return url.startAccessingSecurityScopedResource()
    }

    func endProjectsHomeAccess() {
        projectsHomeURL?.stopAccessingSecurityScopedResource()
    }
```

- [ ] **Step 4: Clean build — expect green**

Run the **Clean build check**. Expected: `BUILD SUCCEEDED` + `CLEAN`.

- [ ] **Step 5: Commit**

```bash
git add Seedling/Models/SeedFile.swift
git commit -m "feat: AppSettings.projectsHomeURL bookmark for the Projects home"
```

---

## Task 3: Move `SeedResult` formatting into the engine

This makes the result copy available without `MenuBarContent.swift` (deleted in Task 9) and gives the ceremony view a clean dependency.

**Files:**
- Modify: `Seedling/Engine/Seedling.swift` (add extension)
- Modify: `Seedling/Views/MenuBarContent.swift` (remove the extension)

- [ ] **Step 1: Add the extension to the engine**

At the end of `Seedling/Engine/Seedling.swift`, append:

```swift
// MARK: - SeedResult formatting

extension SeedResult {
    /// Short headline, e.g. "Seeded 5 files" / "Nothing to do".
    var headline: String {
        let c = created.count
        if c == 0 && skipped.isEmpty { return "No files written" }
        if c == 0 { return "Nothing to do" }
        return c == 1 ? "Seeded 1 file" : "Seeded \(c) files"
    }

    var subline: String {
        if !skipped.isEmpty {
            return "\(skipped.count) skipped (already exist) · \(folderURL.lastPathComponent)"
        }
        return folderURL.lastPathComponent
    }

    var isAllCreated: Bool {
        !created.isEmpty && skipped.isEmpty
    }

    /// Count of seeds actually planted (created this run).
    var plantedCount: Int { created.count }
}
```

- [ ] **Step 2: Remove the duplicate from `MenuBarContent.swift`**

In `Seedling/Views/MenuBarContent.swift`, delete the entire `// MARK: - SeedResult formatting` extension block (the `extension SeedResult { … }` near the end, lines defining `headline` / `subline` / `isAllCreated`). Leave the rest of the file intact for now.

- [ ] **Step 3: Clean build — expect green**

Run the **Clean build check**. (Both `MenuBarContent` and `AppDelegate` still reference `headline` — now resolved from the engine.) Expected: `BUILD SUCCEEDED` + `CLEAN`.

- [ ] **Step 4: Commit**

```bash
git add Seedling/Engine/Seedling.swift Seedling/Views/MenuBarContent.swift
git commit -m "refactor: move SeedResult formatting into the engine"
```

---

## Task 4: `SeedGrowthView` — the completion bloom

Add "one breath of light" when the growth finishes. Keep `.birth`/`.growth` and reduce-motion behavior intact.

**Files:**
- Modify: `Seedling/Views/SeedGrowthView.swift`

**Approach:** a single soft circle near the growth tip. It only renders after `bloomStarted` flips (so it's absent during the draw), and animating the `bloom` boolean swells it (`scale 0.3 → 1.7`) while it dissolves (`opacity 0.7 → 0`) — one outward breath of light.

- [ ] **Step 1: Add the two state vars**

In `struct SeedGrowthView`, after `@State private var progress: CGFloat = 0`, add:

```swift
    @State private var bloom = false
    @State private var bloomStarted = false
```

- [ ] **Step 2: Add the bloom overlay**

In `body`, on the existing `ZStack { … }.frame(width: size, height: size)`, append this `.overlay` immediately after the `.frame(width: size, height: size)` line (and before `.onAppear`):

```swift
        .overlay(alignment: .top) {
            // One breath of light as the growth completes (growth mode only).
            if mode == .growth && bloomStarted {
                Circle()
                    .fill(theme.accent)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .blur(radius: size * 0.04)
                    .scaleEffect(bloom ? 1.7 : 0.3)
                    .opacity(bloom ? 0.0 : 0.7)
                    .padding(.top, size * 0.12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
```

- [ ] **Step 3: Schedule the bloom in `onAppear`**

Replace the existing `.onAppear { … }` block with:

```swift
        .onAppear {
            if reduceMotion {
                progress = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onComplete?() }
                return
            }
            withAnimation(.easeInOut(duration: duration)) { progress = 1 }
            if mode == .growth {
                // Near the end of the draw, reveal the petal and let it swell + dissolve.
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.82) {
                    bloomStarted = true
                    withAnimation(.easeOut(duration: 0.55)) { bloom = true }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { onComplete?() }
        }
```

- [ ] **Step 4: Clean build — expect green**

Run the **Clean build check**. Expected: `BUILD SUCCEEDED` + `CLEAN`.

- [ ] **Step 5: Visual check (manual)**

In Xcode, open `SeedGrowthView.swift` and run the `#Preview`. Confirm the `.growth` preview draws the line art and ends with a soft expanding glow that dissolves; the `.birth` preview is unchanged. Reduce-motion (if you toggle it) shows the final frame with no glow.

- [ ] **Step 6: Commit**

```bash
git add Seedling/Views/SeedGrowthView.swift
git commit -m "feat: growth animation completes with a soft bloom of light"
```

---

## Task 5: `SeedCeremonyView` — the zen window body

**Files:**
- Create: `Seedling/Views/SeedCeremonyView.swift`
- Modify: `Seedling.xcodeproj/project.pbxproj` (Sub-procedure A, suffix `A013`, group Views)

- [ ] **Step 1: Create the view**

Create `Seedling/Views/SeedCeremonyView.swift`:

```swift
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
```

- [ ] **Step 2: Wire the file into the Xcode project**

Apply **Sub-procedure A** with suffix `A013`, filename `SeedCeremonyView.swift`, group Views (`A1000005000000000000A008`).

- [ ] **Step 3: Clean build — expect green**

Run the **Clean build check**. Expected: `BUILD SUCCEEDED` + `CLEAN`.

- [ ] **Step 4: Visual check (manual)**

Run the `SeedCeremonyView` `#Preview`. Confirm: a small seed dot, a centered "name your project" field with the focus underline, the destination line, and the "⏎ to grow" hint. (Onboarding/growing/alive are exercised live in Task 6.)

- [ ] **Step 5: Commit**

```bash
git add Seedling/Views/SeedCeremonyView.swift Seedling.xcodeproj/project.pbxproj
git commit -m "feat: SeedCeremonyView — zen rest/grow/alive ceremony body"
```

---

## Task 6: `CeremonyWindowController` — centered key-accepting panel

**Files:**
- Create: `Seedling/App/CeremonyWindowController.swift`
- Modify: `Seedling.xcodeproj/project.pbxproj` (Sub-procedure A, suffix `A014`, group App)

- [ ] **Step 1: Create the controller**

Create `Seedling/App/CeremonyWindowController.swift`:

```swift
import SwiftUI
import AppKit

// MARK: - KeyablePanel
//
// A borderless NSPanel that is still allowed to become key, so the SwiftUI
// text field inside can take keyboard focus.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - CeremonyWindowController
//
// Owns the centered, borderless, glass ceremony panel that hosts
// SeedCeremonyView. Fades in centered on the active screen, takes key focus,
// and fades out when the ceremony finishes, on Esc, or on an outside click.
//
@MainActor
final class CeremonyWindowController {
    private let settings: AppSettings
    private var panel: KeyablePanel?
    private var outsideClickMonitor: Any?

    init(settings: AppSettings) {
        self.settings = settings
    }

    var isShown: Bool { panel != nil }

    /// Show the window if hidden; bring it forward + refocus if already shown.
    func summon() {
        NSApp.activate(ignoringOtherApps: true)
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let (theme, scheme) = resolveTheme()
        let root = SeedCeremonyView(onFinish: { [weak self] in self?.dismiss() })
            .environmentObject(settings)
            .environment(\.kikaTheme, theme)
            .preferredColorScheme(scheme)

        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = true

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        self.panel = panel

        centerOnActiveScreen(panel)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }
        installOutsideClickMonitor()
    }

    func toggle() {
        if isShown { dismiss() } else { summon() }
    }

    func dismiss() {
        guard let panel else { return }
        removeOutsideClickMonitor()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                self?.panel = nil
            }
        })
    }

    // MARK: Helpers

    private func centerOnActiveScreen(_ panel: NSPanel) {
        guard let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                     y: frame.midY - size.height / 2))
    }

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // Any click outside our app (the panel is the only window) dismisses.
            self?.dismiss()
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor {
            NSEvent.removeMonitor(m)
            outsideClickMonitor = nil
        }
    }

    /// Resolve the KIKA theme + SwiftUI color scheme honoring the user's
    /// appearance preference (mirrors AppDelegate's HUD theme resolution).
    private func resolveTheme() -> (KikaTheme, ColorScheme?) {
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
}
```

- [ ] **Step 2: Wire the file into the Xcode project**

Apply **Sub-procedure A** with suffix `A014`, filename `CeremonyWindowController.swift`, group App (`A1000005000000000000A004`).

- [ ] **Step 3: Clean build — expect green**

Run the **Clean build check**. Expected: `BUILD SUCCEEDED` + `CLEAN`. (Nothing references the controller yet — that's Task 7.)

- [ ] **Step 4: Commit**

```bash
git add Seedling/App/CeremonyWindowController.swift Seedling.xcodeproj/project.pbxproj
git commit -m "feat: CeremonyWindowController — centered key-accepting glass panel"
```

---

## Task 7: Wire `AppDelegate` to summon the ceremony window

Swap the popover for the ceremony window; reveal via the default file manager.

**Files:**
- Modify: `Seedling/App/AppDelegate.swift`

- [ ] **Step 1: Replace the popover property with the controller**

In `AppDelegate`, remove `NSPopoverDelegate` from the class declaration and replace the popover stored property. Change:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    /// Strong reference to the settings object (also injected into SwiftUI scenes).
    let settings = AppSettings()

    private var eventMonitor: Any?
```

to:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    /// Strong reference to the settings object (also injected into SwiftUI scenes).
    let settings = AppSettings()

    /// The centered ceremony window (replaces the old menu-bar popover).
    private lazy var ceremony = CeremonyWindowController(settings: settings)
```

- [ ] **Step 2: Trim `applicationDidFinishLaunching`**

Remove the now-dead popover/seed-notification wiring. In `applicationDidFinishLaunching`, delete these calls/observers:
- `configurePopover()`
- `installOutsideClickMonitor()`
- the `NotificationCenter.default.addObserver(... selector: #selector(handleSeedDidComplete), name: .seedlingDidSeed ...)` block

Keep `configureStatusItem()`, `updateStatusItemIcon()`, the Services provider lines, the `willCloseNotification` observer, and both Combine subscriptions.

- [ ] **Step 3: Delete dead popover methods**

Delete these members entirely: `handleSeedDidComplete()`, `configurePopover()`, `installOutsideClickMonitor()`, `togglePopover()`, and the `deinit` that removes `eventMonitor` (the controller owns its own monitor now).

- [ ] **Step 4: Point button + hotkey at the ceremony window**

Replace `handleButtonPress` body's `else` branch and `summonPopover()`:

```swift
    @objc private func handleButtonPress(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            ceremony.toggle()
        }
    }
```

In `refreshHotKey()`, change the registration to summon the window:

```swift
    private func refreshHotKey() {
        if settings.globalHotKeyEnabled {
            hotKey.register { [weak self] in self?.ceremony.summon() }
        } else {
            hotKey.unregister()
        }
    }
```

Delete the old `summonPopover()` method.

- [ ] **Step 5: Reveal via the default file manager (Finder Service path)**

In `performHeadlessSeed(into:)`, replace:

```swift
                if !result.created.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(result.created)
                }
```

with:

```swift
                NSWorkspace.shared.open(folder)   // default file manager, not hard-coded Finder
```

- [ ] **Step 6: Clean build — expect green**

Run the **Clean build check**. Expected: `BUILD SUCCEEDED` + `CLEAN`.

- [ ] **Step 7: Manual smoke of the live app**

```bash
defaults delete com.seedling.app 2>/dev/null; killall Seedling 2>/dev/null
open build/Build/Products/Debug/Seedling.app
```
Verify, in order:
1. Click the menu-bar leaf → a centered window fades in.
2. First run shows onboarding ("Where do your projects grow?"). Choose a folder (e.g. a throwaway `~/Desktop/seedtest`).
3. The resting seed appears; the name field is focused — type `aurora` without clicking.
4. Press Return → the line grows, blooms, "aurora is alive · N seeds planted · revealing…", the `aurora` folder opens in your file manager, the window fades out.
5. Re-summon with `⌥⌘S` → resting seed; type the same name → it plants without overwriting (subline notes "already there").
6. Press `⌥⌘S`, then click elsewhere → the resting window dismisses (outside-click). `Esc` also dismisses.
7. Right-click the leaf → About / Settings… / Quit still work.

- [ ] **Step 8: Commit**

```bash
git add Seedling/App/AppDelegate.swift
git commit -m "feat: summon the ceremony window from the leaf and hotkey; reveal via default file manager"
```

---

## Task 8: Update Settings — "Projects home" + version 3.0

**Files:**
- Modify: `Seedling/Views/SettingsView.swift`
- Modify: `Seedling/Resources/Info.plist`

- [ ] **Step 1: Repoint the path section at Projects home**

In `SettingsView`, replace the `mainPath` computed property:

```swift
    private var projectsHome: String {
        settings.projectsHomeURL?.path ?? "Not set"
    }
```

Replace the "Main path" `Section { … }` with:

```swift
            Section {
                KikaRow(icon: "folder", label: "Location") {
                    Text(projectsHome)
                        .font(KikaFont.caption)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Button("Change…") {
                    pickProjectsHome()
                }
                .buttonStyle(KikaSecondaryButtonStyle())
                .accessibilityLabel("Change Projects home")
                Text("New projects are created as subfolders here. Naming a project in the window creates a folder with that name and plants the seeds inside it.")
                    .font(KikaFont.caption)
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Projects home")
                    .accessibilityAddTraits(.isHeader)
            }
```

Replace the `pickMainPath()` method with:

```swift
    private func pickProjectsHome() {
        if let url = chooseDirectory() {
            settings.setProjectsHome(url)
        }
    }
```

- [ ] **Step 2: Update the templates-hero copy and version string**

In `templatesHero`, change "Templates folder" wording to "Seed library" where user-facing. Specifically, change the section header text from `"Templates folder"` to `"Seed library"`, and the hero description string to:

```swift
            Text("Markdown files in this folder are the seeds planted into each new project. The built-in library is used when no folder is set.")
```

In `aboutBlock`, change the version line and description:

```swift
                Text("Version 3.0 (build 1)")
```
```swift
            Text("A calm app for seeding new projects with the right markdown files. Built on the KIKA Design System v2.")
```
and fix the stale accessibility label on the about element:
```swift
        .accessibilityLabel("About Seedling. Version 3.0. A calm app for seeding new projects with the right markdown files.")
```

- [ ] **Step 3: Bump the bundle version**

In `Seedling/Resources/Info.plist`, set `CFBundleShortVersionString` to `3.0` (find the existing `<key>CFBundleShortVersionString</key>` and update the following `<string>`).

- [ ] **Step 4: Clean build — expect green**

Run the **Clean build check**. Expected: `BUILD SUCCEEDED` + `CLEAN`.

- [ ] **Step 5: Manual check**

Re-open the app, right-click leaf → Settings…. Confirm a "Projects home" section showing the folder you chose in Task 7, a "Seed library" hero, Appearance, Shortcut, and About reading "Version 3.0".

- [ ] **Step 6: Commit**

```bash
git add Seedling/Views/SettingsView.swift Seedling/Resources/Info.plist
git commit -m "feat: Settings shows Projects home + seed library; version 3.0"
```

---

## Task 9: Remove the popover surface (`MenuBarContent`, `WelcomeView`) + tagline state

**Files:**
- Delete: `Seedling/Views/MenuBarContent.swift`, `Seedling/Views/WelcomeView.swift`
- Modify: `Seedling/Models/SeedFile.swift` (drop tagline + main-path state)
- Modify: `Seedling/App/SeedlingApp.swift` (header comment)
- Modify: `Seedling.xcodeproj/project.pbxproj` (Sub-procedure B, suffixes `A002`, `A00F`)

- [ ] **Step 1: Confirm there are no remaining references**

```bash
grep -rn "MenuBarContent\|WelcomeView\|seedlingDidSeed" Seedling/ | grep -v "MenuBarContent.swift:" | grep -v "WelcomeView.swift:"
```
Expected: no output. (If `seedlingDidSeed` still appears, it should only be inside `MenuBarContent.swift`, which we're deleting. Any other hit must be removed first.)

- [ ] **Step 2: Delete the two files from disk**

```bash
git rm Seedling/Views/MenuBarContent.swift Seedling/Views/WelcomeView.swift
```

- [ ] **Step 3: Remove them from the Xcode project**

Apply **Sub-procedure B** for suffix `A002` (MenuBarContent) and suffix `A00F` (WelcomeView).

```bash
grep -vE "A100000[12]000000000000A002" Seedling.xcodeproj/project.pbxproj > /tmp/pbx && mv /tmp/pbx Seedling.xcodeproj/project.pbxproj
grep -vE "A100000[12]000000000000A00F" Seedling.xcodeproj/project.pbxproj > /tmp/pbx && mv /tmp/pbx Seedling.xcodeproj/project.pbxproj
grep -c "A002\|A00F" Seedling.xcodeproj/project.pbxproj   # expect 0
```

- [ ] **Step 4: Drop now-dead settings state**

In `Seedling/Models/SeedFile.swift`, the ceremony flow re-derives nothing per open and has no tagline. Remove the following (they are no longer referenced after Step 1):
- key constants `lastFolderBookmarkKey`, `lastProjectNameKey`, `lastTaglineKey`, `mainPathBookmarkKey`
- properties `lastFolderURL`, `mainPathURL`, `lastProjectName`, `lastTagline`
- their resolve blocks in `init`
- methods `recordSeed(folder:projectName:tagline:)` and `setMainPath(_:)`

> **Before removing `recordSeed`**, confirm `AppDelegate.performHeadlessSeed` no longer calls it. If it does, delete that call (the Finder Service no longer needs to remember a "last folder"). Re-grep:
```bash
grep -rn "recordSeed\|mainPathURL\|lastFolderURL\|lastProjectName\|lastTagline\|setMainPath" Seedling/
```
Expected after edits: no output.

Keep `ProjectOptions.tagline` (the engine still substitutes `{{TAGLINE}}` to empty) — do not remove it.

- [ ] **Step 5: Refresh the app header comment**

In `Seedling/App/SeedlingApp.swift`, update the `Architecture:` comment block to describe the ceremony window instead of the popover:

```swift
//  Architecture:
//  - The `AppDelegate` owns an `NSStatusItem`.
//  - Left-click on the leaf icon / ⌥⌘S → centered ceremony window (CeremonyWindowController).
//  - Right-click on the leaf icon → NSMenu (About / Settings / Quit).
//  - Settings opens the standard SwiftUI `Settings` scene.
```

- [ ] **Step 6: Clean build + smoke test — expect green**

Run the **Clean build check** and the **Smoke test**. Expected: `BUILD SUCCEEDED`, `CLEAN`, and `All smoke tests passed ✅`.

- [ ] **Step 7: Manual regression**

Re-open the app. Confirm the full Task 7 manual flow still works end-to-end (onboarding only re-appears if you `defaults delete com.seedling.app` first).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: remove popover surface and per-seed state; ceremony window is the only flow"
```

---

## Task 10: Extract `BookmarkedFolder` (the 4th-bookmark refactor)

HANDOFF §5 predicted that a fourth security-scoped bookmark is the moment to extract a helper. After Task 9 there are two left (`templatesFolderURL`, `projectsHomeURL`) — still worth unifying their near-identical resolve/persist/access code.

**Files:**
- Create: `Seedling/Models/BookmarkedFolder.swift`
- Modify: `Seedling/Models/SeedFile.swift`
- Modify: `Seedling.xcodeproj/project.pbxproj` (Sub-procedure A, suffix `A012`, group Models)

- [ ] **Step 1: Create the helper**

Create `Seedling/Models/BookmarkedFolder.swift`:

```swift
import Foundation

// MARK: - BookmarkedFolder
//
// One security-scoped folder bookmark persisted in UserDefaults. Collapses the
// previously-duplicated resolve-on-init / persist-on-set / start-stop-access
// blocks into a single reusable value (HANDOFF §5 predicted this extraction).
//
struct BookmarkedFolder {
    let key: String
    private let defaults: UserDefaults

    init(key: String, defaults: UserDefaults) {
        self.key = key
        self.defaults = defaults
    }

    /// Resolve the persisted bookmark to a URL, or nil if absent/unresolvable.
    func resolve() -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data,
                        options: [.withSecurityScope],
                        relativeTo: nil,
                        bookmarkDataIsStale: &stale)
    }

    /// Persist `url` as a security-scoped bookmark (wraps start/stop access).
    func store(_ url: URL) {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        if let data = try? url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            defaults.set(data, forKey: key)
        }
    }

    /// Remove the persisted bookmark.
    func clear() {
        defaults.removeObject(forKey: key)
    }
}
```

- [ ] **Step 2: Wire the file into the Xcode project**

Apply **Sub-procedure A** with suffix `A012`, filename `BookmarkedFolder.swift`, group Models (`A1000005000000000000A006`).

- [ ] **Step 3: Use it in `AppSettings`**

In `Seedling/Models/SeedFile.swift`, add two helpers backed by the keys (place after the key constants):

```swift
    private lazy var templatesBookmark = BookmarkedFolder(key: templatesBookmarkKey, defaults: defaults)
    private lazy var projectsHomeBookmark = BookmarkedFolder(key: projectsHomeBookmarkKey, defaults: defaults)
```

Replace the `init` resolve blocks for templates and projects-home with:

```swift
        self.templatesFolderURL = templatesBookmark.resolve()
        self.projectsHomeURL = projectsHomeBookmark.resolve()
```

> Note: `templatesBookmark`/`projectsHomeBookmark` are `lazy` and reference `defaults`, so move these two assignments to **after** `self.defaults = defaults` and after `appearance`/`globalHotKeyEnabled` are set (Swift requires all stored properties initialized before using `self`). If the compiler complains about using `lazy` members during `init`, inline the resolve instead: `self.templatesFolderURL = BookmarkedFolder(key: templatesBookmarkKey, defaults: defaults).resolve()`.

Replace `persistTemplatesBookmark()` body and `setProjectsHome` persistence to use the helper:

```swift
    private func persistTemplatesBookmark() {
        guard let url = templatesFolderURL else {
            BookmarkedFolder(key: templatesBookmarkKey, defaults: defaults).clear()
            return
        }
        BookmarkedFolder(key: templatesBookmarkKey, defaults: defaults).store(url)
    }
```

```swift
    func setProjectsHome(_ url: URL) {
        projectsHomeURL = url
        BookmarkedFolder(key: projectsHomeBookmarkKey, defaults: defaults).store(url)
    }
```

(`store` already wraps start/stop access, so the manual `startAccessingSecurityScopedResource` dance is removed.)

- [ ] **Step 4: Clean build + smoke test — expect green**

Run the **Clean build check** and **Smoke test**. Expected: `BUILD SUCCEEDED`, `CLEAN`, `All smoke tests passed ✅`.

- [ ] **Step 5: Manual check — persistence survives relaunch**

```bash
killall Seedling 2>/dev/null; open build/Build/Products/Debug/Seedling.app
```
Open Settings — the Projects home + Seed library you set earlier should still be shown (bookmarks resolved through the new helper). Seed a project to confirm write access still works.

- [ ] **Step 6: Commit**

```bash
git add Seedling/Models/BookmarkedFolder.swift Seedling/Models/SeedFile.swift Seedling.xcodeproj/project.pbxproj
git commit -m "refactor: extract BookmarkedFolder for security-scoped folder bookmarks"
```

---

## Task 11: Update HANDOFF.md and finalize

**Files:**
- Modify: `HANDOFF.md`

- [ ] **Step 1: Update the docs to the ceremony window**

In `HANDOFF.md`:
- §1 file table: replace the `MenuBarContent.swift` / `WelcomeView.swift` rows with `SeedCeremonyView.swift` (Views) and `CeremonyWindowController.swift` (App), and add `ProjectSeeder.swift` (Engine), `BookmarkedFolder.swift` (Models). Update the "read first" pointer from `MenuBarContent.swift` to `SeedCeremonyView.swift`.
- §3 "The popover flow": replace with "The ceremony flow" — centered window, onboarding/rest/growing/alive, Projects-home destination model, name-only input, reveal via default file manager, fade out.
- §6: note the leaf left-click / `⌥⌘S` now summon `CeremonyWindowController` (not the popover); the global outside-click monitor lives in the controller.
- Add a line under §1's design-history bullets pointing at `docs/superpowers/specs/2026-06-03-seedling-zen-redesign-design.md` and this plan as the v3.0 source of truth, and note the v2.0 popover docs are archive.

- [ ] **Step 2: Full verification pass**

Run the **Clean build check** and **Smoke test**. Expected: `BUILD SUCCEEDED`, `CLEAN`, `All smoke tests passed ✅`.

- [ ] **Step 3: Commit**

```bash
git add HANDOFF.md
git commit -m "docs: HANDOFF reflects the v3.0 ceremony window"
```

---

## Self-Review

**Spec coverage (each §):**
- §2 three beats (rest/grow/alive) → Tasks 4 (bloom), 5 (view), 6 (window), 7 (wiring). ✅
- §2 decision 1 (centered window) → Task 6. ✅
- §2 decision 2 (zen, calm) → Task 5 layout. ✅
- §2 decision 3 (Projects home) → Tasks 1, 2, 5. ✅
- §2 decision 4 (name only; `{{TAGLINE}}` empty) → Task 1 (`tagline: ""`), Task 5 (single field). ✅
- §2 decision 5 (line-art + bloom) → Task 4. ✅
- §2 decision 6 (reveal default file manager + fade) → Task 5 (`NSWorkspace.open`), Tasks 6/7. ✅
- §2 decision 7 (collision never overwrites, whisper) → Task 1 (engine), Task 5 (`aliveSubline` "already there"). ✅
- §3 removed popover / per-seed picker / tagline → Tasks 7, 9. ✅
- §3 added projectsHomeURL / window / view / seeder / default-manager reveal → Tasks 2,5,6,1,7. ✅
- §4 components → ProjectSeeder (T1), SeedCeremonyView (T5), CeremonyWindowController (T6), AppSettings (T2/T9), BookmarkedFolder (T10), AppDelegate (T7), SettingsView (T8). ✅
- §6 edge cases: empty name (T1 throw + T5 nudge), sanitize (T1), home unset/onboarding (T5), collision (T1/T5), library fallback (`resolveSeedFiles`, unchanged), write failure (T5 `.failed`), already-open (T6 `summon` brings forward), reduce-motion (T4). ✅
- §7 onboarding → Task 5 `onboarding` phase + Task 9 removes old `WelcomeView`. ✅
- §8 visual/motion → Tasks 4, 5. ✅
- §9 testing → Task 1 smoke extensions + per-task clean build + manual QA in T7/T8/T9/T10. ✅
- §10 out-of-scope respected (no tagline, no recorder, no batch). ✅
- §11 migration (pbxproj dance, archive docs) → Sub-procedures A/B, Task 11. ✅

**Placeholder scan:** No "TBD"/"TODO"/"handle errors" left; every code step shows full code. (The `LICENSE.md` built-in still literally contains "TODO: add license name" — that is product content, not a plan placeholder.) ✅

**Type consistency:** `ProjectSeeder.sanitize(_:)`/`seed(projectName:into:files:)`, `SeedError.emptyProjectName`, `SeedResult.plantedCount/headline`, `AppSettings.projectsHomeURL/setProjectsHome/beginProjectsHomeAccess`, `CeremonyWindowController(settings:).summon()/toggle()/dismiss()`, `SeedCeremonyView(onFinish:)`, `BookmarkedFolder(key:defaults:).resolve()/store(_:)/clear()` — names are used identically across tasks. ✅

> One cosmetic knob to expect tuning during execution: the **bloom overlay** in Task 4 positions the glow with `padding(.top, size * 0.12)`. If it looks off against the 120pt growth in `SeedCeremonyView`, adjust that value — it's purely visual and affects no other task.
