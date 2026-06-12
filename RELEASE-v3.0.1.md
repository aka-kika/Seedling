# Seedling — Release Record · v3.0.1

> A keepsake record of the v3.0.1 release: a small fix so Settings stays reachable on macOS 27.

## What changed

macOS 27 (first beta, `26A5353q`) stopped delivering right-clicks to menu bar status items — the click is swallowed by the system's `MenuBarAgent` before any app sees it. The leaf's right-click menu (Settings… / Quit) silently went dark. Verified with instrumented probe apps: left events arrive, right events never do, and `button.menu` never fires either.

So Seedling no longer depends on right-clicks:

- **ctrl+click the leaf** opens the Settings/Quit menu — it arrives as a left-click with the control flag, which the OS can't eat. Plain right-click still works on macOS versions that deliver it.
- The menu is shown via `NSMenu.popUp` anchored to the leaf; the old transient `statusItem.menu` + `performClick` re-dispatch shows nothing on macOS 27.
- A quiet **gear in the ceremony window's corner** (and `⌘,` while it's up) — an always-reachable door to Settings, whatever the OS does to clicks.

## Build & identity

| Field | Value |
|---|---|
| Version | **3.0.1** (build 2) |
| Bundle identifier | `com.seedling.app` |
| Minimum macOS | **26.0** (Tahoe) |
| Configuration | Release |
| Source commit | `ffd48f1` |

## Code signing & notarization

| Field | Value |
|---|---|
| Identity | **Developer ID Application: Veronica Loren (P5RB3W3D58)** |
| Hardened runtime | ✅ (`flags=runtime`, `get-task-allow` stripped) |
| Notary status | **Accepted** ✅ |
| Submission ID | `2c531ea7-a702-4087-b8ec-e9c7bcb98f36` |
| Ticket | stapled to the DMG (`stapler validate` ✓) |
| Gatekeeper | `accepted · source=Notarized Developer ID` |

## Distribution

| Field | Value |
|---|---|
| Artifact | `Seedling-3.0.1.dmg` (≈2.9 MB) |
| Release | https://github.com/aka-kika/Seedling/releases/tag/v3.0.1 |
| Download | https://github.com/aka-kika/Seedling/releases/download/v3.0.1/Seedling-3.0.1.dmg |
| **SHA-256** | `73a01735c75416a8ff6f1c3041665833e90069d43c299d4a086117d60b242c52` |

Built the same way as [v3.0](RELEASE-v3.0.md) — same recipe, same identity, same garden. 🌱
