#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DewQRaft"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dewqraft-verify.XXXXXX")"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "== repository hygiene"
if find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o \
  \( -name .DS_Store -o -name xcuserdata -o -name '*.xcuserstate' -o -name DerivedData \) \
  -print | grep -q .; then
  echo "Repository contains local state or build cache" >&2
  exit 1
fi

echo "== Info.plist lint"
plutil -lint "$ROOT_DIR/DewQRaft/Info.plist"

echo "== Xcode project"
xcodebuild -project "$ROOT_DIR/$APP_NAME.xcodeproj" -list >/dev/null

echo "== shell script syntax"
for script in "$ROOT_DIR"/Scripts/*.sh; do
  zsh -n "$script"
  echo "syntax OK: ${script:t}"
done

echo "== Release build"
/bin/zsh "$ROOT_DIR/Scripts/build.sh"

echo "== app bundle"
[[ -d "$APP_DIR" ]]
[[ "$(find "$ROOT_DIR/build" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == "1" ]]
[[ -f "$APP_DIR/Contents/Resources/$APP_NAME.icns" ]]
codesign --verify --deep --strict "$APP_DIR"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_DIR/Contents/Info.plist")"
SOURCE_VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT_DIR/DewQRaft/Info.plist")"
[[ "$APP_VERSION" == "$SOURCE_VERSION" ]]

echo "== smoke test (offscreen WKWebView)"
swift -module-cache-path "$TEMP_DIR/SwiftModuleCache" \
  "$ROOT_DIR/Tests/SmokeTest.swift" "$ROOT_DIR/DewQRaft/Resources/index.html"

echo "VERIFY OK"
