# Setup

## Python (working path)

### Requirements

- macOS 12+
- Python 3.9+ (3.11+ recommended for easier pyobjc installs)
- Apple Silicon for `mlx-whisper` (Intel: use `openai-whisper` instead)

### Install

```bash
cd talkshot
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt
```

**Python 3.9 note:** `requirements.txt` pins `pyobjc-framework-Quartz==11.1` because pyobjc-core 12.x has no cp39 wheels and fails to compile on Xcode 26.

### Run

```bash
python3 talkshot.py
```

### Permissions

Grant the **terminal app you run from** (Terminal, iTerm, or Cursor):

1. **Screen Recording** — screenshots
2. **Microphone** — voice notes
3. **Accessibility** — global hotkeys

### Microphone setup

User's built-in MacBook mic returned zero audio. Working config:

```python
MIC_DEVICE = "P.S.K"  # Continuity Camera mic
```

List devices:

```bash
python3 -c "import sounddevice as sd; print(sd.query_devices())"
```

---

## Native app

### Requirements

- macOS 14+
- Xcode 15+ (user has Xcode 26.6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Build

```bash
cd native
chmod +x build.sh
./build.sh
```

Output: `native/dist/Talkshot.app`

### Install (recommended)

```bash
cp -R native/dist/Talkshot.app /Applications/
open /Applications/Talkshot.app
```

Always run the **same installed copy** — don't mix Xcode-run builds with dist builds for permission testing.

### Permissions

Grant **Talkshot** (the .app, not Terminal):

| Setting | Location |
|---------|----------|
| Screen Recording | Privacy & Security → Screen Recording |
| Microphone | Privacy & Security → Microphone |
| Accessibility | Privacy & Security → Accessibility |
| Speech Recognition | Privacy & Security → Speech Recognition |

### After granting Screen Recording

**Quit Talkshot completely, then reopen.** macOS does not apply screen capture permission until restart.

### After each native rebuild

Ad-hoc signing changes the binary identity. Reset permissions:

1. System Settings → Screen Recording → remove Talkshot (−)
2. Open the new `dist/Talkshot.app`
3. Take Note → allow if prompted
4. Quit → reopen → test again

### Proper signing (recommended fix)

Ad-hoc builds cause TCC issues. For stable permissions:

1. Open `native/Talkshot.xcodeproj` in Xcode
2. Signing & Capabilities → enable **Automatically manage signing**
3. Select your Apple ID team
4. Create/download **Mac Development** certificate if missing
5. Build and install to `/Applications`

User has Apple Development cert (`5AD8QG2238`) but build failed looking for "Mac Development" cert.

---

## Hotkeys

| Action | Shortcut |
|--------|----------|
| Start/stop note | **Ctrl + Option + N** (lowercase n, no Shift) |
| Finish session | **Ctrl + Option + E** |

Native app also has menu items that work without hotkeys.

---

## Output location

```
~/Desktop/talkshot-session-<YYYYMMDD-HHMMSS>/
```

Created at session start. Python writes `notes.json`/`notes.md` on finish; native writes after each note and on finish.
