# Architecture

## Overview

Talkshot captures **visual context** (screenshot + cursor position) and **spoken context** (voice note → transcript) into a timestamped session folder.

```
┌─────────────────────────────────────────────────────────┐
│  User triggers note (hotkey or menu)                    │
└────────────────────────┬────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────┐
│  1. Get mouse position (Quartz / CGEvent)               │
│  2. Screenshot main display                             │
│  3. Draw red circle at cursor, save crop                │
│  4. Start microphone recording                          │
└────────────────────────┬────────────────────────────────┘
                         ▼ (user stops)
┌─────────────────────────────────────────────────────────┐
│  5. Stop recording                                      │
│  6. Transcribe audio                                    │
│  7. Append SessionEntry → notes.json + notes.md         │
└─────────────────────────────────────────────────────────┘
```

## Python implementation (`talkshot.py`)

Single-process script. All logic in one file.

| Component | Implementation |
|-----------|----------------|
| Hotkeys | `pynput.keyboard.GlobalHotKeys` |
| Mouse position | `Quartz.CGEventGetLocation` |
| Screenshot | `screencapture -x -D 1` subprocess |
| Image annotate | `PIL` — red ellipse + crop |
| Audio | `sounddevice` InputStream @ 16 kHz mono |
| Transcription | `mlx-whisper` (Apple Silicon) |
| Output | JSON + Markdown to Desktop |

**State variables:** `entries`, `frames`, `recording`, `count`, `pending`, `stream`

## Native implementation (`native/Talkshot/`)

Menu bar app (`LSUIElement=true`, no Dock icon). SwiftUI `MenuBarExtra`.

| Layer | File | Role |
|-------|------|------|
| UI | `TalkshotApp.swift` | Menu bar menu items |
| State | `AppState.swift` | `@MainActor` observable session state |
| Model | `SessionEntry.swift` | Codable entry matching Python JSON schema |
| Capture | `CaptureService.swift` | ScreenCaptureKit `SCScreenshotManager` |
| Audio | `AudioRecorder.swift` | `AVAudioEngine` → temp WAV |
| Mic select | `AudioDeviceSelector.swift` | CoreAudio device by name |
| Transcribe | `TranscriptionService.swift` | `SFSpeechRecognizer` on-device |
| Hotkeys | `HotkeyService.swift` | `NSEvent` global/local monitors |
| Permissions | `PermissionsService.swift` | TCC checks, open System Settings |

**Build system:** XcodeGen (`project.yml`) → `Talkshot.xcodeproj` → `build.sh` → `dist/Talkshot.app`

## Session entry schema

Both implementations produce compatible JSON:

```json
{
  "index": 1,
  "time": "2026-07-04T13:21:45",
  "mouse_points": [1689, 532],
  "mouse_pixels": [1689, 532],
  "screenshot": "shot_001.png",
  "crop": "crop_001.png",
  "note": "transcribed text here"
}
```

## Retina / coordinate handling

- Mouse position from Quartz is in **screen points** (origin top-left)
- Screenshot is in **pixels** — scale = `imageWidth / displayBounds.width`
- Circle and crop math applies scale factor (see `talkshot.py` lines 126–141, `CaptureService.saveAnnotated`)

## Permissions (macOS TCC)

| Permission | Python host | Native app |
|------------|-------------|------------|
| Screen Recording | Terminal/Cursor | Talkshot.app |
| Microphone | Terminal/Cursor | Talkshot.app |
| Accessibility | Terminal/Cursor | Talkshot.app |
| Speech Recognition | N/A | Talkshot.app |

TCC entries bind to **code signature + bundle ID**. Ad-hoc signed rebuilds invalidate existing grants.

## Hotkey design

Current binding (both implementations):

- **Note toggle:** Ctrl + Option + N
- **Finish session:** Ctrl + Option + E

Chosen because user lacks function keys and `\` / `]` conflict with editors.

Native hotkeys require Accessibility. Menu actions work without it.
