# DewQRaft 1.1 — Release QA

Run against `/Applications/DewQRaft.app` installed from `release/DewQRaft-1.1.dmg`
on macOS 26.5.1, 2026-07-11.

**Rule: PASS only from actually performing the check — an honest FAIL committed is
worth more than a green lie.**

| # | Check | How | Pass condition | Result |
|---|-------|-----|----------------|--------|
| 1 | Install & first launch | Mount DMG, drag to /Applications, right-click → Open | Menu bar icon appears; no Dock icon | NOT RUN |
| 2 | Popup opens | Left-click menu bar icon | 560×520 popup with default QR and payload `https://dewflash.dev` | NOT RUN |
| 3 | Default URL scans | Scan preview with phone camera | Phone offers to open dewflash.dev | NOT RUN |
| 4 | Text + emoji | Text tab: `héllo 🚀 test` | Renders; scan shows the exact text | NOT RUN |
| 5 | Wi-Fi payload scans | Wi-Fi tab: real SSID/password | Phone offers to join that network | NOT RUN |
| 6 | Contact scans | Contact tab: name+phone+email | Phone offers a contact card showing the name | NOT RUN |
| 7 | Email scans with spaces | Email tab: subject `Team lunch Friday?` | Mail draft subject shows spaces, no `+` | NOT RUN |
| 8 | Phone scans | Phone tab: a real number | Phone offers to call it | NOT RUN |
| 9 | SMS scans | SMS tab: number + `Hello there` | Messages opens with body prefilled | NOT RUN |
| 10 | Copy PNG | Copy PNG → Preview → File → New from Clipboard | QR image pastes | NOT RUN |
| 11 | Save PNG flow | Save PNG… to Desktop | File saved; QR opens in Preview | NOT RUN |
| 12 | Cancel save | Save SVG… → Cancel | No file written | NOT RUN |
| 13 | Copy SVG | Copy SVG → paste in TextEdit (plain text) | Text starts `<svg xmlns=` | NOT RUN |
| 14 | Save SVG renders | Save SVG… → open in Safari | QR renders; no white hairlines between modules when zoomed | NOT RUN |
| 15 | Transparent background | Background: Transparent → Save PNG | Preview shows checkerboard behind modules | NOT RUN |
| 16 | Custom colours scan | Ink `#1c2430`, paper `#f4efe5` | Colours visible; phone still scans it | NOT RUN |
| 17 | Error correction | Correction: Very high | Code gets denser; still scans | NOT RUN |
| 18 | Export size honest | Size 2048 → Save PNG → Preview inspector | Image is 2048×2048 px | NOT RUN |
| 19 | Overflow handled | Paste ~3000 chars in Text | Buttons disable; status reads "Too long for one QR code" | NOT RUN |
| 20 | Reset | Change several fields/selects → Reset | Defaults restored; Wi-Fi security back to WPA/WPA2 | NOT RUN |
| 21 | Theme persists | Change accent+paper → quit → relaunch | Custom colours still applied | NOT RUN |
| 22 | Launch at Login | Right-click icon → toggle on, check System Settings → Login Items; toggle off | Item checkmark and System Settings agree in both directions | SKIPPED (plan not landed) |
| 23 | Quit | Right-click icon → Quit DewQRaft | App exits; icon disappears | NOT RUN |
| 24 | Fully offline | Turn Wi-Fi off; repeat rows 2, 4, 10 | Everything works identically | NOT RUN |

## Verdict

**DO-NOT-SHIP**

Physical QR scanning and native menu-bar UI QA could not be performed; see the
PLAN-save-panel-flow and PLAN-launch-at-login entries in `BLOCKERS.md`.
