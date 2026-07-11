# PLAN-payload-fixes — Correct payload encoding, error status, reset

**Rank:** 3 of 6.
**Dependencies:** run AFTER PLAN-verify. Independent of PLAN-save-panel-flow and
PLAN-launch-at-login. Must run BEFORE PLAN-dead-code.
**Effort:** Small-Medium (six small verified fixes + smoke assertion updates).
**Files touched:** `index.html`, `scripts/smoke-test.swift`. **Nothing else.**
**Both files must change in the SAME commit** — the smoke pins payload strings, so
changing one without the other fails the gate by design.

## Goal

A QR app has exactly one job: codes that scan into the right action. Five confirmed
defects (all verified by reading `index.html` at HEAD and, where noted, by running
the code) break or degrade that promise:

1. **Email payloads encode spaces as `+`** — `mailPayload()` uses `URLSearchParams`,
   which implements HTML form encoding. RFC 6068 (mailto URIs) requires
   percent-encoding; `+` means a literal plus. Verified by execution: subject
   `Team lunch Friday?` becomes `subject=Team+lunch+Friday%3F`, so spec-following
   mail clients show "Team+lunch+Friday?".
2. **Oversized content shows the literal status "undefined"** — the vendor library
   throws raw strings (`throw 'code length overflow. ('` — `vendor/qrcode.js`), and
   `render()`'s catch does `setStatus(error.message, true)`; a string has no
   `.message`.
3. **vCards are below spec** — vCard 3.0 (RFC 2426) requires an `N:` property and
   CRLF line endings. `contactPayload()` emits neither; lenient scanners cope, strict
   contact importers drop the name or the whole card.
4. **Phone payloads keep inner spaces** — `qrPayload()`'s `"phone"` case only trims,
   so `tel:+65 9123 4567` embeds spaces (invalid in a URI). The `"sms"` case already
   strips whitespace; phone should match.
5. **Reset skips the Wi-Fi security dropdown** — `reset()` clears inputs/textareas
   and explicitly resets three selects (`errorLevel`, `exportSize`,
   `backgroundMode`) but not `wifiSecurity`, so Reset leaves WEP/None selected.

Plus one export-quality fix: **SVG modules get hairline seams** when scaled, because
`svgString()` emits fractional rect coordinates; `shape-rendering="crispEdges"` is
the standard one-attribute cure.

## Steps — `index.html`

All anchors are exact strings verified to exist at HEAD. Match text, not line numbers.

### Step 0 — Gate green before starting

```sh
/bin/zsh scripts/verify.sh
```

If this fails before you change anything: STOP and report — do not improvise.

### Step 1 — Percent-encode mailto (RFC 6068)

Find:

```js
      function mailPayload() {
        const to = elements.emailTo.value.trim();
        const params = new URLSearchParams();
        if (elements.emailSubject.value.trim()) params.set("subject", elements.emailSubject.value.trim());
        if (elements.emailBody.value.trim()) params.set("body", elements.emailBody.value.trim());
        return to || params.toString() ? `mailto:${to}${params.toString() ? `?${params}` : ""}` : "";
      }
```

Replace with:

```js
      function mailPayload() {
        const to = elements.emailTo.value.trim();
        const parts = [];
        if (elements.emailSubject.value.trim()) parts.push(`subject=${encodeURIComponent(elements.emailSubject.value.trim())}`);
        if (elements.emailBody.value.trim()) parts.push(`body=${encodeURIComponent(elements.emailBody.value.trim())}`);
        const query = parts.join("&");
        return to || query ? `mailto:${to}${query ? `?${query}` : ""}` : "";
      }
```

### Step 2 — vCard: add `N:` and use CRLF

In `contactPayload()`, find:

```js
        const lines = ["BEGIN:VCARD", "VERSION:3.0"];
        if (name) lines.push(`FN:${escapeVcard(name)}`);
```

Replace with:

```js
        const lines = ["BEGIN:VCARD", "VERSION:3.0"];
        if (name) {
          lines.push(`N:${escapeVcard(name)};;;;`);
          lines.push(`FN:${escapeVcard(name)}`);
        }
```

