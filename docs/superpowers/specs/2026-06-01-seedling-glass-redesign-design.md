# Seedling — Liquid Glass Redesign, First-Run Flow & Settings Fix

**Date:** 2026-06-01
**Status:** Approved (brainstorming) — ready for implementation plan

---

## Context

Seedling is a finished, polished menu-bar app (KIKA Design System v2, dark-first,
`.regularMaterial` surfaces, slate-blue accent). It already has: the seed engine,
a global ⌥⌘S hotkey, a Finder "Seed this folder" Service, and a line-art
seed-growth animation.

The user wants the app to evolve in five connected directions, all surfaced through
the menu bar:

1. A **first-run welcome** that frames the default-folder choice as the start of a
   story ("Plant your first seed → Choose your path → …and let it grow").
2. **Settings that actually open** (currently broken) — kept as a separate window.
3. A **pastel sage-teal accent** replacing the slate-blue.
4. **Smaller, higher-end typography and controls.**
5. **Apple's Liquid Glass** design language (macOS 26), plus more line animation and
   microinteractions.

The whole app is small (now ~12 Swift files). This is an evolution of the existing
surfaces, not a rewrite. The KIKA discipline carries over (one accent, hairlines, no
drop shadows, SF Symbols) — Liquid Glass *replaces* `.regularMaterial` as the surface
treatment.

## Locked decisions (from brainstorming)

| Topic | Decision |
|---|---|
| First-run | **Path only.** Welcome screen → pick the default destination folder ("your main path") → seed screen. Seed source stays built-in, editable in Settings. |
| Settings | **Keep the separate macOS Settings window; fix why it won't open.** |
| Liquid Glass | **Bump deployment target to macOS 26**, adopt native Liquid Glass (no availability guards / fallback path). |
| Accent | **Pastel Sage `#97CEC2` (dark)**, derived light twin **`#4F9E8E`**. Replaces slate-blue everywhere. |
| Type & controls | **Smaller, quieter.** Title 18→15, body 13→12, caption 11→10.5; tighter button padding; thinner icon strokes; hairline dividers. |
| Animation | Refine the seed-growth line art; add microinteractions (see §7). |
| Welcome copy | "Plant your first seed" (title) → **[ Choose your path ]** (button) → "…and let it grow" (soft italic payoff) → "⌥⌘S to summon from anywhere" (hint). Quiet title case, not all-caps. |

---

## Design

### 1. Deployment target → macOS 26

`MACOSX_DEPLOYMENT_TARGET = 14.0` → `26.0` in both Debug/Release build configs of
`project.pbxproj`. `LSMinimumSystemVersion` in `Info.plist` → `26.0`. About-panel and
README copy noting "macOS 14+" updated to "macOS 26+". This unblocks unguarded use of
Liquid Glass APIs.

### 2. Liquid Glass adoption

Confirmed APIs (Apple docs, macOS 26): `View.glassEffect(_:in:isEnabled:)`,
`GlassEffectContainer`, `.buttonStyle(.glass)` / `.glassProminent` / `.glass(.clear)`.

- **Popover surface** (`MenuBarContent.background`): replace `.background(.regularMaterial)`
  with a Liquid Glass surface. Wrap the popover content in a `GlassEffectContainer` so
  multiple glass elements blend correctly, and apply `.glassEffect(in: rounded rect)` to
  the container.
- **HUD panel** (`SeedHUDPanel`): the rounded card swaps `.regularMaterial` for
  `.glassEffect(in: RoundedRectangle(cornerRadius: 20))`.
- **Buttons**: `KikaPrimaryButtonStyle` (the Seed / Choose-your-path button) is
  re-expressed on top of `.buttonStyle(.glassProminent)` tinted with the accent.
  Secondary icon buttons use `.buttonStyle(.glass)`. We keep the Kika*ButtonStyle type
  names as thin wrappers so call sites don't churn and the "one primary action" rule
  still reads in code.
- **No drop shadows** rule still holds — glass provides depth. Settings window keeps a
  standard `Form`/`.grouped` look (system already gives it Liquid Glass chrome on 26).

### 3. Accent color

In `Theme/KikaColors.swift`:
- `accentDark = Color(hex: 0x97CEC2)`, `accentLight = Color(hex: 0x4F9E8E)`.
- Audit usages: pastel accent on dark glass is light, so **button label text on the
  prominent accent button switches to a dark ink** (`~#0C1A17`) instead of white, for
  legibility (a deliberate high-end detail). Light mode keeps light text on the deeper
  `#4F9E8E`. This lives in the primary button style, the single place label color is set.
- Everything else (leaf icon, section accents, growth animation stroke, result
  checkmark) inherits `theme.accent` automatically — no call-site changes.

### 4. Typography & control sizing

In `Theme/KikaColors.swift` (`KikaFont`):
- `title` 18→15 semibold · `body` 13→12 · `caption` 11→10.5.
- Add nothing new; just retune the three tokens (they propagate everywhere).

In `Theme/KikaComponents.swift` (button styles) + view call sites:
- Primary button vertical padding reduced; corner radius retuned to glass (≈12).
- Icon-only buttons: 30×30 (from larger), icon stroke/weight lighter.
- Hairline dividers already exist (`KikaDivider`); confirm 1px at low opacity.

### 5. First-run welcome flow ("your main path")

