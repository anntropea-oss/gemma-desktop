#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/outputs/Gemma Desktop.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/packaging/GemmaDesktop-Info.plist" "$APP/Contents/Info.plist"

swiftc -parse-as-library \
  "$ROOT/src/GemmaDesktop.swift" \
  -o "$APP/Contents/MacOS/Gemma Desktop"

chmod +x "$APP/Contents/MacOS/Gemma Desktop"

printf 'Built %s\n' "$APP"
