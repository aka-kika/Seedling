# Seedling

A calm, premium macOS menu bar app for **seeding new projects with the right markdown files**.

Pick a folder, fill in a name, hit **Seed**. Seedling writes the standard set — README, AGENTS, COMMANDS, CONTRIBUTING, LICENSE — and skips any that already exist. Point it at your own templates folder to use your own markdown files instead of the built-in ones.

Built on the **KIKA Design System v2** with Apple's **Liquid Glass**: dark-first, restrained, a pastel sage accent, and excellent light mode. Audited against the Apple Human Interface Guidelines for macOS.

---

## What it does

| Workflow | What you do |
|---|---|
| **First time** | Click the leaf → *Plant your first seed* → **Choose your path** (your main folder) → it grows |
| **Next time** | Click the leaf (or `⌥⌘S` from anywhere) → your main path is ready → hit `⌘↩` |
| **From Finder** | Right-click any folder → Services → **Seed this folder** |
| **Change main path / templates** | Right-click the leaf → Settings… → Main path / Templates folder |
| **Light / dark mode** | Right-click the leaf → Settings… → Appearance |
| **Quit** | Right-click the leaf → Quit Seedling (`⌘Q`) |

When you click **Seed**, Seedling writes the default set (5 built-in files) — or the markdown files in your templates folder, if you've set one. Existing files are skipped, never overwritten. The result list shows what was created; click any file to reveal it in Finder.

---

## Requirements

- **macOS 26 Tahoe** or later (required for Liquid Glass)
- **Xcode 26** or later (for building from source)
- **Swift 5.9+**

---

## Build & run

```bash
cd Seedling
open Seedling.xcodeproj
```

Press `⌘R` to build and run. The leaf icon appears in your menu bar.

From the command line:

```bash
xcodebuild -project Seedling.xcodeproj -scheme Seedling -configuration Debug build
open build/Build/Products/Debug/Seedling.app
```

To reset all settings (templates folder, last-seed memory, theme):

```bash
defaults delete com.seedling.app
```

---

## Keyboard shortcuts

| Action | Shortcut | Where |
|---|---|---|
| Pick a folder | `⌘O` | Popover (empty + filled state) |
| Seed | `⌘↩` | Popover (filled state) |
| Close the popover | `Esc` | Popover (anywhere) |
| Settings | `⌘,` | From the menu bar (right-click → Settings…) |
| Quit | `⌘Q` | From the menu bar (right-click → Quit) |

---

## Project layout

```
Seedling/
├── App/
│   ├── SeedlingApp.swift          # @main, scenes, App menu
│   └── AppDelegate.swift          # NSStatusItem, NSPopover, right-click NSMenu
├── Theme/
│   ├── KikaColors.swift           # tokens, KikaTheme.resolve(scheme:), Color(hex:)
│   └── KikaComponents.swift       # KikaSectionHeader, KikaRow, KikaDivider, button styles
├── Models/
│   └── SeedFile.swift             # SeedFile, SeedLibrary, ProjectOptions, AppSettings
├── Engine/
│   ├── Seedling.swift             # template rendering + file writing
│   └── TemplateLoader.swift       # load user .md files from a folder
├── Views/
│   ├── MenuBarContent.swift       # the popover body (project / source / seed / result)
│   └── SettingsView.swift         # Settings window (templates + appearance + about)
├── Resources/
│   ├── Info.plist                 # LSUIElement = YES (menu bar app)
│   └── Seedling.entitlements      # sandbox + user-selected files + bookmarks
└── scripts/
    └── smoke_test.swift           # end-to-end engine test
```

---

## Adding a built-in seed file

Open `Seedling/Models/SeedFile.swift` and append a new `SeedFile(...)` to `SeedLibrary.files`. Set `defaultEnabled: true` if you want it to be part of the default seed set.

```swift
SeedFile(
    id: "support",
    name: "SUPPORT.md",
    icon: "questionmark.bubble",
    description: "Where to ask questions",
    category: .community,
    content: """
    # Support

    - Slack: TODO
    - Discussions: TODO
    """,
    defaultEnabled: false,
    source: .builtIn
)
```

`Category` is a grouping (`overview`, `ai`, `workflow`, `community`, `meta`) reserved for future UI. The popover doesn't surface categories today — files are written as a flat set.

---

## License

© 2026 Seedling. All rights reserved.

---

## See also

- **[HANDOFF.md](./HANDOFF.md)** — Architecture deep-dive, sandbox model, run-from-build commands, common tasks, and gotchas for the next developer picking this up.
- **KIKA Design System** — `~/.agents/skills/kika-design-system/`
- **Apple HIG (macOS, SwiftUI)** — `~/Documents/OPENSKILLZ/apple-hig-swiftui-macos/`
