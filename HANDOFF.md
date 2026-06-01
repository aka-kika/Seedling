# Seedling — Engineering Handoff

> The README is for someone opening the project for the first time. This document is for the next developer who's going to **modify** Seedling.

---

## 1. What you're working with

**Seedling** is a small, focused, menu bar app. No main window. No document model. No navigation. No networking. The state surface is tiny — the hard parts are macOS integration and design discipline.

The whole app is **9 Swift files** plus an Xcode project:

| File | Lines | Purpose |
|---|---|---|
| `App/SeedlingApp.swift` | 42 | `@main`, `Settings` scene, App menu |
| `App/AppDelegate.swift` | 169 | `NSStatusItem` + `NSPopover` + right-click `NSMenu` |
| `Views/MenuBarContent.swift` | 411 | The popover body |
| `Views/SettingsView.swift` | 183 | Settings window (templates + appearance + about) |
| `Models/SeedFile.swift` | 468 | `SeedFile`, `SeedLibrary`, `ProjectOptions`, `AppSettings` |
| `Engine/Seedling.swift` | 91 | Template rendering + file writing |
| `Engine/TemplateLoader.swift` | 77 | Load user `.md` files from a folder |
| `Theme/KikaColors.swift` | 102 | Color tokens, spacing, fonts, `KikaTheme.resolve(scheme:)` |
| `Theme/KikaComponents.swift` | 166 | Reusable views: section header, row, divider, button styles |

(Line counts current as of the v1.6 docs pass; they may drift ±20 lines as the project evolves. The relative ordering — AppDelegate and MenuBarContent are the largest, KikaColors is the smallest — is stable.)

When in doubt, **read `MenuBarContent.swift` first** — it's the single source of truth for the popover's user-facing flow.

---

## 2. Architecture in 90 seconds

### The shape

```
                  NSStatusItem (the leaf icon in the menu bar)
                            │
            ┌───────────────┼───────────────┐
            │                               │
       left-click                       right-click
            │                               │
            ▼                               ▼
       ┌─────────┐                  ┌────────────┐
       │ NSPopover│                 │  NSMenu    │
       │ (SwiftUI)│                 │ About      │
       │          │                 │ Settings…  │
       │ empty /  │                 │ Quit       │
       │ filled   │                 └────────────┘
       └─────────┘
            │
            ▼
       MenuBarContent  (SwiftUI view, hosted in NSHostingController)
```

- **`AppDelegate`** owns the `NSStatusItem` and the `NSPopover`. It's the only place that touches AppKit.
- **`SeedlingApp`** is a thin SwiftUI shell that just wires the `AppDelegate` and declares the `Settings` scene.
- **`MenuBarContent`** is the popover body. It's a SwiftUI `View` — no AppKit needed in here.
- **`SettingsView`** is the Settings window content. Standard SwiftUI `Form { }`.

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

`MenuBarContent.body` is a 2-way branch:

| State | Trigger | What renders |
|---|---|---|
| **Empty hero** | `folderURL == nil` | Centered leaf + "Seed a new project" + "Choose Folder…" primary button |
| **Filled state** | `folderURL != nil` | Scrollable Project section + Source section + Result section (if any) + pinned action bar with Seed button + icon buttons |

The transition is driven by `MenuBarContent`'s local `@State folderURL`, which is set by `pickProjectFolder()` and reset by `resetForm()`. The `restoreLastSeed()` hook fires once per popover open to pre-fill from `AppSettings.lastFolderURL` / `lastProjectName` / `lastTagline`.

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

- The user must explicitly pick any folder we touch (templates folder, last-seeded folder). We can't poke at arbitrary paths.
- To survive across launches, every URL we persist must be a **security-scoped bookmark** (`URL.bookmarkData(options: [.withSecurityScope], ...)`).
- Before reading or writing a bookmarked URL, call `url.startAccessingSecurityScopedResource()`; after, call `url.stopAccessingSecurityScopedResource()`.

`AppSettings` handles this in three places:

- `init(...)` — resolves both bookmarks (templates + last-seeded) on launch.
- `setTemplatesFolder(from:)` — wraps the URL access in start/stop and stores a fresh bookmark.
- `recordSeed(folder:projectName:tagline:)` — same pattern for the destination.

`TemplateLoader.load(from:)` requires the caller to wrap it in start/stop. The popover does this in `filesToSeed`:

```swift
let started = settings.beginTemplatesAccess()
defer { if started { settings.endTemplatesAccess() } }
let loaded = TemplateLoader.load(from: url)
```

`AppSettings.beginTemplatesAccess() / endTemplatesAccess()` are thin wrappers that return a `Bool` indicating whether access was granted, so the caller can skip `endAccess` if the start failed.

