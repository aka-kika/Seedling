# Seedling Liquid Glass Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve Seedling into a Liquid Glass app (macOS 26) with a pastel sage accent, smaller/higher-end type, a "plant your first seed" first-run flow, a fixed Settings window, and richer line-art microinteractions.

**Architecture:** Incremental in-place changes to the existing ~12-file app. Theme tokens change first (accent, fonts), then button styles and glass surfaces, then the `mainPathURL`-driven welcome flow, the Settings-open fix, and microinteractions last. The seed engine is untouched throughout.

**Tech Stack:** Swift 5, SwiftUI + AppKit, Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`), Carbon hotkey, macOS 26 SDK.

---

## Testing reality

No XCTest target exists. Per-task verification uses:

- **Clean build:** `xcodebuild -project Seedling.xcodeproj -scheme Seedling -configuration Debug -derivedDataPath ./build build 2>&1 | grep -E "warning:|error:" | grep -v deprecated | grep -v AppIntents` → must be empty.
- **Engine regression:** `swift scripts/smoke_test.swift` → "All smoke tests passed ✅" (engine unchanged).
- **Launch:** `killall Seedling 2>/dev/null; open ./build/Build/Products/Debug/Seedling.app`.
- **Service drive:** `swift /tmp/drive_service.swift` (existing harness).
- **State inspection:** `defaults read com.seedling.app`.

**Git note:** this project is **not** a git repository. "Commit" steps below are optional checkpoints; run `git init` first if you want them to apply. Otherwise treat each commit step as a "stop and verify" checkpoint.

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `Seedling.xcodeproj/project.pbxproj` | Build config | Deployment target → 26; register new files |
| `Seedling/Resources/Info.plist` | App metadata | `LSMinimumSystemVersion` → 26.0 |
| `Seedling/Theme/KikaColors.swift` | Tokens | Accent pastel sage; font sizes smaller |
| `Seedling/Theme/KikaComponents.swift` | Reusable views/styles | Glass button styles; sizing |
| `Seedling/Theme/Microinteractions.swift` (new) | Press/focus modifiers | Shared subtle interactions |
| `Seedling/Views/MenuBarContent.swift` | Popover flow | 3-way branch; glass surface; row fade-rise |
| `Seedling/Views/WelcomeView.swift` (new) | First-run welcome | Copy arc + choose-your-path |
| `Seedling/Views/SettingsView.swift` | Settings window | Seed source + main path controls |
| `Seedling/Views/SeedGrowthView.swift` | Line animation | Refined geometry/timing |
| `Seedling/App/SeedHUDPanel.swift` | Service feedback | Glass surface |
| `Seedling/App/AppDelegate.swift` | AppKit glue | Settings-open fix |
| `Seedling/Models/SeedFile.swift` | State | `AppSettings.mainPathURL` + bookmark |
| `README.md` | Docs | macOS 26 / accent / flow |

---

## Task 1: Bump deployment target to macOS 26

**Files:**
- Modify: `Seedling.xcodeproj/project.pbxproj` (both `MACOSX_DEPLOYMENT_TARGET = 14.0;` lines — there are two, in the project-level Debug/Release configs `A100000C…`)
- Modify: `Seedling/Resources/Info.plist:21-22` (`LSMinimumSystemVersion`)

- [ ] **Step 1: Set deployment target to 26.0**

In `project.pbxproj`, change every `MACOSX_DEPLOYMENT_TARGET = 14.0;` to `MACOSX_DEPLOYMENT_TARGET = 26.0;` (use replace-all; there are matches in the two `XCBuildConfiguration` blocks).

- [ ] **Step 2: Set LSMinimumSystemVersion to 26.0**

In `Info.plist`:
```xml
	<key>LSMinimumSystemVersion</key>
	<string>26.0</string>
```

- [ ] **Step 3: Clean build**

Run the clean-build grep (see Testing reality). Expected: empty (no warnings/errors).

- [ ] **Step 4: Checkpoint**
```bash
git add -A && git commit -m "build: target macOS 26 for Liquid Glass" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 2: Pastel sage accent + smaller fonts

