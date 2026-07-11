# AGENTS.md — Execution roadmap for DewQRaft handover

You are executing a pre-planned engagement. Every decision that needed judgment has
already been made and written into the `PLAN-*.md` files at repo root. Your job is
faithful execution, honest gates, and honest failure reporting — not creativity.
When a plan and your instinct disagree, the plan wins. When reality and the plan
disagree (a command fails, an anchor is missing), you STOP and log — you do not
improvise.

**Product promise, judge everything against it:** an offline Mac menu-bar utility
where crafting a scannable QR code — click icon, type, copy/save — feels instant,
native, and dead-end free.

## Step 0 — before anything else

Commit the roadmap docs exactly as they stand:

```sh
git add AGENTS.md PLAN-verify.md PLAN-save-panel-flow.md PLAN-payload-fixes.md PLAN-launch-at-login.md PLAN-dead-code.md PLAN-final-polish.md
git commit -m "docs: add execution roadmap"
```

This protects the handover from stray checkouts. Do not edit the plans first.

## Execution order and dependency graph

One plan per session. Finish it — gate green, acceptance criteria met, committed —
before starting the next. Never interleave two plans in one working tree.

```
PLAN-verify (1)                      ← run first; creates the gate itself
 ├─→ PLAN-save-panel-flow (2)        ← independent of 3, 4, 5
 ├─→ PLAN-payload-fixes (3) ─→ PLAN-dead-code (5)
 ├─→ PLAN-launch-at-login (4)        ← independent of 2, 3, 5
 └─→ all of the above ─→ PLAN-final-polish (6)   ← run last, always
```

Recommended sequence: 1, 2, 3, 4, 5, 6. If a plan is blocked, you may continue with
plans that do not depend on it (see graph); PLAN-final-polish always runs last and
must reconcile what actually landed (its Step 0).

## The hard gate — after EVERY plan

1. `/bin/zsh scripts/verify.sh` exits 0 and prints `VERIFY OK`.
   (Before PLAN-verify lands, the gate is the baseline set: `plutil -lint
   macos/Info.plist`, `zsh -n scripts/*.sh`, `/bin/zsh scripts/build-mac-app.sh` —
   all green at HEAD `2e4af47` on 2026-07-11.)
2. That plan's own **Acceptance criteria** section, every numbered item, including
   the manual checks — actually performed, not assumed.
3. Commit with the plan's suggested commit message.

**Never weaken a gate on your own.** Never delete, skip, loosen, or "temporarily
disable" a verify check or an acceptance criterion to get to green. If a gate seems
wrong, that is a blocker to log, not a decision you get to make. The ONLY sanctioned
assertion changes are the ones a plan spells out explicitly (PLAN-payload-fixes
Steps 7–12).

## Failure protocol

When a gate fails and the plan's own steps don't resolve it:

1. **Revert to the last green commit** (`git checkout -- .` for uncommitted work, or
   `git reset --hard <last-green>` if you committed). Never leave a plan half-landed;
   never commit on red.
2. **Log to `BLOCKERS.md`** (create it if missing): the plan name, the exact failing
   command, the FULL output (not a summary), and what you tried.
3. **Continue only with plans independent of the blocked one** (see graph).
   PLAN-final-polish then documents reality: unlanded features stay out of the
   README, and the QA verdict reflects what shipped.

## House rules

- **No new dependencies.** No packages, no downloads, no new vendored code. Apple
  system frameworks explicitly named by a plan (ServiceManagement in
  PLAN-launch-at-login) are the only additions allowed.
- **Never edit `vendor/`** — that is the QR encoder (third-party, MIT). All app
  changes happen in `index.html`, `macos/`, or `scripts/`.
- **Match existing style:** 2-space indent in `index.html` JS/CSS, 4-space in Swift,
  zsh with `set -euo pipefail` in scripts. Scripts are invoked interpreter-prefixed
  (`/bin/zsh …`, `swift …`); do not add exec bits or shebangs beyond what exists.
- **Bridge invariant:** the JS↔Swift contract is the `dewQRaftNative` message
  handler with message types `copyPng`, `copyText`, `save`, and the
  `window.dewQRaftNativeDone` callback. Any change to one side changes the other
  side AND the smoke test in the same commit.
- **Never commit:** `build/`, `.DS_Store`, `release/*/` staging folders, or any
  secret. The sanctioned exception: `release/DewQRaft-<version>.zip`, `.dmg`, and
  `release/INSTALL.txt` are tracked by existing repo convention (the 1.0 artifacts
  already are), and PLAN-final-polish commits the 1.1 ones.
- **Never push, never create tags except where PLAN-final-polish says, never touch
  GitHub.** The repo owner pushes.
- `verify.sh` needs a logged-in macOS GUI session (WebKit helper processes); it
  opens no windows. A failure over plain SSH is environmental, not a regression —
  rerun in a GUI session before concluding anything.

## Definition of done

- All six plans landed with green gates and their suggested commit messages — or
  blocked ones honestly logged in `BLOCKERS.md` with the protocol above.
- `RELEASE-QA.md` committed with every row's Result filled and an explicit
  **SHIP / DO-NOT-SHIP** verdict, produced under its verbatim honesty rule.
- Tag `v1.1` exists if and only if the verdict is SHIP.
- No uncommitted changes, no red gate, no undocumented deviation from any plan.