**Gotcha:** If you ever add a third persistent URL (e.g. a "favorite destinations" list), you need a third bookmark key, a third resolve-on-init branch, and a third setter that wraps the access pattern. Don't reach for a more general abstraction until you have at least three — the explicit code is easier to debug.

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

This automatically:
- Wires `⌘,` to open it.
- Adds a `Settings…` item to the App menu.
- Wires it to the right-click menu's `Settings…` action.
- Prevents the user from resizing it (via `.windowResizability(.contentSize)`).

`SettingsView` is a `Form { }` with three sections: Templates folder, Appearance, About. The templates hero is a custom card (not a `Form` row) because it needs an elevated background and inline path display — `Form` rows can't do that.

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

There's no first-run experience anymore. If you want to test the empty hero, just kill Seedling and clear the last-folder bookmark:

```bash
defaults delete com.seedling.app seedling.lastFolderBookmark
```

---

## 10. Design system rules

Seedling is built on the KIKA Design System v2. The hard rules:

- **No hardcoded colors at call sites.** Always go through `KikaTheme.resolve(scheme: colorScheme)` and read tokens from the resolved `KikaTheme`. The `KikaColors` enum exists for *token definition*, not for direct use.
- **No custom fonts.** `Font.system(size:weight:)` only, via `KikaFont.title / body / caption`.
- **No drop shadows.** Use `RoundedRectangle().fill(surface)` or `.regularMaterial` to imply elevation.
- **No multi-color palettes.** Accent is `KikaColors.accentDark` / `accentLight` — the only accent in the app.
- **One primary action per view.** Don't stack two `KikaPrimaryButtonStyle` buttons side-by-side.
- **SF Symbols only.** `Image(systemName: ...)` and `Label`. No custom icon assets.
- **Three gap values: 12, 16, 20.** `KikaSpacing.sm / md / lg`. Don't introduce arbitrary `padding(8)`.
- **No subtitles.** If a label and a description feel needed, rewrite the description as the label.

The popover's action bar is the place to look at the design system working: one primary action (Seed) + two icon-only secondaries, a single divider above, three gap values used throughout.

If you're ever tempted to add a "feature" that violates these (e.g. a colored icon background, a 6th placeholder color, a custom font), stop and ask: is this consistent with the rest of the app, or does it make Seedling look like a different app?

---

## 11. Apple HIG compliance

Seedling was audited against the Apple HIG for macOS (loaded from `~/Documents/OPENSKILLZ/apple-hig-swiftui-macos`). Compliance highlights:

- **Menu bar app pattern** — `LSUIElement = true`, no Dock icon, no main window, `NSStatusItem` owns the entry point.
- **Standard App menu** — `CommandGroup(replacing: .appInfo)` for About. The `Settings` scene automatically wires Settings (`⌘,`) and Quit (`⌘Q`).
- **Settings via `Settings { }` scene** — not a sheet, not a custom window. Standard `Form { }` inside.
- **Settings `.windowResizability(.contentSize)`** — settings windows shouldn't be user-resizable.
- **Floating panel uses `.regularMaterial`** — the popover picks up desktop vibrancy.
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
| `Seedling.xcodeproj/project.pbxproj` | Hand-maintained. Adding a new Swift file requires: (1) `PBXBuildFile` entry, (2) `PBXFileReference` entry, (3) entry in the appropriate `PBXGroup` (App / Engine / Models / Resources / Theme / Views), (4) entry in `PBXSourcesBuildPhase`. Use unique 24-character hex IDs — `A1000001000000000000XXXX` for `PBXBuildFile`, `A1000002000000000000XXXX` for `PBXFileReference`. |
| `Seedling/Resources/Info.plist` | `LSUIElement = true` is the only thing that makes this a menu bar app. `CFBundleShortVersionString` is the version shown in About. |
| `Seedling/Resources/Seedling.entitlements` | Sandbox + user-selected files + bookmarks. Removing any of these will break the app. |
| `Seedling.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Auto-generated by Xcode. Don't hand-edit. |
| `Seedling.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Build system + preview settings. |
| `scripts/smoke_test.swift` | Engine test, not a runnable script in its current form. |

---

## 16. What to do when you don't know where to put something

- **UI logic** → `Views/`
- **Persistent user state** → `Models/SeedFile.swift` (the `AppSettings` class)
- **Pure file I/O** → `Engine/`
- **AppKit / system integration** → `App/AppDelegate.swift`
- **Reusable visual component** → `Theme/KikaComponents.swift`
- **Color / font / spacing token** → `Theme/KikaColors.swift`
- **A new built-in markdown file** → `Models/SeedFile.swift`'s `SeedLibrary.files`

If it doesn't fit any of those, you're probably designing a new feature, not just adding to an existing one. Stop, sketch the UX, then come back.