**Concept:** the persisted default destination becomes "your main path." A new
`AppSettings.mainPathURL` (security-scoped bookmark, same pattern as `lastFolderURL`)
holds it. `hasCompletedFirstRun` is derived as `mainPathURL != nil`.

**Popover states** (`MenuBarContent`) become a 3-way branch:
- **Welcome** (`mainPathURL == nil`): centered leaf → "Plant your first seed" →
  **[ Choose your path ]** glass button → "…and let it grow" (italic) → ⌥⌘S hint.
  Choosing a folder: persists it as `mainPathURL`, plays the existing `.birth`
  animation, transitions to the seed screen.
- **Seed screen** (`mainPathURL != nil`): today's filled state, pre-filled with the
  main path as the destination and the folder name as the project name. "Change folder"
  still lets you target a different folder for a one-off seed without changing the main
  path; a small control sets the current folder as the new main path.
- The current empty-hero is replaced by the Welcome state; `restoreLastSeed()` is
  reframed to restore from `mainPathURL` first.

**Reuse:** the birth animation, `applyFolder`, and `recordSeed` already exist; this
re-points them at `mainPathURL`. Copy lives in the Welcome view only.

### 6. Settings window — fix the open bug

**Requirement:** ⌘, and right-click → Settings… reliably open the Settings window and
bring it to the front, every time, for this `LSUIElement` (accessory) app.

**Likely cause (to confirm via systematic-debugging):** accessory-policy apps don't
reliably surface the SwiftUI `Settings` scene via
`NSApp.sendAction(Selector(("showSettingsWindow:")))` — timing vs `NSApp.activate`,
and/or the selector behavior on macOS 26. Candidate fixes, in order of preference:
1. `NSApp.activate(ignoringOtherApps:)` **then** send `showSettingsWindow:` on the next
   run-loop tick (ordering fix).
2. Use the SwiftUI `@Environment(\.openSettings)` action from a hosted control instead
   of the AppKit selector.
3. Temporarily set `NSApp.setActivationPolicy(.regular)` to allow the window to front,
   restoring `.accessory` on close — only if 1–2 fail.

The seed-source and main-path controls live in this window (so "change later in
Settings" works); both already have the bookmark plumbing.

### 7. Animation & microinteractions

- **Seed-growth line art** (`SeedGrowthView`): refine curve/leaf geometry and timing for
  the smaller, glassier context; thinner stroke to match the lighter UI.
- **Microinteractions** (small, tasteful, reduce-motion-aware):
  - Primary button press "give" (subtle scale-down on press).
  - An accent hairline that draws in under a text field on focus (trim animation).
  - The leaf doing a one-stroke flourish on summon / hover.
  - Seed-screen rows fade-rise in sequence when the screen appears.
- All honor `@Environment(\.accessibilityReduceMotion)` (static fallback), consistent
  with `SeedGrowthView` today.

---

## Files affected

**Modified:**
- `Seedling.xcodeproj/project.pbxproj` — deployment target 26.
- `Seedling/Resources/Info.plist` — `LSMinimumSystemVersion` 26.
- `Seedling/Theme/KikaColors.swift` — accent tokens, font sizes.
- `Seedling/Theme/KikaComponents.swift` — glass button styles, sizing, focus underline.
- `Seedling/Views/MenuBarContent.swift` — 3-way branch, welcome state, glass surface,
  microinteractions.
- `Seedling/Views/SettingsView.swift` — seed-source + main-path controls; glass.
- `Seedling/App/AppDelegate.swift` — Settings-open fix; popover glass sizing if needed.
- `Seedling/App/SeedHUDPanel.swift` — glass surface.
- `Seedling/Models/SeedFile.swift` — `AppSettings.mainPathURL` (+ bookmark plumbing).
- `Seedling/Views/SeedGrowthView.swift` — refined geometry/timing.
- `README.md` / About copy — macOS 26, new accent/flow notes.

**New (likely):**
- `Seedling/Views/WelcomeView.swift` — the first-run welcome (keeps MenuBarContent focused).
- Possibly `Seedling/Theme/Microinteractions.swift` — shared press/focus modifiers.

(New Swift files require the 4 pbxproj entries per HANDOFF.md §15.)

---

## Verification

1. **Clean build** on macOS 26 SDK; warnings-only grep is empty.
2. **Engine smoke test** still green (`swift scripts/smoke_test.swift`) — engine untouched.
3. **First run:** with settings reset (`defaults delete com.seedling.app`), the welcome
   copy + glass appear; choosing a folder plays `.birth`, persists the main path, and
   reveals the seed screen. Relaunch → goes straight to the seed screen.
4. **Settings:** ⌘, and right-click → Settings… both open and front the window reliably,
   repeatedly. Seed source + main path are editable there and persist across launches.
5. **Glass + accent:** popover, HUD, and buttons show Liquid Glass; pastel sage accent
   everywhere; button ink legible in both light and dark.
6. **Service path** still seeds (drive via `NSPerformService`, as before).
7. **Reduce Motion:** all animations render a static final frame.
8. **Visual pass:** launch the real app and confirm against the approved mockup.

## Out of scope (deliberately)

- No inline-in-popover Settings (kept as a window, per decision).
- No custom hotkey recorder; no auto-detection of frontmost folder.
- No macOS < 26 support / fallback styling.
- No change to the seed engine or never-overwrite property.
