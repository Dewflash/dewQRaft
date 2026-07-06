# DewQRaft

DewQRaft is an offline Mac menu bar utility for crafting QR codes.

## Features

- Text/link, Wi-Fi, contact, email, phone, and SMS payloads
- Live offline QR rendering
- PNG and SVG copy/export
- Native macOS save panel for naming saved files
- No network calls or external assets

## Build

```sh
/bin/zsh scripts/build-mac-app.sh
```

The app bundle is created at `build/DewQRaft.app`.

## Release

```sh
/bin/zsh scripts/package-release.sh 1.0
```

The release files are created in `release/` as a ZIP, a DMG, and `INSTALL.txt`.
