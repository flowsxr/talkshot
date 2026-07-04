# AGENTS.md — Talkshot

> **Read this first.** This file orients AI coding agents on project state, priorities, and constraints.

## Mission

Build a macOS tool for **screenshot + voice note** capture during coding/research sessions. Output feeds Claude or other LLMs (cursor position + screen context + spoken note).

## Repository map

```
talkshot/
├── talkshot.py              # WORKING Python implementation (single file)
├── requirements.txt         # Python deps (note pyobjc==11.1 pin for Python 3.9)
├── README.md                # User-facing overview
├── AGENTS.md                # This file
├── docs/
│   ├── ARCHITECTURE.md      # Design + data flow
│   ├── SETUP.md             # Install & permissions
│   └── KNOWN_ISSUES.md      # Open bugs — READ BEFORE FIXING NATIVE APP
└── native/
    ├── build.sh             # Build script → dist/Talkshot.app
    ├── project.yml          # XcodeGen spec
    ├── Talkshot/            # Swift source
    │   ├── TalkshotApp.swift       # @main MenuBarExtra UI
    │   ├── AppState.swift          # Session state, capture orchestration
    │   ├── Models/SessionEntry.swift
    │   └── Services/
    │       ├── CaptureService.swift      # ScreenCaptureKit screenshots
    │       ├── AudioRecorder.swift       # AVAudioEngine mic capture
    │       ├── AudioDeviceSelector.swift # CoreAudio mic picker
    │       ├── TranscriptionService.swift # Apple Speech framework
    │       ├── HotkeyService.swift       # NSEvent global hotkeys
    │       └── PermissionsService.swift  # TCC / permission helpers
    ├── dist/Talkshot.app      # Built app (gitignored)
    └── build/                 # Xcode artifacts (gitignored)
```

## Which implementation to work on

| Goal | Work in |
|------|---------|
| Fix something **now** for the user | `talkshot.py` — it works end-to-end |
| Menu bar app, login item, proper .app | `native/` |
| Better transcription quality | Python (`mlx-whisper`) or native (Speech framework) |

**Do not delete or break `talkshot.py`** while fixing native. User relies on Python version.

## User environment (observed)

- **macOS 26.5**, Apple Silicon, Xcode 26.6
- **Python 3.9.6** at `/usr/bin/python3` (system/Xcode Python)
- **Built-in MacBook mic** returns silence to Python/sounddevice — user uses **Continuity Camera mic** (`P.S.K Microphone`)
- pyobjc-core **12.x fails to build** on Python 3.9 — must pin `pyobjc-framework-Quartz==11.1`
- User has **no function keys** (F9/F10) — hotkeys are **Ctrl+Option+N/E**

## Core user flow

```
Ctrl+Option+N (or menu "Take Note")
  → screenshot main display
  → draw red circle at cursor
  → save crop around cursor
  → start mic recording

Ctrl+Option+N again (or "Stop Recording")
  → stop mic
  → transcribe audio
  → append to session entries
  → write notes.json / notes.md

Ctrl+Option+E (or "Finish Session")
  → save all notes
  → open session folder
  → reset to a fresh session (native, stays running) or exit (python)
```

## Native app — status

Ad-hoc signing / Screen Recording permission-loop / hotkey-Accessibility issues that used to live here are **fixed** — see `docs/KNOWN_ISSUES.md` for the fix history. `build.sh` signs with a real `Apple Development` cert (stable across rebuilds); `build-release.sh` + `notarize.sh` produce a **Developer ID**-signed, notarized, stapled build for distribution outside this machine.

## Build commands

```bash
# Python
python3 -m pip install -r requirements.txt
python3 talkshot.py

# Native (local dev — Apple Development signing)
cd native && ./build.sh
# Output: native/dist/Talkshot.app

# Native (distribution — Developer ID signing + notarization)
cd native && ./build-release.sh && ./notarize.sh
# Output: native/dist-release/Talkshot.dmg
```

## Testing checklist

After native changes:

1. Quit any running Talkshot (`pkill -x Talkshot`)
2. Remove Talkshot from System Settings → Screen Recording
3. Open `native/dist/Talkshot.app` (not Xcode run, unless debugging)
4. Grant Screen Recording → **quit app → reopen**
5. Menu → Take Note → verify `shot_001.png` on Desktop session folder
6. Stop Recording → verify transcript in `notes.json`
7. Test Ctrl+Option+N after granting Accessibility

After Python changes:

1. `python3 talkshot.py`
2. Ctrl+Option+N twice with speech
3. Check Desktop session folder

## Code conventions

- **Python:** single-file script, minimal deps, config as top-level constants
- **Swift:** macOS 14+, SwiftUI MenuBarExtra, services as enums/classes under `Services/`
- **Don't over-engineer** — user wants a small utility, not a framework
- **Don't add markdown/docs** unless asked (except this agent-oriented set)

## Key config locations

| Setting | Python | Native |
|---------|--------|--------|
| Hotkeys | `talkshot.py` → `HOTKEYS` | `HotkeyService.swift` → `HotkeyConfig` |
| Microphone | `MIC_DEVICE = "P.S.K"` | `AudioDeviceSelector.preferredDeviceName` |
| Whisper model | `WHISPER_MODEL` | N/A (uses Speech framework) |
| Crop size | `CROP_W`, `CROP_H` | `CaptureService` private constants |
| Output dir | `~/Desktop/talkshot-session-*` | `AppState.sessionFolder` |

## What agents should NOT do

- Force-push to main
- Commit secrets or `.env` files
- Remove Python implementation while native is broken
- Use `screencapture` subprocess in native (already migrated to ScreenCaptureKit — don't revert without reason)
- Assume Screen Recording toggle ON means permission works (signature mismatch)

## Suggested next steps for native fix

1. Enable **Xcode automatic signing** with user's Apple Development team (team ID `5AD8QG2238` — Mac Development cert may be missing; user may need to create one in Xcode → Settings → Accounts)
2. Install signed build to `/Applications/Talkshot.app` only
3. Reset TCC, grant once, verify `CGPreflightScreenCaptureAccess()` returns true
4. Add unit/integration test: capture screenshot to temp file on launch (debug menu item)
5. Consider **CGEventTap** or `KeyboardShortcuts` Swift package if NSEvent monitors remain unreliable

## Questions to ask the user if blocked

- Are you running from `dist/Talkshot.app`, Xcode, or `/Applications`?
- Did you remove + re-add Talkshot in Screen Recording after last rebuild?
- Did you quit and reopen after granting permissions?
- Which mic is selected in System Settings → Sound → Input?
