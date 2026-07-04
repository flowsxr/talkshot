# Known Issues

Last updated: 2026-07-04

## Native app — Screen Recording permission (FIXED 2026-07-04)

**Symptom:** Talkshot toggle is ON in System Settings → Screen Recording, but:
- "Take Note" does nothing or shows permission dialog repeatedly
- Session folder stays empty (no `shot_001.png`)
- Status may say permission needed

**Root cause:** App was **ad-hoc signed** (`CODE_SIGN_IDENTITY="-"` in `build.sh`). Each rebuild produced a new code signature. macOS TCC (Transparency, Consent, Control) binds permission to signature + bundle ID, so the System Settings toggle could reference a **stale entry** from a previous build while the currently-running binary silently failed/re-prompted.

**Fix applied:** `build.sh` now signs with the real `Apple Development` certificate in the keychain instead of ad-hoc, deriving `DEVELOPMENT_TEAM` from the certificate's `OU` field at build time. Verified: after the fix, `codesign -dvvvv` shows `flags=0x0(none)` (not `adhoc`) and a stable `TeamIdentifier`, and this identity does not change across rebuilds — only the CDHash does (expected; TCC keys on team ID + bundle ID for properly-signed apps, not raw CDHash).

**Note on the Team ID:** the previous entry in this doc said the team ID was `5AD8QG2238` — that's actually the personal ID embedded in the certificate's Common Name (`Apple Development: Prasanth Sasikumar (5AD8QG2238)`), not the Team ID. The real Team ID is the certificate's `OU` field, `3U4384584Z`. `build.sh` now derives this programmatically instead of hardcoding either value.

**One-time step required after this fix:** the existing TCC grant was tied to the old ad-hoc signature, so it won't carry over to the newly-signed build. Remove Talkshot from Screen Recording (and Accessibility) once, reopen the freshly-built `dist/Talkshot.app`, and re-grant — same as the old manual workaround, but this is now a **one-time** step, not a per-rebuild ritual.

**Relevant files:**
- `native/build.sh` (signing identity + team ID derivation)
- `native/Talkshot/Services/CaptureService.swift`
- `native/Talkshot/Services/PermissionsService.swift`
- `native/project.yml`

---

## Native app — Hotkeys not working (OPEN)

**Symptom:** Ctrl+Option+N / Ctrl+Option+E do nothing.

**Causes:**
1. Accessibility not granted to Talkshot.app
2. Same ad-hoc signing mismatch as Screen Recording
3. User pressing wrong modifiers (Shift+Option+N vs Ctrl+Option+N)

**Workaround:** Use menu bar → **Take Note** / **Stop Recording** / **Finish Session**

**Relevant file:** `native/Talkshot/Services/HotkeyService.swift`

**Fix ideas:**
- CGEvent tap instead of NSEvent monitor
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) Swift package
- Signed app with stable Accessibility grant

---

## Native app — Mac Development signing failed

**Symptom:** xcodebuild error: `No signing certificate "Mac Development" found` for team `5AD8QG2238`.

User has `Apple Development: Prasanth Sasikumar (5AD8QG2238)` but not Mac Development. Need to create via Xcode → Settings → Accounts → Manage Certificates → Mac Development.

---

## Python — Built-in microphone silent (WORKAROUND IN PLACE)

**Symptom:** `sounddevice` records all zeros from "MacBook Pro Microphone".

**Workaround:** `MIC_DEVICE = "P.S.K"` (Continuity Camera). User selects this in System Settings → Sound → Input.

**Note:** `sounddevice` default input may not follow macOS System Settings default — must set device explicitly.

---

## Python — pyobjc-core 12 build failure on Python 3.9 (FIXED)

**Symptom:** `pip install pyobjc-framework-Quartz` fails building pyobjc-core with clang `-Wdefault-const-init-var-unsafe`.

**Fix:** Pin `pyobjc-framework-Quartz==11.1` in `requirements.txt`.

---

## Python — GlobalHotKeys may need Accessibility

**Symptom:** Hotkeys don't fire from Terminal/Cursor.

**Fix:** Grant Accessibility to Terminal/Cursor. Message: "This process is not trusted!"

---

## Native — Transcription quality

Native uses Apple **Speech** framework; Python uses **mlx-whisper**. Quality/latency may differ. User preferred mlx-whisper quality during Python testing.

To use whisper in native: would need whisper.cpp Core ML bundle or Python subprocess (not implemented).

---

## Investigation log

| Date | Finding |
|------|---------|
| 2026-07-04 | Python version works with Continuity mic + pyobjc 11.1 |
| 2026-07-04 | Native ad-hoc build: permission toggle ON but capture fails |
| 2026-07-04 | Migrated native capture from `screencapture` subprocess to ScreenCaptureKit |
| 2026-07-04 | Hotkeys changed from F9/F10 → ` ]` → Ctrl+Option+N/E |
| 2026-07-04 | Menu "Take Note" should work without Accessibility (verify after signing fix) |
| 2026-07-04 | Fixed ad-hoc signing: `build.sh` now signs with `Apple Development` cert, team ID derived from cert `OU` (`3U4384584Z`, not the `5AD8QG2238` previously recorded — that's the personal ID in the CN). Verified stable `TeamIdentifier` across two consecutive rebuilds. One-time re-grant of Screen Recording/Accessibility still needed since the old TCC entry was tied to the ad-hoc signature. |

---

## Files safe to ignore / gitignore

- `native/build/` — Xcode derived data
- `native/dist/` — built .app (rebuild with `./build.sh`)
- `~/Desktop/talkshot-session-*/` — user session output
