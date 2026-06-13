# Seedling — Release Record · v3.0.2

> A keepsake record of the v3.0.2 release: a visible way to quit, since macOS 27 hid the old one.

## What changed

The v3.0.1 fix made **Settings** reachable after macOS 27 stopped delivering
right-clicks to menu bar status items — but **Quit** lived in that same dead
right-click menu, so there was still no visible way to quit the app. 3.0.2 adds
Quit to two right-click-free places:

- **Ceremony window** — a quiet `power` glyph in the bottom-leading corner,
  mirroring the Settings gear in the opposite corner. Subtle (hover-brightens),
  and set apart from the name field so it isn't hit mid-naming. `⌘Q` works too.
- **Settings → About** — a "Quit Seedling" button below the copyright.

Also fixed: the About version string was hardcoded to a stale "3.0 (build 1)".
It now reads `CFBundleShortVersionString` / `CFBundleVersion` live from the
bundle, so it can never drift from Info.plist again.

## Build & identity

| Field | Value |
|---|---|
| Version | **3.0.2** (build 3) |
| Bundle identifier | `com.seedling.app` |
| Minimum macOS | **26.0** (Tahoe) |
| Configuration | Release |
| Source commit | `ca1dff4` |

## Code signing & notarization

| Field | Value |
|---|---|
| Identity | **Developer ID Application: Veronica Loren (P5RB3W3D58)** |
| Hardened runtime | ✅ (`flags=runtime`, `get-task-allow` stripped) |
| Notary status | **Accepted** ✅ |
| Submission ID | `bd3bc173-859f-4a5a-b681-99c9676a7a6e` |
| Ticket | stapled to the DMG (`stapler validate` ✓) |
| Gatekeeper | `accepted · source=Notarized Developer ID` |

## Distribution

| Field | Value |
|---|---|
| Artifact | `Seedling-3.0.2.dmg` (≈2.9 MB) |
| Release | https://github.com/aka-kika/Seedling/releases/tag/v3.0.2 |
| Download | https://github.com/aka-kika/Seedling/releases/download/v3.0.2/Seedling-3.0.2.dmg |
| **SHA-256** | `4a46cbfcf22c0cf0b54192ed02ea3df0050e309e40479afdc85a93773557a6c6` |

Built the same way as [v3.0](RELEASE-v3.0.md) and [v3.0.1](RELEASE-v3.0.1.md) —
same recipe, same identity, same garden. 🌱
