# Seedling — Engineering Handoff

> The README is for someone opening the project for the first time. This document is for the next developer who's going to **modify** Seedling.

---

## 1. What you're working with

**Seedling** is a small, focused, menu bar app. No main window. No document model. No navigation. No networking. The state surface is tiny — the hard parts are macOS integration and design discipline.

The whole app is **16 Swift files** plus an Xcode project:

| File | Purpose |
|---|---|
| `App/SeedlingApp.swift` | `@main`, `Settings` scene, App menu |
| `App/AppDelegate.swift` | `NSStatusItem` + ctrl/right-click context `NSMenu` (popUp) + global hotkey + Finder Service + Settings opening; summons the ceremony window |
| `App/CeremonyWindowController.swift` | Centered, borderless, key-accepting `NSPanel` (the ceremony window) that hosts `SeedCeremonyView`; fade in/out + outside-click dismissal |
| `App/GlobalHotKey.swift` | Carbon `RegisterEventHotKey` wrapper for the ⌥⌘S summon hotkey |
| `App/SeedHUDPanel.swift` | Transient borderless panel that plays the growth animation for headless (Finder Service) seeds |
| `Views/SeedCeremonyView.swift` | The ceremony body — the zen rest → growing → alive flow (plus first-run onboarding) |
| `Views/SettingsView.swift` | Settings window (Projects home + seed library + appearance + hotkey + about) |
| `Views/SeedGrowthView.swift` | The line-art seed-growth animation (`.birth` / `.growth`), completing in a soft bloom |
| `Models/SeedFile.swift` | `SeedFile`, `SeedLibrary`, `ProjectOptions`, `AppSettings` |
| `Models/BookmarkedFolder.swift` | Reusable security-scoped folder bookmark (resolve / store / clear) |
| `Engine/Seedling.swift` | Template rendering + file writing + `SeedResult` formatting |
| `Engine/ProjectSeeder.swift` | Sanitize a name, create `ProjectsHome/<name>`, seed into it (never overwrites) |
| `Engine/TemplateLoader.swift` | Load user `.md` files from a folder |
| `Theme/KikaColors.swift` | Color tokens, spacing, fonts, `KikaTheme.resolve(scheme:)` |
| `Theme/KikaComponents.swift` | Reusable views: section header, row, divider, glass button styles |
| `Theme/Microinteractions.swift` | Shared SwiftUI modifiers (focus underline) |

