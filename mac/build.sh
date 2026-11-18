#!/usr/bin/env bash
# Builds dist/Snapperr-<version>-mac.dmg (Apple Silicon + Intel). Run on a Mac:
#   bash mac/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(tr -d ' \r\n' < VERSION)
OUT=build/mac
APP="$OUT/Snapperr.app"
rm -rf "$OUT"
mkdir -p "$OUT" "$APP/Contents/MacOS" "$APP/Contents/Resources" dist

sed "s/^let appVersion = .*/let appVersion = \"$VERSION\"/" mac/main.swift > "$OUT/main.swift"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos11.0" "$OUT/main.swift" -o "$OUT/Snapperr-$arch"
done
lipo -create "$OUT/Snapperr-arm64" "$OUT/Snapperr-x86_64" -output "$APP/Contents/MacOS/Snapperr"
sed "s/__VERSION__/$VERSION/g" mac/Info.plist > "$APP/Contents/Info.plist"
cp assets/snapperr.icns "$APP/Contents/Resources/Snapperr.icns"
# Not signed by Apple (no paid developer account), so sign "ad hoc" so it runs on Apple Silicon.
codesign --force --deep --sign - --identifier com.skillsgeek.snapperr "$APP"
codesign --verify --verbose "$APP"

mkdir -p "$OUT/dmg"
cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
DMG="dist/Snapperr-$VERSION-mac.dmg"
rm -f "$DMG"
hdiutil create -volname "Snapperr" -srcfolder "$OUT/dmg" -ov -format UDZO "$DMG"
echo "Built $DMG"
shasum -a 256 "$DMG"
