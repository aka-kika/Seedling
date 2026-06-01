# Seedling — Engineering Handoff

> The README is for someone opening the project for the first time. This document is for the next developer who's going to **modify** Seedling.

---

## 1. What you're working with

**Seedling** is a small, focused, menu bar app. No main window. No document model. No navigation. No networking. The state surface is tiny — the hard parts are macOS integration and design discipline.

The whole app is **14 Swift files** plus an Xcode project:

| File | Lines | Purpose |
|---|---|---|
| `App/SeedlingApp.swift` | 42 | `@main`, `Settings` scene, App menu |
| `App/AppDelegate.swift` | 307 | `NSStatusItem` + `NSPopover` + right-click `NSMenu` + global hotkey + Finder Service + Settings opening |
| `App/GlobalHotKey.swift` | 80 | Carbon `RegisterEventHotKey` wrapper for the ⌥⌘S summon hotkey |
| `App/SeedHUDPanel.swift` | 110 | Transient borderless panel that plays the growth animation for headless (Finder Service) seeds |
| `Views/MenuBarContent.swift` | 451 | The popover body (welcome / seed / result) |
| `Views/WelcomeView.swift` | 35 | First-run welcome ("Plant your first seed → Choose your path → …and let it grow") |
| `Views/SettingsView.swift` | 235 | Settings window (main path + templates + appearance + hotkey + about) |
| `Views/SeedGrowthView.swift` | 230 | The line-art seed-growth animation (`.birth` / `.growth`) |
| `Models/SeedFile.swift` | 522 | `SeedFile`, `SeedLibrary`, `ProjectOptions`, `AppSettings` |
| `Engine/Seedling.swift` | 91 | Template rendering + file writing |
| `Engine/TemplateLoader.swift` | 77 | Load user `.md` files from a folder |
| `Theme/KikaColors.swift` | 102 | Color tokens, spacing, fonts, `KikaTheme.resolve(scheme:)` |
| `Theme/KikaComponents.swift` | 160 | Reusable views: section header, row, divider, glass button styles |
| `Theme/Microinteractions.swift` | 22 | Shared SwiftUI modifiers (focus underline) |

(Line counts current as of the v2.0 redesign; they may drift ±20 lines. The relative ordering — `SeedFile.swift`, `MenuBarContent.swift`, and `AppDelegate.swift` are the largest — is stable.)

When in doubt, **read `MenuBarContent.swift` first** — it's the single source of truth for the popover's user-facing flow.

### Platform & design baseline (v2.0)

- **macOS 26 (Tahoe) only.** Deployment target is 26.0 so the app can use Apple's **Liquid Glass** natively (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`) without availability guards.
- **Accent is pastel sage** — `KikaColors.accentDark = 0x97CEC2`, `accentLight = 0x4F9E8E`. It's the only accent; everything reads it via `theme.accent`.
- **Liquid Glass replaces `.regularMaterial`** as the surface treatment on the popover and HUD; KIKA rules still hold (one accent, hairlines, no drop shadows — glass provides depth).

### The design history lives in the repo

- `docs/superpowers/specs/2026-06-01-seedling-glass-redesign-design.md` — the approved design spec for the v2.0 redesign.
- `docs/superpowers/plans/2026-06-01-seedling-glass-redesign.md` — the task-by-task implementation plan.
- Git history on the `glass-redesign` branch has one commit per task. `main` holds the pre-redesign snapshot.

---

## 2. Architecture in 90 seconds

### The shape

```
        ⌥⌘S hotkey          NSStatusItem (leaf)          Finder → Services →
        (GlobalHotKey)            │                      "Seed this folder"
            │            ┌────────┼────────┐                     │
            │       left-click          right-click              │
            ▼            │                  │                    ▼
       summonPopover ───►│                  ▼            seedFolderFromService
            │            ▼            ┌────────────┐      → performHeadlessSeed
            │       ┌─────────┐       │  NSMenu    │             │
            │       │ NSPopover│      │ About      │             ▼
            └──────►│ (SwiftUI)│      │ Settings…  │      ┌──────────────┐
                    │ welcome /│      │ Quit       │      │  SeedHUD     │
                    │ seed     │      └────────────┘      │ (NSPanel +   │
                    └─────────┘                           │ SeedGrowth)  │
                         │                                └──────────────┘
                         ▼
       MenuBarContent  (SwiftUI view, hosted in NSHostingController)
```