(The largest files — `SeedFile.swift`, `AppDelegate.swift`, `SeedCeremonyView.swift` — are the ones you'll spend the most time in.)

When in doubt, **read `SeedCeremonyView.swift` first** — it's the single source of truth for the ceremony's user-facing flow.

### Platform & design baseline (v2.0)

- **macOS 26 (Tahoe) only.** Deployment target is 26.0 so the app can use Apple's **Liquid Glass** natively (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`) without availability guards.
- **Accent is pastel sage** — `KikaColors.accentDark = 0x97CEC2`, `accentLight = 0x4F9E8E`. It's the only accent; everything reads it via `theme.accent`.
- **Liquid Glass replaces `.regularMaterial`** as the surface treatment on the popover and HUD; KIKA rules still hold (one accent, hairlines, no drop shadows — glass provides depth).

### The design history lives in the repo

- `docs/superpowers/specs/2026-06-03-seedling-zen-redesign-design.md` — the approved design spec for the **v3.0 Zen ceremony redesign** (current source of truth).
- `docs/superpowers/plans/2026-06-03-seedling-zen-redesign.md` — the task-by-task implementation plan for v3.0.
- `docs/superpowers/specs/2026-06-01-seedling-glass-redesign-design.md` + `plans/2026-06-01-seedling-glass-redesign.md` — the **v2.0 popover** redesign. **Archive** — these describe the old menu-bar popover, which v3.0 replaced with the centered ceremony window.
- Git history has one commit per task. `main` holds the pre-redesign snapshot.

---

## 2. Architecture in 90 seconds

### The shape

```
        ⌥⌘S hotkey          NSStatusItem (leaf)          Finder → Services →
        (GlobalHotKey)            │                      "Seed this folder"
            │            ┌────────┼────────┐                     │
            │       left-click       ctrl+click               │
            │                        (or right-click            │
            ▼            │            pre-macOS 27)              ▼
      ceremony.summon ──►│                  ▼            seedFolderFromService
            │            ▼            ┌────────────┐      → performHeadlessSeed
            │   ┌──────────────┐      │ NSMenu     │             │
            │   │ CeremonyWindow│     │ .popUp()   │             ▼
            └──►│ Controller    │     │ Settings…  │      ┌──────────────┐
                │ (NSPanel +    │     │ Quit       │      │  SeedHUD     │
                │ SeedCeremony) │     └────────────┘      │ (NSPanel +   │
                └──────────────┘                          │ SeedGrowth)  │
                         │   gear → Settings              └──────────────┘
                         ▼   power → Quit  (window corners)
     SeedCeremonyView  (SwiftUI view, hosted in the controller's NSPanel)
```

There are **three ways in** — all funnel into the same seed engine + `AppSettings`:
1. **Left-click / ⌥⌘S** → the centered ceremony window (`CeremonyWindowController` → `SeedCeremonyView`).
2. **ctrl+click** (or right-click on macOS ≤ 26) → an `NSMenu` shown via `.popUp()` (Settings… / Quit; About now lives in a Settings tab). See §"Left-click vs. context-click" for *why* ctrl+click — macOS 27 stopped delivering right-clicks to status items.
3. **Finder → Services → "Seed this folder"** → `seedFolderFromService` → `performHeadlessSeed`, confirmed by the `SeedHUD` panel.

The ceremony window also carries its own chrome in the bottom corners: a **gear** (bottom-trailing → Settings) and a **power** glyph (bottom-leading → Quit), so both are reachable without the menu — the visible fallback on macOS 27.

- **`AppDelegate`** owns the `NSStatusItem`, the global hotkey (`GlobalHotKey`), the Services provider, and Settings-window opening, and holds the `CeremonyWindowController`. It's the only place (besides the controller) that touches AppKit.
- **`CeremonyWindowController`** owns the borderless `KeyablePanel`, hosts `SeedCeremonyView`, and handles fade in/out + outside-click dismissal.
- **`SeedlingApp`** is a thin SwiftUI shell that wires the `AppDelegate` and declares the `Settings` scene.
- **`SeedCeremonyView`** is the ceremony body — a SwiftUI `View` (the `NSOpenPanel` for onboarding is the only AppKit it touches). Branches on `phase` (onboarding / rest / growing / alive / failed).
- **`SettingsView`** is the Settings window content — a segmented (`Picker`) tab switch over **Gardening / Keyboard / About**. (About also holds the **Quit Seedling** button and the live version string.)
- **`SeedGrowthView`** is the line-art animation, shown in the ceremony window and inside `SeedHUD` for headless seeds.

### State

| State | Lives in | Type | Persisted? |
|---|---|---|---|
| Seed library (the source) | `AppSettings.templatesFolderURL` | `@Published` | Yes — security-scoped bookmark |
| Projects home (the destination root) | `AppSettings.projectsHomeURL` | `@Published private(set)` | Yes — security-scoped bookmark |
| Theme | `AppSettings.appearance` | `@Published` | Yes — enum raw value |
| Hotkey enabled | `AppSettings.globalHotKeyEnabled` | `@Published` | Yes — bool |
| Current project name / phase / result | `SeedCeremonyView` | `@State` | No (each ceremony starts fresh) |

The only persistent state is in `AppSettings`. The ceremony view derives nothing per open except the resting seed — there is **no** "last seed" memory anymore.

### Inter-component communication

| Direction | Mechanism |
|---|---|
| `SeedCeremonyView` → window (dismiss after the ceremony / on Esc) | `onFinish` closure passed in by `CeremonyWindowController`, which calls `dismiss()` (fade out) |
| `AppSettings.templatesFolderURL` change → status item icon | Combine subscription in `AppDelegate`; calls `updateStatusItemIcon()` |
| `AppDelegate` → `SettingsView` | `appDelegate.settings` is injected as `@EnvironmentObject` in `SeedlingApp`'s `Settings { }` scene |
| `AppDelegate` → `SeedCeremonyView` | `settings` injected as `@EnvironmentObject` via the controller's `NSHostingView` root |

The old `.seedlingDidSeed` notification (which closed the popover) is gone — the window self-dismisses via `onFinish`.

---

## 3. The ceremony flow

The **v3.0 Zen ceremony** replaced the menu-bar popover. The leaf left-click and ⌥⌘S both call `CeremonyWindowController.summon()`, which fades a **centered, borderless, key-accepting `NSPanel`** in on the active screen and hosts `SeedCeremonyView`. The window dismisses on outside click, on Esc, or on its own after the ceremony completes.

`SeedCeremonyView` is a state machine over `enum Phase { onboarding, rest, growing, alive, failed }`:

| Phase | Trigger | What renders |
|---|---|---|
| **onboarding** | `settings.projectsHomeURL == nil` (first run) | "Where do your projects grow?" + one folder pick → `setProjectsHome` → drops into `rest`. The only folder picker in the flow. |
| **rest** | Projects home is set | A breathing seed, one centered `name your project` field (auto-focused), a live `planting in  Home/<name>` line, and a `⏎ to grow` hint. |
| **growing** | Return (or tap the seed) with a non-empty sanitized name | `SeedGrowthView(.growth)` plays while `ProjectSeeder.seed(...)` runs the file I/O on a background queue. |
| **alive** | growth animation **and** I/O both finished (`finalizeIfReady`) | "<name> is alive · N seeds planted · revealing…", then `NSWorkspace.open(folder)` (default file manager) and the window fades out after ~1.1s. |
| **failed** | I/O threw | A quiet message + "Try again" (back to `rest`). |

The destination model is **"Projects home"**: the typed name births `ProjectsHome/<name>` and fills `{{PROJECT_NAME}}`. There is no tagline field (`{{TAGLINE}}` expands to empty). An empty name gives a gentle shake (`ShakeEffect`), never an error. A name that collides with an existing folder seeds into it without overwriting (the engine's safety property) — the alive subline notes "already there".

### The seed-growth animation (`SeedGrowthView`)

Pure SwiftUI line art (no assets). Two `Shape`s (a filled seed dot + a stroked stem/leaves) are driven by a single animatable `progress`, so SwiftUI calls `path(in:)` at each interpolated step and the segment-by-segment drawing is frame-exact (a plain `.trim` can't stagger like this). Modes: `.birth` and `.growth`. The `.growth` mode **completes with a soft bloom of light** — a luminous circle gated on `bloomStarted` that swells and dissolves (one breath). Takes a `size:` param (120 in the ceremony). Honors `accessibilityReduceMotion` by snapping to the final frame (no bloom). Microinteractions (`Theme/Microinteractions.swift`): a focus-underline that draws under the focused name field.

### Where the seed action actually lives

`SeedCeremonyView.attemptGrow()` is the entry point. It:

1. Sanitizes the name (`ProjectSeeder.sanitize`); empty → shake, no seed.
2. Snapshots `settings.resolveSeedFiles()` (seed library folder or built-in defaults).
3. Wraps security-scoped access to `projectsHomeURL` and dispatches to a global `DispatchQueue`.
4. Calls `ProjectSeeder.seed(projectName:into:files:)` (creates the subfolder + seeds, never overwriting).
5. Stores the result; `finalizeIfReady()` advances to `alive` once both I/O and the growth animation are done, posts an `AccessibilityNotification.Announcement`, reveals the folder, and asks the window to dismiss.

The headless **Finder Service** path (`AppDelegate.performHeadlessSeed`) still seeds an existing folder in place and confirms with the `SeedHUD` panel; it also reveals via `NSWorkspace.open(folder)`.

---

## 4. The engine

`Engine/Seedling.swift` is a 90-line struct with two static functions:

```swift
static func render(_ file: SeedFile, options: ProjectOptions) -> String
static func seed(_ files: [SeedFile], into folder: URL, options: ProjectOptions) throws -> SeedResult
```

`render()` does the `{{KEY}}` substitution. The two keys are `{{PROJECT_NAME}}` and `{{TAGLINE}}`. To add a new placeholder, just add a `replacingOccurrences` call in `render()`.

`seed()` does:
1. Empty check (returns a no-op `SeedResult`).
2. Folder-exists check (`SeedError.noFolderSelected`).
3. Folder-writable check (`SeedError.folderNotWritable`).
4. For each file, skip if it exists, otherwise `body.write(to:atomically:encoding:.utf8)`.
5. Return a `SeedResult` with `created`, `skipped`, and `folderURL`.

**Design constraint:** `seed()` never overwrites. This is the safety property — if a user re-runs Seed on a folder that already has a `README.md`, the existing one stays untouched and is reported in `result.skipped`. Don't change this without a clear UX story.

The smoke test in `scripts/smoke_test.swift` exercises this end-to-end with a real temp directory.

---

## 5. Sandbox & bookmarks

Seedling is a sandboxed app. The entitlements are:

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
<key>com.apple.security.files.bookmarks.app-scope</key><true/>
```

What this means in practice:

- The user must explicitly pick any folder we touch (main path, templates folder, last-seeded folder). We can't poke at arbitrary paths.
- To survive across launches, every URL we persist must be a **security-scoped bookmark** (`URL.bookmarkData(options: [.withSecurityScope], ...)`).
- Before reading or writing a bookmarked URL, call `url.startAccessingSecurityScopedResource()`; after, call `url.stopAccessingSecurityScopedResource()`.
- The **Finder Service** path is special: when the user invokes "Seed this folder", macOS hands us a temporary sandbox extension for *that* folder, so `performHeadlessSeed` can write without the folder being pre-bookmarked.

`AppSettings` persists **two** security-scoped bookmarks, both now routed through the `BookmarkedFolder` helper (`Models/BookmarkedFolder.swift` — `resolve()` / `store(_:)` / `clear()`):

- `projectsHomeURL` ← `projectsHomeBookmarkKey`, set by `setProjectsHome(_:)` — where new projects are born.
- `templatesFolderURL` ← `templatesBookmarkKey`, set by `setTemplatesFolder(from:)` (persisted via the `didSet` → `persistTemplatesBookmark()`).

`TemplateLoader.load(from:)` requires the caller to wrap it in start/stop. `AppSettings.resolveSeedFiles()` does this:

```swift
let started = settings.beginTemplatesAccess()
defer { if started { settings.endTemplatesAccess() } }
let loaded = TemplateLoader.load(from: url)
```

`AppSettings.beginTemplatesAccess() / endTemplatesAccess()` are thin wrappers that return a `Bool` indicating whether access was granted, so the caller can skip `endAccess` if the start failed.

**History:** earlier versions had three hand-copied bookmark blocks. v3.0 hit the predicted "fourth bookmark" threshold and extracted `BookmarkedFolder`; the two remaining bookmarks both go through it. New folder bookmarks should use `BookmarkedFolder`, not a fresh hand-rolled copy.

---

## 6. The status item (AppKit)

`AppDelegate` is where AppKit lives. The hot spots:

### Status item icon

```swift
private func updateStatusItemIcon() {
    let hasTemplates = settings.templatesFolderURL != nil
    let symbolName = hasTemplates ? "leaf.fill" : "leaf"
    // ...
}
```

`leaf` is the default state. `leaf.fill` signals "you've configured a custom templates folder." This is wired to a Combine subscription on `settings.$templatesFolderURL`, so the icon updates live when the user changes templates in Settings.

### Left-click vs. context-click

```swift
button.sendAction(on: [.leftMouseUp, .rightMouseUp])

@objc private func handleButtonPress(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    // ctrl+click counts as a context click. On macOS 27 the system stops
    // delivering right-mouse events to status item buttons entirely (the
    // click dies in MenuBarAgent), so ctrl+click — which arrives as a
    // left-click with the .control flag — is the only context gesture left.
    let isContextClick = event?.type == .rightMouseUp
        || event?.modifierFlags.contains(.control) == true
    if isContextClick {
        showContextMenu(from: sender)
    } else {
        ceremony.toggle()   // summon / dismiss the centered ceremony window
    }
}
```

Disambiguating left/context on one `NSStatusBarButton` is the canonical pattern — don't try to attach two separate actions to one button; that doesn't work for `NSStatusItem`. The `.control` branch is **load-bearing on macOS 27**: without it there is no way to open the menu from the leaf at all (right-click is swallowed before the app sees it — verified with instrumented probe apps).

### Showing the menu: `popUp`, not the `performClick` dance

```swift
private func showContextMenu(from button: NSStatusBarButton) {
    let menu = NSMenu()
    // … Settings… / separator / Quit …
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 6), in: button)
}
```

The **old** trick (assign `statusItem.menu`, `performClick(nil)`, then clear it) silently shows *nothing* on macOS 27. The reliable replacement is `NSMenu.popUp(...)` anchored to the button, called straight from the action handler. Don't reintroduce the `statusItem.menu` + `performClick` dance — it's dead on the current OS.

### The visible fallback (ceremony window corners)

Because the leaf menu is reachable only via ctrl+click on macOS 27, the ceremony window carries Settings and Quit as always-visible corner buttons, wired in `SeedCeremonyView`:

- **bottom-trailing `gearshape`** → `onSettings` (the `AppDelegate` closure that opens the Settings window); also bound to `⌘,`.
- **bottom-leading `power`** → `NSApp.terminate(nil)`; also bound to `⌘Q`.

They're set in opposite corners on purpose — the power glyph is kept away from the centered name field so it can't be hit mid-naming. Quit also lives in **Settings → About** for good measure.

### Ceremony window dismissal (global event monitor)

The ceremony window is a borderless `NSPanel`, so it has no built-in transient behavior. `CeremonyWindowController` installs a global mouse-down monitor while the panel is shown and dismisses on any outside click:

```swift
outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
    self?.dismiss()
}
```

The monitor is removed in `dismiss()` (not leaked across summons). `addGlobalMonitorForEvents` requires an accessibility permission for the *caller*, but a sandboxed app calling it for its own UI doesn't need that — the system has implicit permission. **Don't** add a global event monitor for *other apps'* windows; that does require accessibility. Esc is handled separately via `.onExitCommand` inside `SeedCeremonyView`.

### Global summon hotkey (⌥⌘S)

`GlobalHotKey` wraps Carbon's `RegisterEventHotKey` — the **sandbox-safe** way to register a system-wide hotkey with **no Accessibility / Input-Monitoring prompt** (a global `NSEvent` keyDown monitor would require Input Monitoring and a permission prompt, which fights the "invisible" goal). `AppDelegate.refreshHotKey()` registers/unregisters it based on `settings.globalHotKeyEnabled` (Combine-subscribed, like the icon). The handler is `ceremony.summon()`, which **must** `NSApp.activate(ignoringOtherApps:)` before showing the panel (it does), or the window won't take keyboard focus when another app is frontmost — and the `KeyablePanel` subclass overrides `canBecomeKey` so the borderless panel can focus the name field at all. The combo is fixed (`kVK_ANSI_S` + `cmdKey|optionKey`); there's a Settings toggle but no recorder.

### Finder Service ("Seed this folder")

Declared in `Info.plist` under `NSServices` (`NSMessage = seedFolderFromService`, `NSSendFileTypes = ["public.folder"]`). `AppDelegate` sets `NSApp.servicesProvider = self` + `NSUpdateDynamicServices()` at launch. The handler `seedFolderFromService(_:userData:error:)` reads folder URLs from the pasteboard and calls `performHeadlessSeed(into:)`, which reuses `settings.resolveSeedFiles()` + `Seedling.seed(...)`, then shows the `SeedHUD` growth panel and reveals the created files in Finder.

**Gotcha (learned the hard way):** do **not** filter the pasteboard URLs with `URL.hasDirectoryPath` — the directory hint is lost across the Service's pasteboard round-trip, so it returns `false` and silently drops every invocation. Check the filesystem instead (`FileManager.fileExists(atPath:isDirectory:)`). The Service item appears under Finder right-click → **Services**; macOS sometimes needs `/System/Library/CoreServices/pbs -flush` or a re-login to list a freshly-registered service.

### Accessory-app gotchas (these will bite you)

This is an `LSUIElement` (`.accessory`) app — no Dock icon, rarely "frontmost". Two consequences cost real debugging time:

1. **`NSOpenPanel.runModal()` opens *behind* everything** unless you `NSApp.activate(ignoringOtherApps:)` first. Symptom: clicking a "choose folder" button does nothing visible ("stuck"). Always go through `SeedCeremonyView.chooseProjectsHome()` / `SettingsView.chooseDirectory()`, which activate first and set `panel.level = .modalPanel`.
2. **The SwiftUI `Settings` scene won't surface** while the app is `.accessory` (its `showSettingsWindow:` opener is deprecated and no-ops here). `openSettings()` switches to `.regular`, activates, and shows the self-managed `SettingsWindowController` window; `handleWindowClose(_:)` drops back to `.accessory` when the last titled window closes (so the Dock icon only appears while Settings/About is open). See §7 for the full mechanism — don't route this back through the `Settings` scene.

---

## 7. The Settings window

The SwiftUI `Settings` scene's opener (`showSettingsWindow:`) is deprecated since macOS 14 and **no-ops for accessory apps**, so we don't use it. `SeedlingApp.body` declares `Settings { EmptyView() }` only to satisfy the "a scene is required" rule, and routes the standard `⌘,` / "Settings…" command to our own opener:

```swift
Settings { EmptyView() }                      // never surfaced
// …
CommandGroup(replacing: .appSettings) {
    Button("Settings…") { appDelegate.openSettings() }
}
```

The real window is a **self-managed `NSWindow`** owned by `SettingsWindowController` (titled + closable, hosting `SettingsView`). `AppDelegate.openSettings()` flips to `.regular`, activates, and calls `settingsWindow.show()`; `handleWindowClose(_:)` drops back to `.accessory` when the last titled window closes (so the Dock icon only appears while Settings/About is open). Entry points: the ceremony window's **gear** (most discoverable), the **ctrl+click** leaf menu, and `⌘,` once any app window is key. Don't "simplify" this back to `Settings { SettingsView() }` + `showSettingsWindow:` — it won't open.

`SettingsView` is a segmented-tab layout — a `Picker(.segmented)` switching **Gardening / Keyboard / About**. *Gardening* holds the Root (seed library) and Garden (projects home) hero cards plus the theme picker; *Keyboard* lists the shortcuts and the ⌥⌘S summon toggle; *About* shows the icon, the **live** version string (read from `CFBundleShortVersionString` / `CFBundleVersion`, not hardcoded), and the **Quit Seedling** button. Both folder pickers go through a local `chooseDirectory()` that activates the app first.

---

## 8. Building & running

### From the command line

```bash
xcodebuild \
  -project Seedling.xcodeproj \
  -scheme Seedling \
  -configuration Debug \
  -derivedDataPath ./build \
  build
