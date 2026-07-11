#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "== Info.plist lint"
plutil -lint "$ROOT_DIR/macos/Info.plist"

echo "== shell script syntax"
for f in "$ROOT_DIR"/scripts/*.sh; do
  zsh -n "$f"
  echo "syntax OK: ${f:t}"
done

echo "== build (swift compile + bundle + ad-hoc sign)"
/bin/zsh "$ROOT_DIR/scripts/build-mac-app.sh"

echo "== smoke test (offscreen WKWebView)"
swift "$ROOT_DIR/scripts/smoke-test.swift" "$ROOT_DIR/index.html"

echo "VERIFY OK"
