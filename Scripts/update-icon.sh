#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dewqraft-icon.XXXXXX")"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

swift -module-cache-path "$TEMP_DIR/SwiftModuleCache" \
  "$ROOT_DIR/Scripts/render-app-icon.swift" "$TEMP_DIR/DewQRaft.iconset"
iconutil --convert icns \
  --output "$ROOT_DIR/DewQRaft/Assets/DewQRaft.icns" \
  "$TEMP_DIR/DewQRaft.iconset"