```

Then:

```bash
open build/Build/Products/Debug/Seedling.app
```

### Reset all settings

```bash
defaults delete com.seedling.app
killall Seedling
open build/Build/Products/Debug/Seedling.app
```

### Smoke-test the engine

```bash
swift scripts/smoke_test.swift
```

This is a self-contained runnable script. It inlines the minimal engine + model types and runs six assertions against a real temp directory:

- 5 default files defined
- 5 files created, 0 skipped on first pass
- `{{PROJECT_NAME}}` and `{{TAGLINE}}` placeholders substituted correctly
- 0 created, 5 skipped on re-seed (never overwrites)
- Partial seed: 1 created, 1 skipped, existing file untouched
- Invalid folder throws `SeedError.noFolderSelected`

Expected output ends with `All smoke tests passed ✅`.

**Why inlined?** A `swift script` can't import an Xcode app target's types. The inlined types mirror the production code; if you change `Seedling.swift` or `SeedFile.swift`, mirror the change here. The script is the test specification.

### Verify the build is "clean" (no warnings, no errors)

```bash
xcodebuild \
  -project Seedling.xcodeproj \
  -scheme Seedling \
  -configuration Debug \
  -derivedDataPath ./build \
  build 2>&1 | grep -E "warning:|error:" | grep -v "deprecated" | grep -v "AppIntents"
