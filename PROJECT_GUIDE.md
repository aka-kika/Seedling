# Seedling — plain guide

> **Quick start** — read through "How you run it", then stop if that is enough.
> **The rest** — optional depth when you want the full picture.

---

## In one minute

**Seedling** is a small macOS menu bar app (leaf icon, no normal app window) that drops starter markdown files into a folder you choose — README, AGENTS, and the usual project docs. You pick where projects live once ("your main path"), then seed new folders in a few clicks or from Finder. Version 2.0 is a **Liquid Glass** redesign for **macOS 26 Tahoe**; the active code is on branch `glass-redesign`, with `main` holding the older look.

**Learn:** A **menu bar app** lives in the top bar next to the clock; it usually has no Dock icon and no big main window.

---

## How you run it

1. **Requirements:** macOS 26 (Tahoe) or newer, Xcode 26 or newer.

2. **Open in Xcode:**

   ```bash
   cd /path/to/Seedling
   open Seedling.xcodeproj
   ```

   Press **⌘R** to build and run. The leaf appears in the menu bar.

3. **Or build from the terminal:**

   ```bash
   xcodebuild -project Seedling.xcodeproj -scheme Seedling -configuration Debug -derivedDataPath ./build build
   open build/Build/Products/Debug/Seedling.app
   ```

4. **First use:** Click the leaf → **Plant your first seed** → **Choose your path** (your usual projects folder). After that, click the leaf or press **⌥⌘S** → name the project → **Seed** (⌘↩).

5. **Reset all saved paths/settings (starts welcome again):**

   ```bash
   defaults delete com.seedling.app
   killall Seedling
   ```

6. **Engine smoke test (no UI):**

   ```bash
   swift scripts/smoke_test.swift
   ```

   You should see `All smoke tests passed ✅` at the end.

**Learn:** **Build** means compiling source into a runnable `.app`. **Scheme** in Xcode is the recipe (here: `Seedling`).

---

## The rest (optional)

### What you would use this for

Starting a new coding project folder with a consistent set of markdown files — README, agent instructions, contributing notes, license stub — without copying from an old project by hand. You can use built-in templates or point Seedling at your own folder of `.md` files.

### How it is organized (the map)

```
Seedling/
├── App/           # Menu bar, popover, hotkey, Finder service, HUD panel
├── Views/         # SwiftUI screens (popover, welcome, settings, animation)
├── Engine/        # Read templates and write files to disk
├── Models/        # Built-in seed files + saved user settings
├── Theme/         # Colors, glass UI components, small motion details
├── Resources/     # Info.plist, sandbox entitlements
├── scripts/       # smoke_test.swift (engine check)
├── docs/          # Design spec and implementation plan for v2.0
├── README.md      # Feature overview and shortcuts
└── HANDOFF.md     # Engineering deep-dive for developers
```

### Main pieces (the cast)

| Piece | Plain role |
|-------|------------|
| `App/AppDelegate.swift` | Menu bar icon, popover, right-click menu, global hotkey, Finder "Seed this folder" |
| `Views/MenuBarContent.swift` | Everything you see in the popover (welcome → seed → results) |
| `Engine/Seedling.swift` | Writes files; replaces `{{PROJECT_NAME}}` and `{{TAGLINE}}`; never overwrites existing files |
| `Models/SeedFile.swift` | Built-in templates + saved settings (paths, theme, hotkey) |
| `Views/SettingsView.swift` | Main path, custom templates folder, appearance, hotkey toggle |
| `Theme/*` | KIKA colors, glass buttons, small animations |
| `HANDOFF.md` | Deep engineering guide for the next developer |

### What technologies it uses (no buzzwords)

- **Swift** — Apple's language for Mac apps
- **SwiftUI** — declarative UI for the popover and settings
- **AppKit** — older Mac UI layer for the menu bar icon and popover shell
- **Sandbox** — the app only touches folders you explicitly pick; paths are remembered with secure bookmarks
- **macOS 26 Liquid Glass** — Apple's new translucent surface style on the popover and HUD

### Things that might confuse you

- **No Dock icon** most of the time — that's intentional (`LSUIElement`). Settings briefly shows in the Dock while open.
- **Settings** opens most reliably from right-click the leaf → **Settings…**, not only ⌘,.
- **Finder seeding** is under right-click folder → **Services** → **Seed this folder**, not the main context menu.
- **Leaf icon:** outline = default templates; filled = you set a custom templates folder.
- **Re-seeding** skips files that already exist — it will not overwrite your README.

### Safe next steps for you

1. Build and run once; complete the welcome flow and seed a test folder.
2. Run `swift scripts/smoke_test.swift` to confirm the file-writing engine.
3. Before changing behavior, skim `HANDOFF.md` (especially popover flow and sandbox bookmarks).

### If you want to go deeper later

- **HANDOFF.md** — architecture, gotchas, common tasks
- **docs/superpowers/specs/2026-06-01-seedling-glass-redesign-design.md** — v2.0 design decisions
- **docs/superpowers/plans/2026-06-01-seedling-glass-redesign.md** — task-by-task implementation plan
- **README.md** — shortcuts table and how to add a built-in seed file