There are **three ways in** — all funnel into the same seed engine + `AppSettings`:
1. **Left-click / ⌥⌘S** → the popover (`MenuBarContent`).
2. **Right-click** → `NSMenu` (About / Settings… / Quit).
3. **Finder → Services → "Seed this folder"** → `seedFolderFromService` → `performHeadlessSeed`, confirmed by the `SeedHUD` panel.

- **`AppDelegate`** owns the `NSStatusItem`, the `NSPopover`, the global hotkey (`GlobalHotKey`), the Services provider, and Settings-window opening. It's the only place that touches AppKit.
- **`SeedlingApp`** is a thin SwiftUI shell that wires the `AppDelegate` and declares the `Settings` scene.
- **`MenuBarContent`** is the popover body — a SwiftUI `View` (no AppKit). Branches on `settings.mainPathURL`: `nil` → `WelcomeView`, else the seed/result screen.
- **`SettingsView`** is the Settings window content. Standard SwiftUI `Form { }`.
- **`SeedGrowthView`** is the line-art animation, shown inline in the popover and inside `SeedHUD` for headless seeds.

### State

| State | Lives in | Type | Persisted? |
|---|---|---|---|
| Templates folder (the source) | `AppSettings.templatesFolderURL` | `@Published` | Yes — security-scoped bookmark |
| Last-seeded folder (the destination) | `AppSettings.lastFolderURL` | `@Published private(set)` | Yes — security-scoped bookmark |
| Last project name / tagline | `AppSettings.lastProjectName` / `lastTagline` | `@Published private(set)` | Yes — plain strings |
| Theme | `AppSettings.appearance` | `@Published` | Yes — enum raw value |
| Current project name / tagline / folder | `MenuBarContent` | `@State` | No (re-populated from `AppSettings` on popover open) |
| Last result | `MenuBarContent.lastResult` | `@State` | No (cleared when a new seed runs) |

The only persistent state is in `AppSettings`. The popover re-derives everything from it on each `.onAppear`.

### Inter-component communication

| Direction | Mechanism |
|---|---|
| `MenuBarContent` → `AppDelegate` (close popover after seed) | `Notification.Name.seedlingDidSeed` posted by `MenuBarContent`; observed by `AppDelegate`; calls `popover.performClose(_:)` after 3s |
| `AppSettings.templatesFolderURL` change → status item icon | Combine subscription in `AppDelegate`; calls `updateStatusItemIcon()` |
| `AppDelegate` → `SettingsView` | `appDelegate.settings` is injected as `@EnvironmentObject` in `SeedlingApp`'s `Settings { }` scene |

The `Notification.Name` is a bit much for two collaborators, but it keeps `MenuBarContent` free of `NSPopover` references. Don't replace it with direct coupling unless you're prepared to pass an `NSPopver` instance into the SwiftUI view.

---

## 3. The popover flow

`MenuBarContent.body` branches on **`settings.mainPathURL`** (the persisted default destination, "your main path"):

| State | Trigger | What renders |
|---|---|---|
| **Welcome** | `mainPathURL == nil` (first run) | `WelcomeView`: leaf → "Plant your first seed" → **Choose your path** → "…and let it grow" → ⌥⌘S hint. Choosing a folder calls `setMainPath`, plays the `.birth` animation, and reveals the seed screen. |
| **Seed / result** | `mainPathURL != nil` | Project section + Source section + Result section (with the `.growth` animation, if seeded) + pinned action bar (Seed + folder + reset). Sized to show in **one window without scrolling** (`maxHeight: 480`). |