```

Should be empty.

---

## 9. Common tasks

### "Add a new built-in template"

1. Open `Models/SeedFile.swift`.
2. Find `SeedLibrary.files`.
3. Append a new `SeedFile(...)` literal.
4. Set `defaultEnabled: true` if you want it in the default set.
5. Pick an `icon:` that's an SF Symbol name (check in SF Symbols app first).
6. Run a build — there are no other files to touch.

### "Add a new placeholder"

1. Open `Engine/Seedling.swift`.
2. In `render(_:options:)`, add a `replacingOccurrences(of: "{{KEY}}", with: options.field)`.
3. Add a `var field: String` to `ProjectOptions` in `Models/SeedFile.swift` and pass it through `ProjectSeeder.seed(...)`.
4. Note: the ceremony is deliberately **name-only** (zen). Surfacing a new input in `SeedCeremonyView` fights that design — prefer deriving the value (like `{{PROJECT_NAME}}` from the typed name) over adding a field.

### "Add a new menu-bar context-menu item"

1. Open `App/AppDelegate.swift`.
2. Find `showContextMenu(from:)`.
3. Add a new `NSMenuItem(...)` with an action selector (set its `.target`).
4. Add a `@objc func` that handles the action.
5. Remember the menu only opens on **ctrl+click** on macOS 27 — if the item is important, consider also surfacing it in the ceremony window (like the gear/power) or in Settings.

### "Add a new Settings section"

1. Open `Views/SettingsView.swift`.
2. Add a `Section { }` block to the `Form`.
3. Add a header in the `header:` closure.
4. Use `KikaSectionHeader` / `KikaRow` for content; the `theme` env is already set up.

### "Change the auto-dismiss timer"

Search for `3.0` in `App/AppDelegate.swift`. The single match is the `DispatchQueue.main.asyncAfter` delay in `handleSeedDidComplete()`.

### "Reset the first-run experience"

First run is gated by `projectsHomeURL == nil` (the onboarding phase in `SeedCeremonyView`). To see the onboarding flow again, clear all persisted state:

```bash
defaults delete com.seedling.app
killall Seedling
open build/Build/Products/Debug/Seedling.app
```

### "Change the summon hotkey"

The combo is fixed in `App/GlobalHotKey.swift` (`defaultKeyCode` / `defaultModifiers`). Change those two; there is no recorder UI (deliberate — there's just an on/off toggle in Settings bound to `AppSettings.globalHotKeyEnabled`).

### "Verify the Finder Service end-to-end"

You can drive it without Finder using `NSPerformService` from a Swift script: put a folder URL on a pasteboard and call `NSPerformService("Seedling/Seed this folder", pboard)`, then check the folder for the seeded files. (This is how the Service bug was caught — `runModal`-free, observable on disk.)

---

## 10. Design system rules

Seedling is built on the KIKA Design System v2. The hard rules:

- **No hardcoded colors at call sites.** Always go through `KikaTheme.resolve(scheme: colorScheme)` and read tokens from the resolved `KikaTheme`. The `KikaColors` enum exists for *token definition*, not for direct use.
- **No custom fonts.** `Font.system(size:weight:)` only, via `KikaFont.title / body / caption` (now 15 / 12 / 10.5 — the v2.0 "smaller, higher-end" pass).
- **No drop shadows.** Depth comes from **Liquid Glass** (`.glassEffect(...)`) on floating surfaces, or `RoundedRectangle().fill(surface)` for inline cards — never a shadow.
- **No multi-color palettes.** Accent is the pastel sage `KikaColors.accentDark` (`0x97CEC2`) / `accentLight` (`0x4F9E8E`) — the only accent. On the prominent glass button, label ink is dark (`0x0C1A17`) in dark mode for legibility on the light accent.
- **One primary action per view.** Don't stack two `KikaPrimaryButtonStyle` buttons side-by-side.
- **SF Symbols only.** `Image(systemName: ...)` and `Label`. No custom icon assets.
- **Three gap values: 12, 16, 20.** `KikaSpacing.sm / md / lg`. Don't introduce arbitrary `padding(8)`.
- **No subtitles.** If a label and a description feel needed, rewrite the description as the label.

The popover's action bar is the place to look at the design system working: one primary action (Seed) + two icon-only secondaries, a single divider above, three gap values used throughout.

If you're ever tempted to add a "feature" that violates these (e.g. a colored icon background, a 6th placeholder color, a custom font), stop and ask: is this consistent with the rest of the app, or does it make Seedling look like a different app?

---

## 11. Apple HIG compliance

Seedling was audited against the Apple HIG for macOS (loaded from `~/Documents/OPENSKILLZ/apple-hig-swiftui-macos`). Compliance highlights:

- **Menu bar app pattern** — `LSUIElement = true`, no Dock icon (except transiently while Settings/About is open), no main window, `NSStatusItem` owns the entry point.
- **Standard App menu** — `CommandGroup(replacing: .appInfo)` for About. The `Settings` scene declares Settings; opening it is handled in `AppDelegate` (see §6/§7).
- **Settings via `Settings { }` scene** — not a sheet, not a custom window. Standard `Form { }` inside.
- **Settings `.windowResizability(.contentSize)`** — settings windows shouldn't be user-resizable.
- **Floating surfaces use Liquid Glass** — the popover and HUD use `.glassEffect(...)` (macOS 26).
- **Keyboard** — `⌘O` (pick folder), `⌘↩` (seed), `Esc` (close the ceremony via `.onExitCommand`), `⌘,` (settings — the ceremony gear's shortcut), `⌘Q` (quit — the ceremony power glyph's shortcut).
- **Accessibility** — every icon-only button has `.accessibilityLabel` and `.accessibilityInputLabels([...])`. Section headers are `.accessibilityAddTraits(.isHeader)` for the VoiceOver rotor. `AccessibilityNotification.Announcement` posts the result of every Seed.
- **SF Symbols** — `.imageScale(.medium)` instead of hardcoded `.font(.system(size:))` for icons. `.symbolRenderingMode(.hierarchical)` for the leaf icon and folder icons in Settings.

If you ever change one of these, re-read the relevant HIG reference (`accessibility.md`, `menus-commands.md`, `settings-sheets.md`, `keyboard-focus.md`, `sf-symbols.md`).

---

## 12. Known limitations

- **No multi-select for project folder.** The popover picks one destination. Multi-folder seeding is out of scope.
- **No file-level overrides.** You can't pick "only AGENTS, not README" from the popover. The default set is the default set; the templates folder replaces it wholesale. (This was a deliberate simplification — the previous version had per-file toggles and presets, but it made the popover feel like a "settings page" instead of a "one-click action.")
- **No recursive templates folder scan.** `TemplateLoader` reads only the top level of the chosen folder. Subdirectories are skipped.
- **No placeholder for tagline defaults.** If the user doesn't fill in a tagline, the `{{TAGLINE}}` token expands to an empty string (not "TODO" or anything helpful). If you want a fallback, add it in `Seedling.render(_:options:)`.
- **No automatic theme follow in light menu bar.** The status item icon is `isTemplate = true`, so it picks up the menu bar tint, but the *popover* doesn't follow the menu bar's appearance; it follows `settings.appearance`.

---

## 13. Things that look fragile but aren't

- **`@MainActor` on `AppDelegate` and `AppSettings`.** They need it. Don't drop it.
- **`KeyablePanel` overriding `canBecomeKey`/`canBecomeMain` to return `true`.** A borderless `NSPanel` can't become key by default, so the name field couldn't take keyboard focus. This override is what lets the user type immediately. Don't drop it.
- **`@Published private(set) var projectsHomeURL: URL?`.** Marked private(set) because the public API for setting it is `setProjectsHome(_:)` — which wraps the bookmark logic via `BookmarkedFolder`. Don't expose a public setter.
- **The Combine subscription in `applicationDidFinishLaunching`.** It looks like it should live somewhere else, but `applicationDidFinishLaunching` is the only place where the `AppDelegate` is guaranteed to be alive and the `AppSettings` is guaranteed to be initialized.
- **`NotificationCenter.default.addObserver(self, selector:...)` instead of `for: ... .receive(on:...)`.** Targets must be `@objc` for selector-based observation, and `AppDelegate` is already `@objc` (it's `NSObject`). This is the right tool for an `@objc` target.

---

## 14. Things that actually are fragile

- **The context `NSMenu` rebuild.** The `NSMenu` is created fresh on every context-click and shown via `popUp` (see §"Showing the menu"). If you add stateful menu items (e.g. a checkmark that persists), track the state elsewhere and rebuild on open — don't mutate the existing menu in place.
- **macOS 27 swallows status-item right-clicks.** Verified OS behavior on the 27 beta: right-mouse events never reach the status button (they die in `MenuBarAgent`), and `button.menu` never fires either. The whole context path therefore hangs on the `.control`-modifier branch + `popUp`. If a future macOS restores right-click delivery, the existing `.rightMouseUp` branch already handles it — leave both.
- **Status item button's accessibility description.** Currently set to `"Seedling"` via `NSImage(systemSymbolName:accessibilityDescription:)`. If you change the icon symbol, the description doesn't auto-update. Keep them in sync.
- **The global event monitor is never removed on `applicationWillTerminate`.** It's removed in `deinit`. If the app is force-killed, the monitor is leaked briefly. macOS cleans it up. Don't worry about it.

---

## 15. Files in the project that are not Swift

| File | Notes |
|---|---|
| `Seedling.xcodeproj/project.pbxproj` | Hand-maintained. Adding a new Swift file requires: (1) `PBXBuildFile` entry, (2) `PBXFileReference` entry, (3) entry in the appropriate `PBXGroup` (App / Engine / Models / Resources / Theme / Views), (4) entry in `PBXSourcesBuildPhase`. Use unique 24-character hex IDs — `A1000001000000000000XXXX` for `PBXBuildFile`, `A1000002000000000000XXXX` for `PBXFileReference`. The `XXXX` suffixes are in use up to `A010`; the next file is `A011`. `MACOSX_DEPLOYMENT_TARGET = 26.0` in all four configs. |
| `Seedling/Resources/Info.plist` | `LSUIElement = true` makes this a menu bar app; `LSMinimumSystemVersion = 26.0`. The `NSServices` array declares the Finder "Seed this folder" service (`NSMessage = seedFolderFromService`, `NSSendFileTypes = ["public.folder"]`). `CFBundleShortVersionString` + `CFBundleVersion` are the only version source of truth — the About tab reads them live (no hardcoded version string anymore). Bump both here for a release. |
| `Seedling/Resources/Seedling.entitlements` | Sandbox + user-selected files + bookmarks. Removing any of these will break the app. |
| `Seedling.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Auto-generated by Xcode. Don't hand-edit. |
| `Seedling.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Build system + preview settings. |
| `scripts/smoke_test.swift` | Engine test, not a runnable script in its current form. |

---

## 16. What to do when you don't know where to put something

- **UI logic** → `Views/`
- **Persistent user state** → `Models/SeedFile.swift` (the `AppSettings` class)
- **Pure file I/O** → `Engine/`
- **AppKit / system integration** (status item, hotkey, Services, Settings opening, HUD) → `App/`
- **Reusable visual component** → `Theme/KikaComponents.swift`
- **A reusable interaction modifier** (press, focus, hover) → `Theme/Microinteractions.swift`
- **Animation / motion** → `Views/SeedGrowthView.swift`
- **Color / font / spacing token** → `Theme/KikaColors.swift`
- **A new built-in markdown file** → `Models/SeedFile.swift`'s `SeedLibrary.files`

If it doesn't fit any of those, you're probably designing a new feature, not just adding to an existing one. Stop, sketch the UX, then come back.
