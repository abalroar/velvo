#!/bin/bash
# Builds dist/PhilipsTV Menubar.app. Pass --universal for an arm64 + x86_64 binary (needs Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH_FLAGS=()
if [[ "${1:-}" == "--universal" ]]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi

swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="dist/PhilipsTV Menubar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PhilipsTVMenubar" "$APP/Contents/MacOS/PhilipsTVMenubar"
strip -S "$APP/Contents/MacOS/PhilipsTVMenubar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PhilipsTVMenubar</string>
<key>CFBundleIdentifier</key><string>br.local.PhilipsTVMenubar</string>
<key>CFBundleName</key><string>PhilipsTV Menubar</string>
<key>CFBundleDisplayName</key><string>PhilipsTV Menubar</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSLocalNetworkUsageDescription</key><string>Encontrar e controlar sua TV Philips na mesma rede Wi-Fi.</string>
<key>NSBonjourServices</key><array><string>_androidtvremote2._tcp</string></array>
</dict></plist>
PLIST

codesign --force --sign - --identifier br.local.PhilipsTVMenubar "$APP"
printf 'App criado em %s\n' "$APP"
