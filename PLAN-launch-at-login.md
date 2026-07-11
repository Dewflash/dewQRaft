# PLAN-launch-at-login — "Launch at Login" toggle in the right-click menu

**Rank:** 4 of 6.
**Dependencies:** run AFTER PLAN-verify. Independent of PLAN-save-panel-flow,
PLAN-payload-fixes, and PLAN-dead-code (touches different code; if
PLAN-save-panel-flow already landed, the anchors below are unaffected).
**Effort:** Medium (small code, but acceptance is partly manual/system-level).
**Files touched:** `macos/DewQRaftApp.swift`, `scripts/build-mac-app.sh`. **Nothing else.**

## Goal

DewQRaft is a resident menu-bar utility, but it disappears on every reboot until the
user manually relaunches it — the one capability missing from the "always one click
away" product story. macOS 13+ ships `SMAppService` for exactly this, and the app's
`LSMinimumSystemVersion` is already `13.0` (`macos/Info.plist`), so no deployment
floor changes.

The right-click status-item menu (built fresh on every open in `showStatusMenu()`)
gains a "Launch at Login" item whose checkmark reflects live registration state.

**Feasibility already probed on this machine (2026-07-11):** the
`SMAppService.mainApp` `register`/`unregister`/`status` API typechecks with the
system Swift toolchain. Step 0 re-proves it cheaply in your session.

## Steps

### Step 0 — Feasibility probe

```sh
cat > /tmp/sm-probe.swift <<'EOF'
import AppKit
import ServiceManagement

func probe() {
    let service = SMAppService.mainApp
    let enabled = service.status == .enabled
    _ = enabled
    do { try service.register() } catch { _ = error }
    do { try service.unregister() } catch { _ = error }
}
EOF
swiftc -typecheck /tmp/sm-probe.swift && echo PROBE-OK
```

Expected output ends with `PROBE-OK`. **If this fails: STOP and report — do not
improvise.** (Do not commit the probe file; it lives in /tmp.)

Also confirm the gate is green at your starting point:

```sh
/bin/zsh scripts/verify.sh
```

### Step 1 — Import ServiceManagement

In `macos/DewQRaftApp.swift`, find:

```swift
import AppKit
import UniformTypeIdentifiers
import WebKit
```

Replace with:

```swift
import AppKit
import ServiceManagement
import UniformTypeIdentifiers
import WebKit
```

### Step 2 — Add the menu item in `showStatusMenu()`

Find:

```swift
    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit DewQRaft", action: #selector(quit), keyEquivalent: "q"))
```

Replace with:

```swift
    private func showStatusMenu() {
        let menu = NSMenu()
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DewQRaft", action: #selector(quit), keyEquivalent: "q"))
```

(The following lines — `menu.items.forEach { $0.target = self }` etc. — stay exactly
as they are.)

### Step 3 — Add the toggle action to `AppDelegate`

Directly after the closing brace of `showStatusMenu()`, add:

```swift
    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update Launch at Login"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
```

### Step 4 — Link the framework explicitly in the build script

In `scripts/build-mac-app.sh`, find:

```sh
swiftc "$ROOT_DIR/macos/DewQRaftApp.swift" -o "$MACOS_DIR/$APP_NAME" -framework AppKit -framework WebKit -framework UniformTypeIdentifiers
```

Replace with:

```sh
swiftc "$ROOT_DIR/macos/DewQRaftApp.swift" -o "$MACOS_DIR/$APP_NAME" -framework AppKit -framework WebKit -framework UniformTypeIdentifiers -framework ServiceManagement
```

### Step 5 — Verify and check manually

```sh
/bin/zsh scripts/verify.sh
```

Then perform the manual checks below. For registration checks, use a copy in
/Applications (see edge cases for why):

```sh
ditto build/DewQRaft.app /Applications/DewQRaft.app && open /Applications/DewQRaft.app
```

## Edge cases a weaker model would miss

- **Register the /Applications copy, not `build/DewQRaft.app`.** Login-item
  registration for an ad-hoc-signed app is tied to the bundle on disk. Registering
  the build-directory copy creates a login item pointing into `build/` — which this
  repo's scripts delete and rebuild (`rm -rf "$APP_DIR"` in `build-mac-app.sh`),
  leaving a dangling login item. Manual checks must run against /Applications.
- **`.requiresApproval` is not `.enabled`.** macOS may park the registration as
  "requires approval" (user must flip it in System Settings → General → Login Items).
  The menu checkmark correctly shows OFF in that state — that is honest, not a bug.
  Do not special-case it.
- **The menu is rebuilt on every right-click** (existing `showStatusMenu()` design),
  which is what keeps the checkmark honest if the user changes the setting in System
  Settings instead of the menu. Do not cache the menu or the item.
- **Keep `menu.items.forEach { $0.target = self }` untouched.** It now also iterates
  the separator — harmless (separators have no action) — and it is what makes the new
  item clickable: an `NSMenuItem` without a target is auto-disabled (greyed out).
- **`NSApp.activate` before `alert.runModal()` is load-bearing** for an
  `LSUIElement` (accessory) app: without it the alert can appear behind other apps'
  windows with no Dock icon to find it by.
- **Do not add entitlements, Info.plist keys, or signing steps.** `SMAppService.mainApp`
  needs none of that for a login item; inventing them breaks the ad-hoc build.
- **The smoke test does not change** — this feature is native-only and the smoke
  drives the web layer. Expect the same PASS count as before this plan.
- **First `register()` may show a macOS notification** ("DewQRaft added as Login
  Item") — expected system behavior, not an error.

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0 with `VERIFY OK`.
2. `git diff --name-only` lists exactly: `macos/DewQRaftApp.swift`,
   `scripts/build-mac-app.sh`.
3. Manual, against `/Applications/DewQRaft.app` (install per Step 5):
   a. Right-click the menu bar icon → menu shows "Launch at Login" (unchecked),
      a separator, then "Quit DewQRaft".
   b. Click "Launch at Login" → right-click again → the item is now checked.
   c. System Settings → General → Login Items & Extensions: DewQRaft appears in the
      "Open at Login" list (or as requiring approval — see edge cases; approving it
      must then show the checkmark).
   d. Click "Launch at Login" again → item unchecked, and DewQRaft disappears from
      the System Settings list.
   e. Quit and relaunch the app — toggling still works (state survives relaunch).
4. Cleanup after checks: leave "Launch at Login" OFF unless you are on the final
   release pass, and quit the /Applications copy.

**Suggested commit message:**

```
feat: add Launch at Login toggle to status item menu
```
