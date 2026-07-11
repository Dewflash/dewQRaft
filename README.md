# DewQRaft

DewQRaft is an offline macOS menu bar utility for crafting QR codes. Click the menu
bar icon, type, and copy or save a scannable code — no network, no accounts, no Dock
icon.

## Features

- Payload types: text/link, Wi-Fi, contact (vCard 3.0), email, phone, SMS
- Live offline rendering (vendored MIT-licensed generator by Kazuhiko Arase)
- PNG and SVG export via copy or native save panel
- Adjustable error correction, export size (512–2048 px), ink/paper colours,
  transparent background
- Popup accent/paper theme, persisted between launches

## Requirements

- macOS 13.0 or later (Apple Silicon or Intel)

## Install

Download `release/DewQRaft-1.1.dmg` (or the `.zip`), drag `DewQRaft.app` into
Applications, and open it. The app is ad-hoc signed (no Apple Developer ID), so on
first launch right-click the app and choose Open if macOS blocks it.

## Build from source

```sh
/bin/zsh scripts/build-mac-app.sh
```

The app bundle is created at `build/DewQRaft.app`.

## Verify

```sh
/bin/zsh scripts/verify.sh
```

Runs plist lint, shell syntax checks, a full build, and a WKWebView smoke test that
drives the real UI. Requires a logged-in macOS session; opens no windows.

## Release

```sh
/bin/zsh scripts/package-release.sh 1.1
```

Creates the ZIP, DMG, and `INSTALL.txt` in `release/`.
