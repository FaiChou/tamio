#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
swift build --package-path "$ROOT/Foundation/TamioTerminal" --product TamioConfigurationPreview
BIN="$(swift build --package-path "$ROOT/Foundation/TamioTerminal" --show-bin-path)"
APP="$ROOT/DerivedData/TamioConfigurationPreview.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/TamioConfigurationPreview" "$APP/Contents/MacOS/"
for bundle in "$BIN"/*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>sb.moe.tamio.configuration-preview</string>
<key>CFBundleExecutable</key><string>TamioConfigurationPreview</string>
<key>CFBundleName</key><string>Tamio Configuration Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
/usr/bin/printf '%s\n' "$APP"
