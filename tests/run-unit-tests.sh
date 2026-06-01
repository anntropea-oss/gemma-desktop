#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.tmp-source-indexer-tests"

swiftc \
  "$ROOT/src/Models.swift" \
  "$ROOT/src/SourceIndexer.swift" \
  "$ROOT/tests/SourceIndexerSmokeTests.swift" \
  -o "$BIN"

"$BIN"
rm -f "$BIN"