**Files:**
- Modify: `Seedling/Theme/KikaColors.swift:14` (accentDark), `:24` (accentLight), `:34-36` (KikaFont)

- [ ] **Step 1: Replace accent tokens**

In `KikaColors.swift`, change:
```swift
    static let accentDark      = Color(hex: 0x97CEC2)
```
and
```swift
    static let accentLight      = Color(hex: 0x4F9E8E)
```

- [ ] **Step 2: Shrink the font tokens**
```swift
enum KikaFont {
    static let title   = Font.system(size: 15, weight: .semibold)
    static let body    = Font.system(size: 12, weight: .regular)
    static let caption = Font.system(size: 10.5, weight: .regular)
}
```

- [ ] **Step 3: Clean build + launch + eyeball**

Build clean, launch. The leaf, buttons, and text should now be pastel sage and slightly smaller. (Button label legibility is fixed in Task 3.)

- [ ] **Step 4: Checkpoint**
```bash
git add -A && git commit -m "style: pastel sage accent + smaller type" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 3: Liquid Glass button styles

**Files:**
- Modify: `Seedling/Theme/KikaComponents.swift` (the `KikaPrimaryButtonStyle` and `KikaSecondaryButtonStyle` definitions)

**Context:** Keep the `Kika*ButtonStyle` type names (call sites depend on them) but re-express them on Liquid Glass. The prominent button is tinted with the accent; on the light pastel accent, label ink is dark for legibility.

- [ ] **Step 1: Read the current styles**

Read `KikaComponents.swift` to see the exact current `KikaPrimaryButtonStyle` / `KikaSecondaryButtonStyle` bodies and the `@Environment(\.kikaTheme)` usage.

- [ ] **Step 2: Re-express primary on glassProminent**

Replace the primary style body so it wraps the label with the accent tint and dark ink, using the prominent glass style. Pattern:
```swift
struct KikaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.kikaTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            // Dark ink on the light dark-mode accent; white on the deeper light-mode accent.
            .foregroundStyle(scheme == .dark ? Color(hex: 0x0C1A17) : .white)
            .padding(.vertical, 7)
            .padding(.horizontal, 18)
            .glassEffect(.regular.tint(theme.accent).interactive(), in: .rect(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
```

- [ ] **Step 3: Re-express secondary on plain glass**
```swift
struct KikaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.kikaTheme) private var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(theme.textSecondary)
            .padding(.vertical, 5)
            .padding(.horizontal, 12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
```

- [ ] **Step 4: Clean build + launch**

Build clean. Launch; pick a folder; confirm the Seed and Change buttons render as glass and the press "give" works.

- [ ] **Step 5: Checkpoint**
```bash
git add -A && git commit -m "style: Liquid Glass button styles with accent tint" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 4: Liquid Glass surfaces (popover + HUD)

**Files:**
- Modify: `Seedling/Views/MenuBarContent.swift` (the `.background(.regularMaterial)` on `body`)
- Modify: `Seedling/App/SeedHUDPanel.swift` (the `.background(.regularMaterial, in:)` in `SeedHUDContent`)

- [ ] **Step 1: Popover glass surface**

In `MenuBarContent.body`, wrap the `Group { … }` content in a `GlassEffectContainer` and replace the material background:
```swift
GlassEffectContainer {
    Group {
        if settings.mainPathURL == nil { /* welcome — Task 6 */ }
        else if folderURL == nil { /* welcome — Task 6 */ }
        else { filledState(theme: theme) }
    }
    .frame(width: 360)
    .glassEffect(.regular, in: .rect(cornerRadius: 20))
}
```
(Keep the existing `.overlay { birthPlaying … }`, `.environment`, `.preferredColorScheme`, `.onAppear`, `.onExitCommand` modifiers on the outer view. The 3-way branch bodies are finalized in Task 6 — for now keep the existing 2-way branch and only swap the background to `.glassEffect`.)

For this task, **minimal change only**: replace `.background(.regularMaterial)` with `.glassEffect(.regular, in: .rect(cornerRadius: 20))` and wrap in `GlassEffectContainer { }`. Leave the branch logic for Task 6.

- [ ] **Step 2: HUD glass surface**

In `SeedHUDPanel.swift` `SeedHUDContent.body`, change:
```swift
        .frame(width: 200, height: 220)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
```

- [ ] **Step 3: Clean build + launch + drive service**

Build clean, launch. Open popover → glass surface. Then drive the Service:
```bash
swift /tmp/drive_service.swift
```
Expected: 5 files created; the HUD shows as a glass card.

- [ ] **Step 4: Checkpoint**
```bash
git add -A && git commit -m "style: Liquid Glass popover and HUD surfaces" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 5: `AppSettings.mainPathURL` (the "main path")

**Files:**
- Modify: `Seedling/Models/SeedFile.swift` (`AppSettings`: add key, published property, init resolve, setter)

**Context:** Mirror the existing `lastFolderURL` bookmark pattern exactly (HANDOFF §5). This is the persisted default destination.

- [ ] **Step 1: Add the key + property**

After `lastTaglineKey` add:
```swift
    private let mainPathBookmarkKey = "seedling.mainPathBookmark"
```
After `lastFolderURL`/`lastProjectName`/`lastTagline` published props add:
```swift
    /// The user's default destination — "your main path." Set once on first run,
    /// editable in Settings. Persisted as a security-scoped bookmark.
    @Published private(set) var mainPathURL: URL?
```

- [ ] **Step 2: Resolve the bookmark in init**

In `init`, after the `lastFolderBookmarkKey` resolve block, add the same pattern for `mainPathBookmarkKey` setting `self.mainPathURL`.

- [ ] **Step 3: Add the setter**
```swift
    /// Set (or change) the main path. Stores a security-scoped bookmark.
    func setMainPath(_ url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        mainPathURL = url
        if let data = try? url.bookmarkData(
            options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil
        ) {
            defaults.set(data, forKey: mainPathBookmarkKey)
        }
    }
```

- [ ] **Step 4: Clean build + verify persistence**

Build clean, launch, (after Task 6 wires it) inspect `defaults read com.seedling.app` for `seedling.mainPathBookmark`. For this task, just confirm clean build.

- [ ] **Step 5: Checkpoint**
```bash
git add -A && git commit -m "feat: AppSettings.mainPathURL with bookmark plumbing" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 6: First-run welcome flow

**Files:**
- Create: `Seedling/Views/WelcomeView.swift`
- Modify: `Seedling/Views/MenuBarContent.swift` (3-way branch; persist main path on first pick)
- Modify: `Seedling.xcodeproj/project.pbxproj` (register WelcomeView.swift — IDs `…A00F`)

- [ ] **Step 1: Create WelcomeView**

```swift
import SwiftUI

/// First-run welcome: "Plant your first seed → Choose your path → …and let it grow."
struct WelcomeView: View {
    @Environment(\.kikaTheme) private var theme
    let onChoose: () -> Void

    var body: some View {
        VStack(spacing: KikaSpacing.md) {
            Spacer(minLength: KikaSpacing.lg)
            Image(systemName: "leaf")
                .font(.system(size: 30, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.accent)
            Text("Plant your first seed")
                .font(KikaFont.title)
                .foregroundStyle(theme.textPrimary)
            Button("Choose your path") { onChoose() }
                .buttonStyle(KikaPrimaryButtonStyle())
                .keyboardShortcut("o", modifiers: [.command])
                .accessibilityLabel("Choose your path")
            Text("…and let it grow")
                .font(.system(size: 12, weight: .regular).italic())
                .foregroundStyle(theme.textSecondary)
            Text("⌥⌘S to summon from anywhere")
                .font(KikaFont.caption)
                .foregroundStyle(theme.textTertiary)
                .padding(.top, KikaSpacing.sm)
            Spacer(minLength: KikaSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, KikaSpacing.lg)
    }
}
```

- [ ] **Step 2: Register WelcomeView in pbxproj**

Add the 4 entries per HANDOFF §15 using IDs `A1000001…A00F` (build) / `A1000002…A00F` (ref) in the Views group + Sources phase.

- [ ] **Step 3: Wire the 3-way branch in MenuBarContent**

Replace the branch in `body`:
```swift
if settings.mainPathURL == nil {
    WelcomeView(onChoose: pickFirstPath)
} else {
    filledState(theme: theme)
}
```
Add the handler:
```swift
private func pickFirstPath() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "Choose"
    if panel.runModal() == .OK, let url = panel.url {
        settings.setMainPath(url)
        applyFolder(url)   // sets folderURL, project name, plays .birth
    }
}
```
In `restoreLastSeed()`, prefer the main path:
```swift
if let url = settings.mainPathURL { folderURL = url; if projectName.isEmpty { projectName = url.lastPathComponent } }
else if let url = settings.lastFolderURL { folderURL = url }
```

- [ ] **Step 4: Clean build + first-run test**
```bash
defaults delete com.seedling.app 2>/dev/null; killall Seedling 2>/dev/null
open ./build/Build/Products/Debug/Seedling.app
```
Open popover → welcome copy + glass. Choose a folder → `.birth` plays → seed screen. Quit and relaunch → goes straight to seed screen. Confirm `defaults read com.seedling.app` shows `seedling.mainPathBookmark`.

- [ ] **Step 5: Checkpoint**
```bash
git add -A && git commit -m "feat: first-run welcome flow with mainPath" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 7: Fix the Settings window + add controls

**Files:**
- Modify: `Seedling/App/AppDelegate.swift` (`openSettings()`)
- Modify: `Seedling/Views/SettingsView.swift` (main-path row; seed-source already present)

- [ ] **Step 1: Reproduce the bug**

Launch the app, right-click the leaf → Settings…, and ⌘,. Confirm the window does not appear/front. Note behavior (this is the systematic-debugging baseline).

- [ ] **Step 2: Apply the ordering fix**

Replace `openSettings()` in `AppDelegate.swift`:
```swift
@objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.async {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.windows.first { $0.identifier?.rawValue.contains("Settings") == true || $0.title == "Seedling Settings" }?
            .makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 3: Verify it opens**

Build clean, launch. ⌘, and right-click → Settings… each open + front the window, repeatedly.

- [ ] **Step 4: If still broken, escalate**

If Step 3 fails, use the `@Environment(\.openSettings)` approach: add a hidden hosted SwiftUI control in the menu-bar popover that captures `openSettings` and call it; or temporarily `NSApp.setActivationPolicy(.regular)` before sending and restore `.accessory` on window close. Pick whichever opens reliably; keep the minimal one.

- [ ] **Step 5: Add the main-path row to Settings**

In `SettingsView.swift`, add a Section showing `settings.mainPathURL?.path ?? "Not set"` with a "Change…" button calling an `NSOpenPanel` → `settings.setMainPath(url)`. Mirror the existing `pickTemplatesFolder()` method.

- [ ] **Step 6: Clean build + verify**

Build clean. Open Settings, change the main path, relaunch → popover seeds into the new main path. Seed source (templates folder) still editable and persists.

- [ ] **Step 7: Checkpoint**
```bash
git add -A && git commit -m "fix: Settings window opens reliably; add main path control" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 8: Microinteractions + refined growth animation

**Files:**
- Create: `Seedling/Theme/Microinteractions.swift`
- Modify: `Seedling/Views/MenuBarContent.swift` (focus underline on text fields; row fade-rise)
- Modify: `Seedling/Views/SeedGrowthView.swift` (thinner stroke; retuned timing)
- Modify: `Seedling.xcodeproj/project.pbxproj` (register Microinteractions.swift — IDs `…A010`)

- [ ] **Step 1: Create the focus-underline modifier**

```swift
import SwiftUI

/// Draws an accent hairline under a focused field. Reduce-motion → instant.
struct FocusUnderline: ViewModifier {
    @Environment(\.kikaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var active: Bool
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            theme.accent
                .frame(height: 1)
                .scaleEffect(x: active ? 1 : 0, anchor: .leading)
                .opacity(active ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: active)
        }
    }
}
extension View { func focusUnderline(_ active: Bool) -> some View { modifier(FocusUnderline(active: active)) } }
```

- [ ] **Step 2: Register Microinteractions.swift in pbxproj**

4 entries per HANDOFF §15, IDs `A1000001…A010` / `A1000002…A010`, in the Theme group + Sources phase.

- [ ] **Step 3: Apply focus underline to the text fields**

In `MenuBarContent.projectBlock`, add `@FocusState private var focus: Field?` (enum `Field { case name, tagline }`), attach `.focused($focus, equals: .name)` / `.tagline` to the two `TextField`s, and `.focusUnderline(focus == .name)` / `.tagline` to their rows.

- [ ] **Step 4: Add row fade-rise to the seed screen**

In `filledState`, give the `ScrollView`'s `VStack` children a staggered appear: add `@State private var appeared = false`, set it true `.onAppear` with `withAnimation(.easeOut(duration: 0.3))`, and apply `.opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 6)` to the project/source/result blocks (skip when reduceMotion).

- [ ] **Step 5: Refine the growth animation**

In `SeedGrowthView.swift`, change the stroke `lineWidth: 1.2` → `1.0`, and shorten `duration` (`.birth` 1.4→1.2, `.growth` 1.6→1.4) to suit the smaller surface.

- [ ] **Step 6: Clean build + launch + reduce-motion test**

Build clean, launch. Focus a field → accent underline draws in. Seed screen rows fade-rise. Seed → refined growth. Enable Reduce Motion (System Settings → Accessibility) → all render statically.

- [ ] **Step 7: Checkpoint**
```bash
git add -A && git commit -m "feat: focus underline, row fade-rise, refined growth" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Task 9: Docs + final verification

**Files:**
- Modify: `README.md` (requirements → macOS 26; mention accent/flow), `Seedling/Views/SettingsView.swift` (About version/copy)

- [ ] **Step 1: Update README requirements**

Change "macOS 14 Sonoma or later" → "macOS 26 (Tahoe) or later"; add a line about the first-run "main path" flow and the ⌥⌘S summon / Finder Service.

- [ ] **Step 2: Update About copy**

In `SettingsView.aboutBlock`, bump the version string and adjust the description if needed.

- [ ] **Step 3: Full verification pass**

- Clean build grep → empty.
- `swift scripts/smoke_test.swift` → passes.
- `defaults delete com.seedling.app` → first-run welcome → choose path → birth → seed screen.
- ⌘, opens Settings; change main path persists.
- `swift /tmp/drive_service.swift` → 5 files + glass HUD.
- Reduce Motion → static animations.
- Visual: compare launched app to the approved mockup (glass, pastel sage, smaller type, copy arc).

- [ ] **Step 4: Checkpoint**
```bash
git add -A && git commit -m "docs: macOS 26, redesign notes; final pass" 2>/dev/null || echo "checkpoint (no git)"
```

---

## Self-review notes

- **Spec coverage:** macOS 26 (T1), accent+type (T2), glass buttons (T3), glass surfaces (T4), mainPath (T5), welcome flow (T6), Settings fix + controls (T7), animation/microinteractions (T8), docs (T9). All spec sections mapped.
- **Type consistency:** `mainPathURL` / `setMainPath(_:)` used consistently across T5/T6/T7; `KikaPrimaryButtonStyle`/`KikaSecondaryButtonStyle` names preserved; `focusUnderline(_:)` defined in T8 before use.
- **Known soft spot:** the Settings-open fix (T7) is the one task with diagnostic uncertainty — T7 includes an escalation path (Step 4) rather than a placeholder.
