# PLAN-dead-code — Remove the unreachable hand-rolled QR encoder

**Rank:** 5 of 6.
**Dependencies:** run AFTER PLAN-verify (the smoke test is the safety net for this
deletion) and AFTER PLAN-payload-fixes (both edit `index.html`; fixed order keeps
anchors stable). Independent of PLAN-save-panel-flow and PLAN-launch-at-login.
**Effort:** Small (pure deletion, heavily guarded).
**Files touched:** `index.html`. **Nothing else. Deletions only — zero inserted lines.**

## Goal

`index.html` contains a complete second QR encoder — Reed-Solomon math, bit buffers,
mask scoring (`ECC_CODEWORDS`, `gfMultiply`, `rsRemainder`, `BitBuffer`, `encodeQr`,
`drawQr`, `scorePenalty`, …) — that is **provably never executed**: its only root,
`encodeQr(...)`, has zero call sites (verified: `grep -n "encodeQr" index.html`
shows only the definition). The app's real encoder is the vendored, battle-tested
Kazuhiko Arase library, called through `makeQr()` → `qrcode(0, level)`.

Why this matters for a handover: it is a *decoy implementation of the app's central
function*, ~25% of the file. A future maintainer "fixing QR generation" will land in
`encodeQr`/`drawQr` first (the names sound authoritative), edit dead code, and watch
nothing change. Deleting it removes that trap. The smoke test (which pins payload
strings AND the PNG/SVG bridge output) proves behavior is unchanged.

Also removed: three duplicate event-listener registrations that re-bind `render` to
selects already covered by the generic loop directly above them (harmless, but they
are the same kind of misleading residue).

## Steps

Anchor on exact code text, not line numbers.

### Step 0 — Gate green before starting

```sh
/bin/zsh scripts/verify.sh
```

If this fails before you change anything: STOP and report — do not improvise.

### Step 1 — Deletion A (ECC tables through `BitBuffer`)

Delete the contiguous block that starts at the line:

```js
      const ECC_CODEWORDS = {
```

and ends at (inclusive) **the blank line immediately before** the line:

```js
      function makeQr(text, level) {
```

The deleted block contains, in order: `ECC_CODEWORDS`, `ECC_BLOCKS`,
`TOTAL_CODEWORDS`, `ALIGNMENT_POSITIONS`, the `gfExp`/`gfLog` arrays and their
init loop (`let value = 1; …`), `gfMultiply`, `rsDivisor`, `rsRemainder`, and
`class BitBuffer`. If the block you are about to delete does not contain exactly
those items, STOP — you have mis-anchored.

### Step 2 — KEEP `makeQr` untouched

This function stays, byte for byte — it is the app's only live QR entry point,
called from `render()`:

```js
      function makeQr(text, level) {
        const qr = qrcode(0, level);
        qr.addData(text);
        qr.make();
        const size = qr.getModuleCount();
        return Array.from({ length: size }, (_, row) =>
          Array.from({ length: size }, (_, col) => qr.isDark(row, col))
        );
      }
```

### Step 3 — Deletion B (`encodeQr` through `samePattern`)

Delete the contiguous block that starts at the line:

```js
      function encodeQr(data, version, level, dataCapacity, countBits) {
```

and ends at (inclusive) **the blank line immediately before** the line:

```js
      function qrPayload() {
```

The deleted block contains, in order: `encodeQr`, `addEccAndInterleave`, `drawQr`,
`drawFinder`, `drawAlignment`, `reserveFormat`, `drawVersion`, `maskBit`,
`applyMask`, `drawFormat`, `scorePenalty`, `linePenalty`, `samePattern`. Same rule:
if the block differs from that list, STOP.

### Step 4 — Deletion C (duplicate listeners)

Delete exactly these three lines (they appear together, directly after the
`document.querySelectorAll("input, textarea, select").forEach(...)` block, which
already binds `render` to `input` AND `change` on every select):

```js
      elements.errorLevel.addEventListener("change", render);
      elements.exportSize.addEventListener("change", render);
      elements.backgroundMode.addEventListener("change", render);
```

### Step 5 — Run the gate

```sh
/bin/zsh scripts/verify.sh
```

## Edge cases a weaker model would miss

- **`makeQr` looks like part of the dead cluster but is the ONE live function** in
  that region (it sits between Deletion A and Deletion B). Deleting it kills every
  QR render; the smoke fails on nearly all checks. That is why Steps 1 and 3 name
  their complete contents and Step 2 exists.
- **Do not touch `vendor/qrcode.js` or `vendor/qrcode_UTF8.js`** — that IS the real
  encoder. "Dead code removal" applies only to the inline copy in `index.html`.
- **Each deletion swallows one adjacent blank line** (the trailing blank before the
  next kept function) so the file keeps exactly one blank line between sections.
  Leaving doubled blank lines fails the zero-insertions expectation reviewers get
  from `git diff --stat`.
- **The `let value = 1` inside Deletion A is IIFE-scoped and only used by the
  deleted init loop** (verified). The `value` parameter in `normalizeHex(value)`
  further down is a different scope — do not "rename to avoid conflicts" or touch it.
- **If ANY smoke check fails after the deletion, you deleted something live.**
  Revert (`git checkout -- index.html`) and re-anchor. Never adjust smoke
  assertions to make a deletion pass — that is gate-weakening, which AGENTS.md
  forbids.
- **`grep -c` prints `0` but exits with status 1 when there are no matches.** In the
  acceptance checks below, judge by the printed count, not the exit code, or you
  will misread success as failure.

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0 with `VERIFY OK`, same PASS count as the
   previous plan's run (41 if PLAN-payload-fixes landed) — zero assertion changes in
   this plan.
2. `git diff --name-only` lists exactly: `index.html`.
3. `git diff --stat` shows **deletions only** (expected ≈ 311 deleted lines, ±3;
   insertions must be 0).
4. Grep checks (judge printed count; see edge cases about exit codes):
   - `grep -cE "encodeQr|BitBuffer|ECC_CODEWORDS|ALIGNMENT_POSITIONS|rsRemainder|rsDivisor|gfMultiply|gfExp|scorePenalty|linePenalty|samePattern|addEccAndInterleave|drawFinder|drawAlignment|reserveFormat|drawVersion|maskBit|applyMask|drawFormat|drawQr" index.html` prints `0`
   - `grep -c "makeQr" index.html` prints `2`
   - `grep -c "qrcode(0, level)" index.html` prints `1`

**Suggested commit message:**

```
refactor: remove unreachable hand-rolled QR encoder and duplicate listeners
```
