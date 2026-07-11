#!/bin/zsh
set -euo pipefail
setopt NULL_GLOB
export COPYFILE_DISABLE=1

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DewQRaft"
PLIST="$ROOT_DIR/DewQRaft/Info.plist"
PLIST_VERSION="$(plutil -extract CFBundleShortVersionString raw "$PLIST")"
VERSION="${1:-$PLIST_VERSION}"
RELEASE_DIR="$ROOT_DIR/release"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dewqraft-package.XXXXXX")"
DMG_STAGE="$TEMP_DIR/dmg"
ZIP_STAGE="$TEMP_DIR/zip"
ZIP_TEMP="$TEMP_DIR/$APP_NAME-$VERSION.zip"
DMG_TEMP="$TEMP_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [[ "$VERSION" != "$PLIST_VERSION" ]]; then
  echo "Release version $VERSION does not match Info.plist version $PLIST_VERSION" >&2
  exit 1
fi

/bin/zsh "$ROOT_DIR/Scripts/build.sh" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

mkdir -p "$ZIP_STAGE"
ditto "$APP_DIR" "$ZIP_STAGE/$APP_NAME.app"
pushd "$ZIP_STAGE" >/dev/null
zip -qry "$ZIP_TEMP" "$APP_NAME.app"
popd >/dev/null

mkdir -p "$DMG_STAGE"
ditto "$APP_DIR" "$DMG_STAGE/$APP_NAME.app"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_TEMP" >/dev/null

unzip -t "$ZIP_TEMP" >/dev/null
hdiutil verify "$DMG_TEMP" >/dev/null

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
mv "$ZIP_TEMP" "$ZIP_PATH"
mv "$DMG_TEMP" "$DMG_PATH"

echo "$ZIP_PATH"
echo "$DMG_PATH"