Then in the same function find:

```js
        return lines.join("\n");
```

Replace with:

```js
        return lines.join("\r\n");
```

### Step 3 — Strip whitespace from phone numbers

In `qrPayload()`, find:

```js
          case "phone":
            return elements.phoneNumber.value.trim() ? `tel:${elements.phoneNumber.value.trim()}` : "";
```

Replace with:

```js
          case "phone": {
            const number = elements.phoneNumber.value.replace(/\s+/g, "");
            return number ? `tel:${number}` : "";
          }
```

### Step 4 — Human-readable QR errors

Directly ABOVE the line `function render() {`, insert:

```js
      function qrErrorMessage(error) {
        const raw = String(error && error.message ? error.message : error);
        return raw.includes("code length overflow") ? "Too long for one QR code" : raw;
      }

```

Then inside `render()`'s catch block, find:

```js
          setStatus(error.message, true);
```

Replace with:

```js
          setStatus(qrErrorMessage(error), true);
```

### Step 5 — Reset the Wi-Fi security dropdown

In `reset()`, find:

```js
        activeMode = "text";
        elements.errorLevel.value = "M";
```

Replace with:

```js
        activeMode = "text";
        elements.wifiSecurity.value = "WPA";
        elements.errorLevel.value = "M";
```

### Step 6 — Crisp SVG edges

In `svgString()`, find:

```js
        return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${bg}<g fill="${elements.foreground.value}">${rects}</g></svg>`;
```

Replace with:

```js
        return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" shape-rendering="crispEdges">${bg}<g fill="${elements.foreground.value}">${rects}</g></svg>`;
```

## Steps — `scripts/smoke-test.swift` (same commit)

These update the pinned baseline assertions to the new correct behavior, and add
coverage for the new fixes. The strings below are the literal file text — the doubled
backslashes are correct (Swift string escaping), do not "simplify" them.

### Step 7 — Email expectation

Find:

```
  const mailExpected = "mailto:a@b.c?subject=Team+lunch+Friday%3F&body=See+you+%26+Bob";
```

Replace with:

```
  const mailExpected = "mailto:a@b.c?subject=Team%20lunch%20Friday%3F&body=See%20you%20%26%20Bob";
```

### Step 8 — vCard expectation

Find:

```
  const vcardExpected = [
    "BEGIN:VCARD",
    "VERSION:3.0",
    "FN:Ada Lovelace",
    "TEL:+65 9123 4567",
    "EMAIL:ada@lovelace.dev",
    "END:VCARD"
  ].join("\\n");
```

Replace with:

```
  const vcardExpected = [
    "BEGIN:VCARD",
    "VERSION:3.0",
    "N:Ada Lovelace;;;;",
    "FN:Ada Lovelace",
    "TEL:+65 9123 4567",
    "EMAIL:ada@lovelace.dev",
    "END:VCARD"
  ].join("\\r\\n");
```

### Step 9 — Phone expectation

Find:

```
  check("phone payload", payload() === "tel:+65 9123 4567", payload());
```

Replace with:

```
  check("phone payload", payload() === "tel:+6591234567", payload());
```

### Step 10 — Overflow message assertion

Find:

```
  check("overflow shows error", statusIsError() && buttonsDisabled(), status());
```

Replace with:

```
  check("overflow shows error", statusIsError() && buttonsDisabled(), status());
  check("overflow message friendly", status() === "Too long for one QR code", status());
```

### Step 11 — Reset covers the Wi-Fi security dropdown

Find:

```
  // 10. Reset restores defaults
  tab("wifi");
  $("resetButton").click();
```

Replace with:

```
  // 10. Reset restores defaults
  tab("wifi");
  setSelect($("wifiSecurity"), "WEP");
  $("resetButton").click();
```

Then find:

```
  check("reset re-enables actions", !buttonsDisabled());
```

Replace with:

```
  check("reset re-enables actions", !buttonsDisabled());
  check("reset restores wifi security", $("wifiSecurity").value === "WPA", $("wifiSecurity").value);
