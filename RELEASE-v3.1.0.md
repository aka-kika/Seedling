# Seedling — Release Record · v3.1.0

> A keepsake record of the v3.1.0 release: the leaf finally opens like every other menu bar app — a left-click, a small menu, and a clean window again.

## What changed

macOS 27 stopped delivering right-clicks to menu bar status items, and 3.0.1 /
3.0.2 worked around that with a ctrl+click menu plus visible gear/power buttons
baked into the ceremony window. 3.1.0 drops the workarounds for the pattern every
other menu bar app already uses:

- **Left-click the leaf opens a menu** — `Open Seedling`, `Settings…`,
  `Quit Seedling`. No right-click, no ctrl-click; the gesture the OS can't eat
  *is* the menu now.
- **`Open Seedling`** is the first item and summons the centered ceremony (`⌥⌘S`
  still summons it in one gesture — shown as a hint in the menu when the hotkey
  is enabled).
- The menu is shown via `NSMenu.popUp` from the button's action, with the leaf
  highlighted while it tracks — the native pressed look. (The transient
  `statusItem.menu` + `performClick` path still shows nothing on macOS 27.)
- **A clean ceremony window** — the workaround gear and power glyphs are gone.
  It's just a seed in the dark again. `⌘,` and `⌘Q` still work app-wide through
  the standard App menu.

## Build & identity

| Field | Value |
|---|---|
| Version | **3.1.0** (build 4) |
| Bundle identifier | `com.seedling.app` |
| Minimum macOS | **26.0** (Tahoe) |
| Configuration | Release |
| Source commit | `4b0d2bc` |

## Code signing & notarization

> _Filled in after the signed + notarized Release build — same recipe as v3.0.x
> (Developer ID, hardened runtime, notarized + stapled)._

| Field | Value |
|---|---|
| Identity | **Developer ID Application: Veronica Loren (P5RB3W3D58)** |
| Hardened runtime | ✅ (`flags=runtime`, `get-task-allow` stripped) |
| Notary status | _pending_ |
| Submission ID | _pending_ |
| Ticket | _staple after notarization (`stapler validate`)_ |
| Gatekeeper | _verify `accepted · source=Notarized Developer ID`_ |

## Distribution

> _Fill the SHA-256 from the actual notarized DMG; the `latest/download` links in
> the README resolve once the v3.1.0 GitHub release is published with
> `Seedling-3.1.0.dmg` attached._

| Field | Value |
|---|---|
| Artifact | `Seedling-3.1.0.dmg` |
| Release | https://github.com/aka-kika/Seedling/releases/tag/v3.1.0 |
| Download | https://github.com/aka-kika/Seedling/releases/download/v3.1.0/Seedling-3.1.0.dmg |
| **SHA-256** | _pending — `shasum -a 256 Seedling-3.1.0.dmg`_ |

Built the same way as [v3.0](RELEASE-v3.0.md), [v3.0.1](RELEASE-v3.0.1.md), and
[v3.0.2](RELEASE-v3.0.2.md) — same recipe, same identity, same garden. 🌱
