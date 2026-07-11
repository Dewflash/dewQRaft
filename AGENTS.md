# AGENTS.md — DewQRaft repository guide

DewQRaft is an offline macOS menu-bar QR utility. Preserve the core flow: open
the menu-bar popup, enter content, then copy or save a scannable QR code without
network access or dead ends.

## Required layout

- `DewQRaft/` contains app source, Info.plist, required resources, and icon assets.
- `DewQRaft.xcodeproj/` contains only `project.pbxproj`.
- `Tests/` contains automated tests.
- `Scripts/` contains build, verification, cleanup, icon, and packaging scripts.
- `build/DewQRaft.app` is the only allowed build output.
- `release/DewQRaft-<version>.dmg` and `.zip` are the only release files.
- Root contains the Makefile, gitignore, README, and project documentation.

The `PLAN-*.md`, `BLOCKERS.md`, and `RELEASE-QA.md` files are historical release
records. Do not re-execute their old roadmap or rewrite their recorded command
output.

## Commands and gates

- `make build` creates a universal ad-hoc-signed Release app.
- `make verify` must exit 0 and print `VERIFY OK` after runtime changes.
- `make clean` removes local build output.
- `make package` rebuilds and replaces the current DMG and ZIP.
- `make icons` regenerates `DewQRaft.icns` from `AppIconSource.png`.

Build and test caches must stay in temporary directories. Never add DerivedData,
module caches, user schemes, workspace state, `.DS_Store`, assistant settings, or
stale binaries to the repository.

## House rules

- No new dependencies or downloads.
- Never edit `DewQRaft/Resources/vendor/`; it is third-party MIT QR code code.
- Use 2-space indentation in HTML/CSS/JavaScript and 4 spaces in Swift.
- Keep shell scripts on zsh with `set -euo pipefail`.
- Preserve the `dewQRaftNative` bridge message types `copyPng`, `copyText`, and
  `save`, plus the `window.dewQRaftNativeDone` callback. Update Swift, JavaScript,
  and the smoke test together if that contract changes.
- Do not commit secrets. Do not push or tag unless the repository owner requests it.
- `make verify` needs a logged-in macOS GUI session for WebKit helper processes.
