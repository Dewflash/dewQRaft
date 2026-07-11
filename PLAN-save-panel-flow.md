# PLAN-save-panel-flow — Popup returns after Save, with visible confirmation

**Rank:** 2 of 6.
**Dependencies:** run AFTER PLAN-verify (the gate must exist). Independent of all other plans.
**Effort:** Small.
**Files touched:** `macos/DewQRaftApp.swift`. **Nothing else.**

## Goal

The core promise is a fast menu-bar loop: click icon → craft QR → copy/save → done.
Today that loop dead-ends at Save. Measured behavior on this machine (probe run
2026-07-11, macOS 26.5.1):

- The popover uses `.transient` behavior (`configurePopover()` in
  `macos/DewQRaftApp.swift`). The moment `NSSavePanel.begin` presents the panel, the
  popover auto-closes — before any user click.
- After saving, `callJavaScriptDone("Saved")` fires the toast into a popup that is no
  longer on screen. The user gets **no confirmation**, and must re-click the menu bar
  icon to continue.

Fix: make the close explicit, and **re-open the popover automatically when the save
panel finishes** (saved OR cancelled). The user sees the popup come back with the
"Saved" toast visible. State is preserved because `webViewController` is retained by
`AppDelegate` for the app's lifetime.

**Why not keep the popover open during the panel?** Probed and rejected: the popover
window sits at window level 25, `NSSavePanel` at level 0, and their frames overlap —
a pinned-open popover draws *on top of* the save panel. Do not attempt the
`.applicationDefined` pinning approach.

## Steps

All anchors below are exact strings verified to exist in `macos/DewQRaftApp.swift`
at HEAD. Match on the code text, not line numbers.

### Step 0 — Confirm the gate is green before touching anything

```sh
/bin/zsh scripts/verify.sh
```

If this fails at HEAD: STOP and report — do not improvise.

### Step 1 — Add the reopen hooks to `WebViewController`

Find:

```swift
final class WebViewController: NSViewController, WKScriptMessageHandler {
    private var didLoad = false
```

Replace with:

```swift
final class WebViewController: NSViewController, WKScriptMessageHandler {
    var savePanelWillOpen: (() -> Void)?
    var savePanelFinished: (() -> Void)?
    private var didLoad = false
```

### Step 2 — Signal around the save panel in `saveFile(from:)`

Find (inside `saveFile(from:)`):

```swift
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = allowedTypes(for: mime)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                self?.callJavaScriptDone("Saved")
            } catch {
                self?.callJavaScriptDone("Save failed")
            }
        }
```

Replace with:

```swift
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = allowedTypes(for: mime)
        savePanelWillOpen?()
        panel.begin { [weak self] response in
            guard let self else { return }
            self.savePanelFinished?()
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                self.callJavaScriptDone("Saved")
            } catch {
                self.callJavaScriptDone("Save failed")
            }
        }
```

### Step 3 — Factor popover presentation into `showPopover()` in `AppDelegate`

Find (inside `statusItemClicked(_:)`):

```swift
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            webViewController.loadIfNeeded()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            webViewController.focus()
        }
```

Replace with:

```swift
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
```

Then add this method to `AppDelegate`, directly after the closing brace of
`statusItemClicked(_:)`:

```swift
    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        webViewController.loadIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        webViewController.focus()
    }
```

### Step 4 — Wire the hooks in `configurePopover()`

Find:

```swift
    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = AppConfig.popoverSize
        popover.contentViewController = webViewController
    }
```

Replace with:

```swift
    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = AppConfig.popoverSize
        popover.contentViewController = webViewController
        webViewController.savePanelWillOpen = { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }
        webViewController.savePanelFinished = { [weak self] in
            self?.showPopover()
        }
    }
```

### Step 5 — Verify and check manually

```sh
/bin/zsh scripts/verify.sh
```

Then run the manual checks under Acceptance criteria using `build/DewQRaft.app`
(open it with `open build/DewQRaft.app`; quit it afterwards from its right-click menu).

## Edge cases a weaker model would miss

- **`savePanelWillOpen?()` must run BEFORE `panel.begin`.** The transient popover
  auto-closes as a side effect of the panel appearing; closing it explicitly first
  makes the sequence deterministic instead of depending on AppKit's dismissal timing,
  which can change between macOS versions.
- **`self.savePanelFinished?()` must be the FIRST statement in the completion handler,
  before the `response == .OK` guard.** The guard returns early on Cancel. If the
  reopen call sits after it, cancelling the dialog strands the user with a closed
  popup — the exact dead end this plan removes.
- **Keep `popover.behavior = .transient`.** Do not change it anywhere, temporarily or
  permanently. The pinned-open alternative was probed and draws the popover on top of
  the save panel (window level 25 vs 0) — see Goal. Outside-click-closes must keep
  working; a manual check asserts it.
- **`showPopover()` must guard `!popover.isShown`.** While the save panel is open the
  user can manually re-open the popup from the menu bar icon; an unconditional
  `popover.show` on completion would then re-present an already-shown popover
  (flicker, and AppKit may raise).
- **Do not rename the closures or make them non-optional.** `WebViewController` is
  also instantiated by nothing else, but the optional-closure pattern keeps the
  controller buildable in isolation (the smoke harness does not set them).
- **The toast still works because `webViewController` outlives the popover.**
  `AppDelegate` holds it strongly; the WKWebView keeps executing JS while detached.
  Do not "clean up" the controller or webview on popover close.
- **Reopen order (`savePanelFinished` before `callJavaScriptDone("Saved")`) is
  load-bearing:** it puts the popup back on screen first so the toast fires into a
  visible view.

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0 with `VERIFY OK`. (No smoke assertions change
   in this plan — the smoke harness drives the JS bridge without a real save panel.)
2. `git diff --name-only` lists exactly one file: `macos/DewQRaftApp.swift`.
3. Manual, against `build/DewQRaft.app`:
   a. Click the menu bar icon → popup opens. Click **Save PNG…** → popup closes, save
      panel is frontmost and fully visible. Save to Desktop → **popup re-opens by
      itself** and a "Saved" toast is visible bottom-right. The PNG on the Desktop
      opens in Preview and shows the QR code.
   b. Click **Save SVG…** → in the save panel press **Cancel** → popup re-opens by
      itself, no toast.
   c. With the popup open, click anywhere outside it (e.g. the desktop) → popup closes
      (transient behavior preserved).
   d. Right-click the menu bar icon → Quit still works.

**Suggested commit message:**

```
fix: reopen popover after save panel so Saved confirmation is seen
```
