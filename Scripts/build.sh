#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DewQRaft"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dewqraft-build.XXXXXX")"
DERIVED_DATA="$TEMP_DIR/DerivedData"
ICONSET_DIR="$TEMP_DIR/$APP_NAME.iconset"
GENERATED_ICON="$TEMP_DIR/$APP_NAME.icns"
SOURCE_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

swift -module-cache-path "$TEMP_DIR/SwiftModuleCache" \
  "$ROOT_DIR/Scripts/render-app-icon.swift" "$ICONSET_DIR"
iconutil --convert icns --output "$GENERATED_ICON" "$ICONSET_DIR"
if ! cmp -s "$GENERATED_ICON" "$ROOT_DIR/DewQRaft/Assets/$APP_NAME.icns"; then
  echo "App icon is stale. Run 'make icons' and commit the regenerated icon." >&2
  exit 1
fi

xcodebuild \
  -project "$ROOT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=NO \
  CLANG_MODULE_CACHE_PATH="$TEMP_DIR/ClangModuleCache" \
  SWIFT_MODULE_CACHE_PATH="$TEMP_DIR/SwiftModuleCache" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build
rm -rf "$ROOT_DIR/$APP_NAME.xcodeproj/project.xcworkspace" \
  "$ROOT_DIR/$APP_NAME.xcodeproj/xcuserdata"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
ditto "$SOURCE_APP" "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"
rm -f "$BUILD_DIR/.DS_Store"

echo "$APP_DIR"
