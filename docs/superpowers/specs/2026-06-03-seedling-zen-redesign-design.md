# Seedling — Zen Ceremony Redesign (v3.0)

> **Status:** Approved design, ready for implementation planning.
> **Date:** 2026-06-03
> **Supersedes:** the menu-bar **popover** flow described in `2026-06-01-seedling-glass-redesign-design.md` and HANDOFF §3. Those remain valid as the v2.0 archive; this document is the new source of truth for the user-facing flow. Engine, sandbox/bookmark, and KIKA design-system sections of v2.0 carry forward unchanged unless noted here.

---

## 1. Intent

Seedling stamps a chosen set of `.md` files (`AGENTS.md`, `CLAUDE.md`, `README`, `TODO`, `SECURITY`, …) into a new project folder. The engine is trivial and already solid (never-overwrite, smoke-tested). **The product is the *experience*, not the pipeline.**

The goal of v3.0 is to make starting a project feel like a small, personal ceremony — *a new beginning, a new life.* The metaphor is literal, not decorative: the `.md` files **are** the project's DNA (its rules and guidelines), so "planting seeds and watching them grow into a project" is an honest depiction of what the software does.

**Design north star:** intimate, calm, "a moment" — closer to lighting a candle than filling in a form.

---

## 2. The experience (the whole moment)

One **intimate window, centered on screen**, summoned by the menu-bar leaf or `⌥⌘S`. Modest size — personal, not cinematic. Liquid Glass surface, dark, mostly empty space around a seed. Three beats of the **same** window:

| Beat | What the user sees | What happens |
|---|---|---|
| **1 · At rest** | A seed breathing softly in the dark. One field: *"name your project."* A faint line: *planting in ~/Projects*. A hint: *⏎ to grow*. | Window has faded in centered and taken keyboard focus. Cursor is in the name field. |
| **2 · Grows** | User types `aurora`. The destination line updates live to *~/Projects/aurora*. On `⏎`, the line-art seed **draws itself** — stem, then leaves, stroke by stroke. | The subfolder is created and the seeds are written (background I/O), while the growth animation plays. |
| **3 · Alive** | One **breath of light** (a soft bloom) as the line completes. *"aurora is alive · 5 seeds planted · revealing…"* | The new folder is revealed in the user's **default file manager**, then the window **fades away on its own**. Nothing lingers. |

**Reduce-motion:** snap to the final frame, no animation (existing behavior, preserved).

### Resolved decisions (from brainstorming)

