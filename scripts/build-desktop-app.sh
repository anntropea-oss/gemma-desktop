#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/outputs/Gemma Desktop.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/packaging/GemmaDesktop-Info.plist" "$APP/Contents/Info.plist"
swift "$ROOT/scripts/generate-app-icon.swift" "$APP/Contents/Resources/GemmaDesktop.icns"

swiftc -parse-as-library \
  "$ROOT/src/GemmaDesktop.swift" \
  -o "$APP/Contents/MacOS/Gemma Desktop"

chmod +x "$APP/Contents/MacOS/Gemma Desktop"
touch "$APP"

printf 'Built %s\n' "$APP"
