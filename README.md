# DewQRaft

DewQRaft is an offline macOS menu bar utility for crafting QR codes. Open the
menu bar popup, enter content, then copy or save a scannable code. It has no
accounts, network requirement, Dock icon, or pre-filled payload.

## Features

- Text/link, Wi-Fi, contact (vCard 3.0), email, phone, and SMS payloads
- Live offline rendering using the vendored MIT-licensed generator by Kazuhiko Arase
- PNG and SVG copy/export with a native macOS save panel
- Adjustable error correction, export size, code colour, and full QR background colour
- Four interface layouts with persisted accent and window colours
- One-click colour reset to the standard Apple-blue neutral appearance

## Requirements

- macOS 13.0 or later
- Xcode command-line build tools

Release builds are universal binaries for Apple Silicon and Intel Macs.

## Repository layout

- `DewQRaft/` — Swift source, Info.plist, app icon, HTML, and vendored QR resources
- `DewQRaft.xcodeproj/` — Xcode project definition only
- `Tests/` — offscreen WKWebView smoke tests
- `Scripts/` — icon, build, verification, cleanup, and packaging scripts
- `build/DewQRaft.app` — latest local Release app
- `release/DewQRaft-1.1.dmg` and `.zip` — current release artifacts

## Commands

```sh
make build
make verify
make clean
make package
```

`make build` uses temporary DerivedData/module-cache directories, creates a
universal Release app, and ad-hoc signs it. `make verify` rebuilds and runs the
real UI through an offscreen WKWebView; it requires a logged-in macOS GUI
session. `make package` reads the version from `DewQRaft/Info.plist`, replaces
stale release files, and creates validated ZIP and DMG artifacts.

When `DewQRaft/Assets/AppIconSource.png` changes, run `make icons` before
building. The build rejects a stale generated `DewQRaft.icns`.

## Install

Open `release/DewQRaft-1.1.dmg` or `.zip`, then drag `DewQRaft.app` into
Applications. The app is ad-hoc signed rather than Developer ID notarized, so
macOS may require right-clicking the app and choosing Open on first launch.
