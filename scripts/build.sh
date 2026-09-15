#!/bin/bash
# Builds Flow.app and a drag-to-install DMG into dist/.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="Flow"
BUNDLE_ID="com.jashdubal.flow"
VERSION="${VERSION:-1.0.0}"

DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
STAGE="$ROOT/.build/dmg"

rm -rf "$DIST" "$STAGE"
mkdir -p "$DIST"

echo "==> Compiling (release, universal)"
swift build -c release --arch arm64 --arch x86_64 2>&1 | grep -v 'SwiftUICore' || true
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"
[ -f "$BIN" ] || { echo "build failed: no binary at $BIN"; exit 1; }

echo "==> Assembling $APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

echo "==> Rendering icon"
ICONSET="$ROOT/.build/$APP_NAME.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
swift "$ROOT/scripts/makeicon.swift" "$ROOT/.build/icon.png" >/dev/null
for size in 16 32 64 128 256 512; do
  sips -z $size $size "$ROOT/.build/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size*2)) $((size*2)) "$ROOT/.build/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/$APP_NAME.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleIconFile</key><string>$APP_NAME</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <!-- Menu bar resident: no Dock tile, no app switcher entry. -->
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Flow — minimalist focus timer</string>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Contents/Info.plist" >/dev/null

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - --options runtime "$APP" 2>/dev/null \
  || codesign --force --deep --sign - "$APP"
codesign --verify --verbose=1 "$APP"

echo "==> Building DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format ULFO "$DMG" >/dev/null
rm -rf "$STAGE"

echo
echo "  app  ->  $APP"
echo "  dmg  ->  $DMG"
