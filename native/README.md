# Talkshot Native App

Swift/SwiftUI menu bar application. See root [README.md](../README.md) and [AGENTS.md](../AGENTS.md) for full project context.

## Status

**Recommended path.** Proper macOS permissions (Screen Recording, Microphone, Accessibility), a real app icon, and Developer ID signing + notarization for distribution. See [docs/KNOWN_ISSUES.md](../docs/KNOWN_ISSUES.md) for fix history.

## Build

```bash
./build.sh            # local dev build, Apple Development signing
./build-release.sh    # Developer ID signing, hardened runtime
./notarize.sh          # submit to Apple, staple ticket, package as .dmg
```

Requires Xcode 15+ and XcodeGen (`brew install xcodegen`). `build-release.sh`/`notarize.sh` require a paid Apple Developer Program membership and a `Developer ID Application` certificate.

## Source layout

```
Talkshot/
├── TalkshotApp.swift          # Menu bar UI entry point
├── AppState.swift             # Session orchestration
├── Models/SessionEntry.swift  # JSON schema
└── Services/
    ├── CaptureService.swift       # ScreenCaptureKit
    ├── AudioRecorder.swift        # AVAudioEngine
    ├── AudioDeviceSelector.swift  # Mic by name
    ├── TranscriptionService.swift # Speech framework
    ├── HotkeyService.swift        # Ctrl+Option+N/E
    └── PermissionsService.swift   # TCC helpers
```

## Configuration

| File | Setting |
|------|---------|
| `Services/AudioDeviceSelector.swift` | `preferredDeviceName = nil` (system default input) |
| `Services/HotkeyService.swift` | `HotkeyConfig.note` / `.finish` |
| `Services/CaptureService.swift` | Crop size constants |

## Bundle ID

`com.talkshot.app`

## Entitlements

Non-sandboxed (`com.apple.security.app-sandbox = false`), audio input enabled.
