#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DewQRaft"
VERSION="${1:-1.0}"
RELEASE_DIR="$ROOT_DIR/release"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
ZIP_STAGE="/private/tmp/dewqraft-zip-stage"
DMG_STAGE="/private/tmp/dewqraft-dmg-stage"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
INSTALL_PATH="$RELEASE_DIR/INSTALL.txt"

mkdir -p "$RELEASE_DIR"

"$ROOT_DIR/scripts/build-mac-app.sh" >/dev/null

cat > "$INSTALL_PATH" <<EOF
$APP_NAME $VERSION

ZIP install:
1. Open $APP_NAME-$VERSION.zip.
2. Drag $APP_NAME.app into Applications.
3. Open it from Applications. If macOS blocks first launch, right-click the app and choose Open.

DMG install:
1. Open $APP_NAME-$VERSION.dmg.
2. Drag $APP_NAME.app into Applications.
3. Open it from Applications. If macOS blocks first launch, right-click the app and choose Open.

Notes:
- $APP_NAME is offline and does not need internet access.
- This build is unsigned with an Apple Developer ID, so macOS may show a trust prompt.
EOF

rm -rf "$ZIP_STAGE" "$DMG_STAGE"
rm -f "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$ZIP_STAGE" "$DMG_STAGE"

ditto "$APP_DIR" "$ZIP_STAGE/$APP_NAME.app"
cp "$INSTALL_PATH" "$ZIP_STAGE/INSTALL.txt"
ditto -c -k --sequesterRsrc "$ZIP_STAGE" "$ZIP_PATH"

ditto "$APP_DIR" "$DMG_STAGE/$APP_NAME.app"
cp "$INSTALL_PATH" "$DMG_STAGE/INSTALL.txt"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "$ZIP_PATH"
echo "$DMG_PATH"