1. **Container:** centered intimate window (not the menu-bar popover, not full-screen). Menu-bar leaf + `⌥⌘S` are the triggers; the window itself is center-screen.
2. **Flow shape:** Zen — minimal UI, the seed and dark space, one field, a soft action. Nothing may break the calm.
3. **Destination model — "Projects home":** the user sets a parent folder once (e.g. `~/Projects`). Each seed = type a name → Seedling creates `ProjectsHome/<name>` and plants the seeds inside it. **No folder picker per seed.** The typed name births the folder.
4. **Window input — name only:** a single field. The name births the folder **and** fills `{{PROJECT_NAME}}`. Tagline is dropped from the flow; `{{TAGLINE}}` expands to empty.
5. **Animation:** line-art that draws itself, completing with one soft bloom of light (line-art discipline + a single moment of magic).
6. **After growth:** brief rest on the final frame → reveal the new folder in the **system default folder handler** (not hard-coded Finder) → fade the window out.
7. **Collision (folder already exists):** plant into it anyway, **never overwriting** existing files (preserves the engine's safety property), with a whisper of acknowledgment rather than an error. Result copy reflects new vs. already-present seeds.

---

## 3. What changes vs. v2.0

### Removed / replaced
- **`NSPopover` anchored to the status item → gone.** Replaced by a centered ceremony **window** (`NSPanel`).
- **Per-seed folder picker (`NSOpenPanel` for the destination) → gone** from the main flow. Destination is derived from Projects home + typed name. (The picker survives only in Settings, for choosing Projects home and the seed library once.)
- **Tagline field and `lastTagline` → removed** from the flow. `{{TAGLINE}}` still substitutes (to empty) so existing templates don't break.

### Added
- **`projectsHomeURL`** — a fourth security-scoped bookmark in `AppSettings` for the Projects home. (Per HANDOFF §5's own prediction, a *fourth* bookmark is the trigger to extract a small `BookmarkedFolder` helper — see §6.)
- **Centered ceremony window** owned by a controller in `App/` (generalizes the existing `SeedHUDPanel` pattern, which is already a borderless centered `NSPanel`).
- **`SeedCeremonyView`** — the SwiftUI zen body (rest / growing / alive states), replacing `MenuBarContent` as the primary surface.
- **New-project creation step** — sanitize name → create `ProjectsHome/<name>` → seed into it.
- **"Open in default file manager"** on completion via `NSWorkspace.open(_:)` (respects a user-set default folder handler) rather than `activateFileViewerSelecting` (which forces Finder).

### Unchanged (carried forward from v2.0)
- The **engine** (`Engine/Seedling.swift`): render + never-overwrite seed. One small addition (§5).
- **Sandbox + security-scoped bookmarks** model (HANDOFF §5).
- **KIKA design system v2** rules (one sage accent, hairlines, no drop shadows, Liquid Glass, SF Symbols, 12/16/20 spacing) — HANDOFF §10.
- The **menu-bar status item** (leaf icon, left-click opens the window, right-click `NSMenu` with About / Settings… / Quit) — HANDOFF §6.
- The **Finder Service** ("Seed this folder") + `SeedHUD` confirmation — kept as a power-user **side door** (HANDOFF §6). It seeds an *existing* folder in place, so it does not use the Projects-home model; it can reuse the new growth view for its HUD.
- The **`Settings` scene** and accessory-app opening dance (HANDOFF §6/§7).
- **Global hotkey** `⌥⌘S` via Carbon (HANDOFF §6) — now summons the centered window instead of the popover.

---

## 4. Components & responsibilities

Designed so each unit has one purpose and a clear interface.

| Unit | File (new/changed) | Responsibility | Depends on |
|---|---|---|---|
| **CeremonyWindow** (controller + `NSPanel`) | `App/` (new, e.g. `CeremonyWindowController.swift`; may absorb/generalize `SeedHUDPanel.swift`) | Own the borderless, centered, glass `NSPanel`. Fade in, center on the active screen, take key focus, fade out. Dismiss on `Esc` / outside click. | AppKit, `SeedCeremonyView` |
| **SeedCeremonyView** | `Views/SeedCeremonyView.swift` (new; replaces `MenuBarContent.swift`'s role) | The zen body. Drives the rest → growing → alive state machine. Owns the name `@State`, the live destination string, and calls the seed action. Pure SwiftUI. | `SeedGrowthView`, `AppSettings`, `ProjectSeeder` |
| **SeedGrowthView** | `Views/SeedGrowthView.swift` (evolve) | Line-art growth driven by `progress`; ends in a soft bloom of light. Honors reduce-motion. Add/confirm a `.ceremony` mode + bloom completion. | SwiftUI only |
| **ProjectSeeder** | `Engine/` (new small helper) | Given Projects home, a name, and the seed files: sanitize the name, create `home/<name>` (security-scoped), seed into it, return a `SeedResult` + the new folder URL. Never overwrites. | `Seedling`, `FileManager` |
| **AppSettings** | `Models/SeedFile.swift` (change) | Add `projectsHomeURL` bookmark; remove tagline state; keep templates/library + appearance + hotkey. | bookmarks |
| **BookmarkedFolder** | `Models/` (new small helper) | Collapse the now-4 near-identical bookmark blocks (resolve-on-init + start/stop setter) into one reusable type. | sandbox bookmark API |
| **AppDelegate** | `App/AppDelegate.swift` (change) | Status item left-click + `⌥⌘S` → summon CeremonyWindow (was: toggle popover). Right-click menu, Services provider, Settings opening unchanged. | CeremonyWindow, GlobalHotKey |
| **SettingsView** | `Views/SettingsView.swift` (change) | Set **Projects home** + **Seed library** + appearance + hotkey + about. Copy updated for the new model. | AppSettings |

---

## 5. Data flow

```
⌥⌘S / leaf left-click
        │  NSApp.activate(ignoringOtherApps:)   (accessory-app gotcha)
        ▼
CeremonyWindowController.summon()
   fade in centered NSPanel → makeKey → focus name field
        │
        ▼
SeedCeremonyView (.rest)
   user types name ──► live destination = projectsHome/<sanitized name>
        │  Return (primary) — or tap the seed glyph (equivalent); name non-empty
        ▼
SeedCeremonyView (.growing)  ── plays SeedGrowthView ──┐
        │                                              │ (concurrently, background queue)
        ▼                                              ▼
ProjectSeeder.seed(name:, home:)            create dir + Seedling.seed(...)
   → SeedResult(created, skipped, folderURL)           │
        │◄─────────────────────────────────────────────┘
        ▼
SeedCeremonyView (.alive)
   bloom completes → "<name> is alive · N seeds planted · revealing…"
   → NSWorkspace.open(folderURL)            (default file manager)
   → AccessibilityNotification.Announcement (result headline)
   → CeremonyWindowController.dismiss()  (fade out after a short beat)
```

**Persisted state after a seed:** Projects home and seed library are the only durable settings. We do **not** pre-fill the name on next open (each ceremony starts fresh from the resting seed). `lastProjectName` / `lastFolderURL` / `lastTagline` are retired (or left dormant) — the zen flow re-derives nothing per-open except the resting state.

---

## 6. Error handling & edge cases

| Case | Behavior |
|---|---|
| **Empty name**, user hits `⏎` | Nothing grows. The resting hint gives a gentle nudge (e.g. a soft shake of the field / hint stays). No modal, no red. |
| **Name with path separators / illegal chars** | Sanitize to a filesystem-safe folder name (strip `/`, leading dots, control chars; collapse whitespace). The live destination line shows the sanitized result so there's no surprise. |
| **Projects home not set** (first run) | Onboarding beat in the same window: a calm prompt to choose where projects live (and to point at the seed library). Only place a folder picker appears. After setup, the resting seed. |
| **Subfolder already exists** | Plant into it; never overwrite. Whisper acknowledgment; completion copy reflects *N planted · M already there*. |
| **Seed library unset/empty** | Fall back to the built-in default seed set (existing `resolveSeedFiles()` behavior). |
| **Folder not writable / creation fails** | Quiet inline failure in the window (no crash, no Finder of a folder that wasn't made). Surface a short message; do not fade out as if successful. |
| **Window summoned while already open** | Re-center / bring to front + focus; don't stack panels. |
| **Reduce-motion** | Final frame only; copy and reveal still happen. |

---

## 7. First-run / onboarding

Two things must exist before the resting seed makes sense: a **Projects home** and a **seed library** (the library can fall back to built-ins, so it's optional; Projects home is required for the "births a folder" model).

- If **Projects home is unset**, the window opens to a single calm onboarding beat: *"Where do your projects grow?"* → one folder pick → done, then dissolve into the resting seed. Keep it to one decision; the seed library can be configured later in Settings (built-ins cover the default).
- Tone matches the ceremony — not a multi-step wizard. (This replaces the v2.0 `WelcomeView`, which was gated on `mainPathURL == nil`.)

---

## 8. Visual & motion spec

- **Window:** centered on the key/active screen, modest width (~280–320pt), glass surface (`.glassEffect`), generous dark negative space, corner radius consistent with KIKA. Fade-in ~200ms; fade-out ~300ms after the alive beat holds ~1s.
- **Resting seed:** a single sage dot with a slow "breathe" (subtle opacity + 1–2pt vertical drift, ~3.4s loop).
- **Name field:** one hairline-underlined field (reuse the focus-underline microinteraction), placeholder *name your project*; the destination line below updates live.
- **Growth:** line-art draws itself (stem → leaves) over ~1.6–2.2s with the existing `progress`-driven `path(in:)` approach; **completes with a soft bloom** — a brief luminous swell at the growth tip (one breath, then settle). One accent only; the bloom is a lighter sage tint of the same accent, not a new color.
- **Alive copy:** *"<name> is alive"* + *"N seeds planted · revealing…"* in caption ink.
- **KIKA rules hold:** one sage accent, hairlines, no drop shadows (glow on the bloom is light, not a shadow), SF Symbols only, 12/16/20 spacing.

---

## 9. Testing

- **Engine smoke test (extend `scripts/smoke_test.swift`):** add coverage for `ProjectSeeder` — creating `home/<name>`, seeding into it, never-overwrite on re-seed of the same name, and name sanitization. Keep the existing six assertions. The script remains the inlined spec (mirror any `Seedling`/`SeedFile`/`ProjectSeeder` change here).
- **Clean build:** `xcodebuild … build` with the HANDOFF §8 warning filter must stay empty.
- **Manual QA (new):** window centers on the active screen; takes keyboard focus (type immediately without clicking); `⏎` grows; reveal opens the new folder in the default file manager; window fades out; `Esc` and outside-click dismiss the resting window; reduce-motion snaps to final frame; collision plants without overwriting; first-run onboarding sets Projects home; Finder "Seed this folder" side door still works via `NSPerformService`.

---

## 10. Out of scope (YAGNI)

- Multi-select / batch project creation.
- Per-file seed toggles in the window (the library is wholesale; manage it in the folder).
- A tagline field or any second input in the ceremony.
- A hotkey recorder (the `⌥⌘S` toggle stays as-is).
- Templating beyond `{{PROJECT_NAME}}` / `{{TAGLINE}}` (tagline now expands empty).
- Choosing the file manager inside the app (we just respect the OS default).

---

## 11. Migration notes

- The popover (`MenuBarContent.swift`) is retired as the primary surface; its validated logic (restore/seed/announce) moves into `SeedCeremonyView` + `ProjectSeeder`.
- `project.pbxproj` is hand-maintained — new files (`CeremonyWindowController`, `SeedCeremonyView`, `ProjectSeeder`, `BookmarkedFolder`) need the four-entry dance (HANDOFF §15); next hex suffix is `A011`.
- `docs/superpowers/*` for the glass redesign and any popover references become **archive** once this ships; update HANDOFF §3 to describe the ceremony window.
```
