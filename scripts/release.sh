#!/usr/bin/env bash
#
# Build, sign, notarize, and staple a distributable Seedling DMG.
# Mirrors the recipe used for 3.1.0 (and every release since).
#
# One-time prereqs:
#   - "Developer ID Application: Veronica Loren (P5RB3W3D58)" cert in the login keychain.
#   - A notarytool keychain profile (default name: seedling-notary):
#       xcrun notarytool store-credentials "seedling-notary" \
#         --apple-id "<apple-id>" --team-id "P5RB3W3D58" --password "<app-specific-password>"
#
# Usage:  scripts/release.sh [version]
#   version defaults to CFBundleShortVersionString from the app Info.plist.
#   Override the profile with NOTARY_PROFILE=<name> scripts/release.sh
#
# Output: dist/Seedling-<version>.dmg  (notarized + stapled), plus its SHA-256.
#
set -euo pipefail

TEAM_ID="P5RB3W3D58"
IDENTITY="Developer ID Application: Veronica Loren (P5RB3W3D58)"
NOTARY_PROFILE="${NOTARY_PROFILE:-seedling-notary}"
SCHEME="Seedling"
PROJECT="Seedling.xcodeproj"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Seedling/Resources/Info.plist)}"
DMG="dist/Seedling-${VERSION}.dmg"

echo "▸ Releasing Seedling ${VERSION}"
rm -rf release_build/Seedling.xcarchive release_build/export release_build/dmg_stage
mkdir -p release_build dist

echo "▸ Archiving (Release)…"
xcodebuild archive \
  -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -archivePath release_build/Seedling.xcarchive \
  -destination 'generic/platform=macOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" >/dev/null

echo "▸ Exporting Developer ID app…"
cat > release_build/exportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive \
  -archivePath release_build/Seedling.xcarchive \
  -exportOptionsPlist release_build/exportOptions.plist \
  -exportPath release_build/export >/dev/null

APP="release_build/export/Seedling.app"
echo "▸ Verifying signature…"
codesign --verify --deep --strict "$APP"
codesign -dvv "$APP" 2>&1 | grep -q "flags=0x10000(runtime)" \
  || { echo "✗ hardened runtime missing"; exit 1; }

echo "▸ Building DMG…"
STAGE=release_build/dmg_stage
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Seedling.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Seedling" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "▸ Notarizing (waiting on Apple)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vvv -t install "$DMG" 2>&1 | sed 's/^/   /'

echo "▸ SHA-256:"
shasum -a 256 "$DMG"
echo "✓ Done → $DMG"
