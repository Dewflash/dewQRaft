# Roadmap blockers

## PLAN-save-panel-flow

The implementation was applied exactly as specified and `/bin/zsh scripts/verify.sh`
completed with `VERIFY OK`, but the required manual acceptance criteria could not be
performed in the current Codex execution environment. Per the failure protocol, the
uncommitted implementation was reverted to the last green commit.

### Failing command 1

```sh
osascript -e 'tell application "System Events" to get name of every process whose name is "DewQRaft"' -e 'tell application "System Events" to tell process "DewQRaft" to get description of every menu bar item of menu bar 1'
```

Full output:

```text
154:165: execution error: System Events got an error: osascript is not allowed assistive access. (-1719)
```

### Failing command 2

```sh
screencapture -x /private/tmp/dewqraft-save-flow-start.png
```

Full output:

```text
could not create image from display
```

### What was tried

1. Ran the plan's required pre-change `/bin/zsh scripts/verify.sh`; it exited 0 and
   printed `VERIFY OK`.
2. Applied Steps 1–4 exactly to `macos/DewQRaftApp.swift`; `git diff --name-only`
   listed only that file and `git diff --check` passed.
3. Ran the plan's required post-change `/bin/zsh scripts/verify.sh`; it exited 0 and
   printed `VERIFY OK`, including all 38 smoke checks.
4. Launched the required artifact with `open build/DewQRaft.app`; the process ran.
5. Tried to drive and inspect the menu-bar UI with macOS Accessibility through
   System Events; the environment denied assistive access with error `-1719`.
6. Tried to gather direct visual evidence with `screencapture`; the environment
   could not create an image from the display.
7. Stopped the launched app and reverted the uncommitted implementation with
   `git checkout -- .` as required. No manual result was assumed.