```

### Step 12 — SVG crispEdges assertion (Swift code, Phase B)

Find:

```swift
    check("bridge copySvg is svg", text.hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\"") && text.contains("<rect"))
```

Replace with:

```swift
    check("bridge copySvg is svg", text.hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\"") && text.contains("<rect"))
    check("bridge copySvg crisp edges", text.contains("shape-rendering=\"crispEdges\""))
```

### Step 13 — Run the gate

```sh
/bin/zsh scripts/verify.sh
```

Every check must PASS, including the four updated and three added ones.

## Edge cases a weaker model would miss

- **index.html and smoke-test.swift land in ONE commit.** The smoke deliberately pins
  payload strings; splitting the change across commits leaves a commit where the gate
  is red, which violates the AGENTS.md failure protocol.
- **In smoke-test.swift, `\\r\\n` and `\\n` are FILE text, not the runtime string.**
  Swift consumes one backslash level before the JavaScript engine sees the code. If
  you write `\r\n` (single backslashes) in the Swift file, the Swift string itself
  contains real CR/LF characters inside a JS string literal → JavaScript syntax error
  → every Phase A check fails at once.
- **`N:` must come BEFORE `FN:`** (conventional vCard property order) — the smoke
  assertion encodes that order. Emitting it after FN "works" in some scanners but
  fails the gate.
- **The `;;;;` after the escaped name must stay OUTSIDE `escapeVcard(...)`.** They are
  the four empty N components (given/additional/prefix/suffix). `escapeVcard` escapes
  semicolons, so moving them inside produces `N:Ada\;\;\;\;` — wrong.
- **The braces in `case "phone": { ... }` are required**, not style: `const` directly
  inside a `case` leaks into the whole switch scope; a block keeps it local and safe
  if any other case ever declares the same name.
- **Do not "fix" `smsPayload()` or `escapeWifi()`** — both were verified correct
  (`sms:` already strips whitespace and percent-encodes; Wi-Fi escaping covers
  `\ ; , " :` per the de-facto WIFI: syntax). Touching them risks breaking passing
  assertions for zero gain.
- **`payloadPreview` roundtrips `\r\n` exactly** — the app sets `textContent` and the
  smoke reads `textContent` back; no HTML parsing normalizes the CR. That is why the
  CRLF assertion is reliable.
- **Why `+` is a real bug and not pedantry:** `URLSearchParams` implements
  `application/x-www-form-urlencoded` (spaces → `+`). RFC 6068 mailto URIs use RFC
  3986 percent-encoding, where `+` is a literal plus sign. Mail clients that follow
  the spec render "Team+lunch+Friday?" in the subject line.
- **`qrErrorMessage` must handle BOTH string throws and Error objects.** The vendor
  lib throws strings today, but `makeQr`/canvas code could throw real Errors; the
  `String(error && error.message ? error.message : error)` form covers both. Do not
  reduce it to `String(error)` (prints "Error: …" prefix) or `error.message` (the
  original bug).

## Acceptance criteria

1. `/bin/zsh scripts/verify.sh` exits 0 with `VERIFY OK` (41 smoke PASS lines: the
   original 38, plus `overflow message friendly`, `reset restores wifi security`,
   and `bridge copySvg crisp edges` — with 4 assertions updated in place).
2. `git diff --name-only` lists exactly: `index.html`, `scripts/smoke-test.swift`.
3. Mechanical spot checks, all from repo root:
   - `grep -c "URLSearchParams" index.html` → `0`
   - `grep -c "qrErrorMessage" index.html` → `2`
   - `grep -c "crispEdges" index.html` → `1`
   - `grep -c 'lines.join' index.html` → `1`
4. Manual (only if an iPhone is at hand — otherwise this is re-checked in
   RELEASE-QA): scan an Email QR with subject "Team lunch Friday?" — the mail draft
   shows spaces, not `+` signs. Scan a Contact QR — the contact card shows the name.

**Suggested commit message:**

```
fix: correct mailto/vcard/tel payload encoding, error status, reset
```