Folder choosing goes through `chooseDirectory()`, which **calls `NSApp.activate(ignoringOtherApps:)` before `NSOpenPanel.runModal()`** — see §6 (accessory-app gotchas) for why. `restoreLastSeed()` fires once per popover open, pre-filling `folderURL` from `mainPathURL` first (then `lastFolderURL`), plus `lastProjectName` / `lastTagline`. `resetForm()` re-pins to the main path rather than clearing to nil.

### The seed-growth animation (`SeedGrowthView`)

Pure SwiftUI line art (no assets). Two `Shape`s (a filled seed dot + a stroked stem/leaves) are driven by a single animatable `progress`, so SwiftUI calls `path(in:)` at each interpolated step and the segment-by-segment drawing is frame-exact (a plain `.trim` can't stagger like this). Modes: `.birth` (welcome beat, on first folder choice) and `.growth` (every successful seed). Takes a `size:` param (120 default; 64 inline in the result so it fits without scrolling). Honors `accessibilityReduceMotion` by snapping to the final frame. Microinteractions (`Theme/Microinteractions.swift`): a focus-underline that draws under a focused text field; rows fade-rise on appear; buttons "give" on press (in the glass button styles).

### Where the Seed action actually lives

`MenuBarContent.seed()` is the entry point. It:

1. Validates `folderURL` is non-nil.
2. Snapshots `filesToSeed` (templates folder or built-in defaults).
3. Dispatches to a global `DispatchQueue` (file I/O on the background).
4. Calls `Seedling.seed(_:into:options:)` and posts `.seedlingDidSeed` on success.
5. Calls `AppSettings.recordSeed(...)` so the next popover open pre-fills.
6. Posts an `AccessibilityNotification.Announcement` with the result headline.

The `AppDelegate` listens for `.seedlingDidSeed` and closes the popover 3s later — long enough for the user to read the result and click a file row to reveal in Finder.

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

`AppSettings` persists **three** security-scoped bookmarks, each with the same shape (a key constant, a resolve-on-init branch, and a setter that wraps start/stop access):

- `mainPathURL` ← `mainPathBookmarkKey`, set by `setMainPath(_:)` — the default destination ("your main path").
- `templatesFolderURL` ← `templatesBookmarkKey`, set by `setTemplatesFolder(from:)`.
- `lastFolderURL` ← `lastFolderBookmarkKey`, set by `recordSeed(folder:projectName:tagline:)`.

`TemplateLoader.load(from:)` requires the caller to wrap it in start/stop. The popover does this in `filesToSeed`:

```swift
let started = settings.beginTemplatesAccess()
defer { if started { settings.endTemplatesAccess() } }
let loaded = TemplateLoader.load(from: url)
```

`AppSettings.beginTemplatesAccess() / endTemplatesAccess()` are thin wrappers that return a `Bool` indicating whether access was granted, so the caller can skip `endAccess` if the start failed.

**Gotcha:** there are now three near-identical bookmark blocks (the original docs predicted this would be the moment to generalize). It's still deliberately explicit — three short, debuggable copies beat one clever abstraction. If you add a *fourth*, that's the time to extract a small `BookmarkedFolder` helper.

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

### Left-click vs. right-click

```swift
button.sendAction(on: [.leftMouseUp, .rightMouseUp])

@objc private func handleButtonPress(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp {
        showContextMenu()
    } else {
        togglePopover()
    }
}
```

This is the canonical way to disambiguate left/right on an `NSStatusBarButton`. Don't try to attach two separate actions to one button — that doesn't work for `NSStatusItem`.

### Right-click menu trick

```swift
statusItem.menu = menu
statusItem.button?.performClick(nil)
statusItem.menu = nil
```

The menu is set on the `statusItem` *temporarily*, then the button is clicked, then the menu is removed. This makes the right-click menu appear *under* the cursor at the right time. Without this dance, the menu can appear at the wrong location or not appear at all.

### Popover transient + global event monitor

```swift
popover.behavior = .transient  // dismisses on outside click
eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { ... }
```

`.transient` is supposed to dismiss on outside click, but in practice the global event monitor is more reliable — it works even when the click target is in another app. Belt + suspenders.

`addGlobalMonitorForEvents` requires an accessibility permission for the *caller*, but a sandboxed app calling it for its own popover doesn't need that — the system has implicit permission for the app's own UI. **Don't** add a global event monitor for *other apps'* windows; that does require accessibility.

### Global summon hotkey (⌥⌘S)

`GlobalHotKey` wraps Carbon's `RegisterEventHotKey` — the **sandbox-safe** way to register a system-wide hotkey with **no Accessibility / Input-Monitoring prompt** (a global `NSEvent` keyDown monitor would require Input Monitoring and a permission prompt, which fights the "invisible" goal). `AppDelegate.refreshHotKey()` registers/unregisters it based on `settings.globalHotKeyEnabled` (Combine-subscribed, like the icon). The handler is `summonPopover()`: it **must** `NSApp.activate(ignoringOtherApps:)` before `togglePopover()`, or the popover won't take keyboard focus when another app is frontmost. The combo is fixed (`kVK_ANSI_S` + `cmdKey|optionKey`); there's a Settings toggle but no recorder.

### Finder Service ("Seed this folder")

Declared in `Info.plist` under `NSServices` (`NSMessage = seedFolderFromService`, `NSSendFileTypes = ["public.folder"]`). `AppDelegate` sets `NSApp.servicesProvider = self` + `NSUpdateDynamicServices()` at launch. The handler `seedFolderFromService(_:userData:error:)` reads folder URLs from the pasteboard and calls `performHeadlessSeed(into:)`, which reuses `settings.resolveSeedFiles()` + `Seedling.seed(...)`, then shows the `SeedHUD` growth panel and reveals the created files in Finder.

**Gotcha (learned the hard way):** do **not** filter the pasteboard URLs with `URL.hasDirectoryPath` — the directory hint is lost across the Service's pasteboard round-trip, so it returns `false` and silently drops every invocation. Check the filesystem instead (`FileManager.fileExists(atPath:isDirectory:)`). The Service item appears under Finder right-click → **Services**; macOS sometimes needs `/System/Library/CoreServices/pbs -flush` or a re-login to list a freshly-registered service.

### Accessory-app gotchas (these will bite you)

This is an `LSUIElement` (`.accessory`) app — no Dock icon, rarely "frontmost". Two consequences cost real debugging time:

1. **`NSOpenPanel.runModal()` opens *behind* everything** unless you `NSApp.activate(ignoringOtherApps:)` first. Symptom: clicking a "choose folder" button does nothing visible ("stuck"). Always go through `MenuBarContent.chooseDirectory()` / `SettingsView.chooseDirectory()`, which activate first and set `panel.level = .modalPanel`.
2. **The SwiftUI `Settings` scene won't surface** while the app is `.accessory`. `openSettings()` switches to `.regular`, activates, then sends `showSettingsWindow:`; `handleWindowClose(_:)` drops back to `.accessory` when the last titled window closes (so the Dock icon only appears while Settings/About is open). Don't "simplify" this back to a bare `sendAction` — it won't open.

---

## 7. The Settings window

`SeedlingApp.body` declares a single scene:

```swift
Settings {
    SettingsView()
        .environmentObject(appDelegate.settings)
}
.windowResizability(.contentSize)
```

This declares the scene and prevents resizing. **But** opening it is not automatic for an accessory app — see §6 "Accessory-app gotchas": `AppDelegate.openSettings()` flips to `.regular`, activates, and sends `showSettingsWindow:`, restoring `.accessory` on close. `⌘,` only works once a window of the app is key (i.e. after Settings/About is already open); the reliable entry point is right-click → Settings….

`SettingsView` is a `Form { }` with five sections: **Main path**, Templates folder, Appearance, Shortcut (the ⌥⌘S toggle), and About. The templates hero is a custom card (not a `Form` row) because it needs an elevated background and inline path display. Both folder pickers go through a local `chooseDirectory()` that activates the app first.

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
3. Add a `var field: String` to `ProjectOptions` in `Models/SeedFile.swift`.
4. Add a `TextField` in `MenuBarContent.projectBlock` that binds to a new `@State` and passes it into the `seed(...)` call.

### "Add a new menu-bar right-click item"

1. Open `App/AppDelegate.swift`.
2. Find `showContextMenu()`.
3. Add a new `NSMenuItem(...)` with an action selector.
4. Add a `@objc func` that handles the action.

### "Add a new Settings section"

1. Open `Views/SettingsView.swift`.
2. Add a `Section { }` block to the `Form`.
3. Add a header in the `header:` closure.
4. Use `KikaSectionHeader` / `KikaRow` for content; the `theme` env is already set up.

### "Change the auto-dismiss timer"

Search for `3.0` in `App/AppDelegate.swift`. The single match is the `DispatchQueue.main.asyncAfter` delay in `handleSeedDidComplete()`.

### "Reset the first-run experience"

First run is gated by `mainPathURL == nil` (the `WelcomeView`). To see the welcome flow again, clear all persisted state:

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
- **Keyboard** — `⌘O` (pick folder), `⌘↩` (seed), `Esc` (close popover via `.onExitCommand`), `⌘,` (settings), `⌘Q` (quit).
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
- **`popover.contentViewController?.view.window?.makeKey()` after `show(...)`.** This is what makes the popover accept keyboard input. Without it, `⌘O` and `⌘↩` don't fire.
- **`@Published private(set) var lastFolderURL: URL?`.** Marked private(set) because the public API for setting it is `recordSeed(...)` — which wraps the bookmark logic. Don't expose a public setter.
- **The Combine subscription in `applicationDidFinishLaunching`.** It looks like it should live somewhere else, but `applicationDidFinishLaunching` is the only place where the `AppDelegate` is guaranteed to be alive and the `AppSettings` is guaranteed to be initialized.
- **`NotificationCenter.default.addObserver(self, selector:...)` instead of `for: ... .receive(on:...)`.** Targets must be `@objc` for selector-based observation, and `AppDelegate` is already `@objc` (it's `NSObject`). This is the right tool for an `@objc` target.

---

## 14. Things that actually are fragile

- **The right-click `NSMenu` rebuild.** The `NSMenu` is created fresh on every right-click. If you add stateful menu items (e.g. a checkmark that persists), you need to track the state elsewhere and rebuild the menu when the state changes. Don't try to mutate the existing menu in place.
- **Status item button's accessibility description.** Currently set to `"Seedling"` via `NSImage(systemSymbolName:accessibilityDescription:)`. If you change the icon symbol, the description doesn't auto-update. Keep them in sync.
- **The global event monitor is never removed on `applicationWillTerminate`.** It's removed in `deinit`. If the app is force-killed, the monitor is leaked briefly. macOS cleans it up. Don't worry about it.

---

## 15. Files in the project that are not Swift

| File | Notes |
|---|---|
| `Seedling.xcodeproj/project.pbxproj` | Hand-maintained. Adding a new Swift file requires: (1) `PBXBuildFile` entry, (2) `PBXFileReference` entry, (3) entry in the appropriate `PBXGroup` (App / Engine / Models / Resources / Theme / Views), (4) entry in `PBXSourcesBuildPhase`. Use unique 24-character hex IDs — `A1000001000000000000XXXX` for `PBXBuildFile`, `A1000002000000000000XXXX` for `PBXFileReference`. The `XXXX` suffixes are in use up to `A010`; the next file is `A011`. `MACOSX_DEPLOYMENT_TARGET = 26.0` in all four configs. |
| `Seedling/Resources/Info.plist` | `LSUIElement = true` makes this a menu bar app; `LSMinimumSystemVersion = 26.0`. The `NSServices` array declares the Finder "Seed this folder" service (`NSMessage = seedFolderFromService`, `NSSendFileTypes = ["public.folder"]`). `CFBundleShortVersionString` is the bundle version; the human-facing version is the hardcoded string in `SettingsView.aboutBlock` (currently "2.0"). |
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
