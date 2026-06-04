# Seedling — Release Record · v3.0

> A keepsake record of the v3.0 release: what it is, how it was built, signed, and notarized.

## The app

**Seedling** — *Plant a seed and watch it grow.*

A tiny, calm macOS menu-bar app for starting new projects. Summon a centered window (the menu-bar leaf or `⌥⌘S`), name a project, and watch a line-art seedling draw itself and bloom — your new project folder, seeded with your rules and guidelines (`AGENTS.md`, `CLAUDE.md`, `README`, `TODO`, `SECURITY`, …) and born on the spot. Made for late nights, brain resets, and fresh beginnings.

- **Root** — the folder where your seed files (`.md`) live
- **Garden** — where new projects grow, each a named subfolder
- Never overwrites; re-planting leaves existing files untouched

## Build & identity

| Field | Value |
|---|---|
| Version | **3.0** (build 1) |
| Bundle identifier | `com.seedling.app` |
| Minimum macOS | **26.0** (Tahoe) |
| Tech | SwiftUI + AppKit, Liquid Glass, sandboxed |
| Configuration | Release |
| Source commit | `fb075a3` |

## Code signing

| Field | Value |
|---|---|
| Identity | **Developer ID Application: Veronica Loren (P5RB3W3D58)** |
| Team ID | `P5RB3W3D58` |
| Hardened runtime | ✅ enabled (`flags=runtime`) |
| Secure timestamp | ✅ |
| Entitlements | App Sandbox · user-selected files (read-write) · app-scope bookmarks |
| `get-task-allow` | ✅ removed (re-signed; required for notarization) |

## Notarization

| Field | Value |
|---|---|
| Service | Apple Notary (`notarytool`) |
| Apple ID | `iliuchina@icloud.com` |
| Submission ID | `9f700bd5-7610-4630-b66f-be18c65a4f47` |
| Status | **Accepted** ✅ |
| Ticket | stapled to the DMG (`stapler staple` + `validate` ✓) |
| Gatekeeper | `accepted · source=Notarized Developer ID` |

## Distribution

| Field | Value |
|---|---|
| Artifact | `Seedling-3.0.dmg` (≈2.8 MB) |
| DMG | code-signed + notarized + stapled; "drag to Applications" layout |
| Release | https://github.com/aka-kika/Seedling/releases/tag/v3.0 |
| Download | https://github.com/aka-kika/Seedling/releases/download/v3.0/Seedling-3.0.dmg |
| **SHA-256** | `3a0b0e16b10cfee270f8c16f8b7b90f5eec9f5b6aa35bef576f73a88da2665a8` |

## Verify it yourself

```bash
# checksum
shasum -a 256 Seedling-3.0.dmg
# → 3a0b0e16b10cfee270f8c16f8b7b90f5eec9f5b6aa35bef576f73a88da2665a8

# notarization ticket is stapled
xcrun stapler validate Seedling-3.0.dmg

# Gatekeeper accepts it
spctl -a -t open --context context:primary-signature -vv Seedling-3.0.dmg
```

## How it was made (for the next release)

```bash
# 1. Build Release, signed with Developer ID + hardened runtime + timestamp
xcodebuild -project Seedling.xcodeproj -scheme Seedling -configuration Release \
  -derivedDataPath ./release_build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: Veronica Loren (P5RB3W3D58)" \
  DEVELOPMENT_TEAM=P5RB3W3D58 ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" build

# 2. Strip the injected get-task-allow entitlement (notarization rejects it)
codesign --force --options runtime --timestamp \
  --entitlements Seedling/Resources/Seedling.entitlements \
  --sign "Developer ID Application: Veronica Loren (P5RB3W3D58)" \
  release_build/Build/Products/Release/Seedling.app
# (Permanent fix: set CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO in the Release config.)

# 3. Build the DMG (homebrew create-dmg), signed
create-dmg --volname "Seedling" --volicon <AppIcon.icns> \
  --window-size 540 380 --icon-size 110 \
  --icon "Seedling.app" 150 185 --app-drop-link 390 185 \
  --codesign "Developer ID Application: Veronica Loren (P5RB3W3D58)" \
  dist/Seedling-3.0.dmg dist/stage

# 4. Notarize, staple, upload
xcrun notarytool submit dist/Seedling-3.0.dmg --keychain-profile "seedling-notary" --wait
xcrun stapler staple dist/Seedling-3.0.dmg
gh release upload v3.0 dist/Seedling-3.0.dmg
```

---

*Notarized and shipped 2026-06-04. 🌙🌱*
