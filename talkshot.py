#!/usr/bin/env python3
"""
talkshot.py - push-to-talk visual notes for macOS

Project docs: README.md, AGENTS.md (for AI agents), docs/

Flow:
  Press Ctrl+Option+N  -> screenshot + start/stop talking
  Press Ctrl+Option+E  -> finish session

Output: ~/Desktop/claude-session-<timestamp>/
  shot_001.png ...  full screenshot with cursor position circled in red
  crop_001.png ...  zoomed region around the cursor (great to feed to Claude)
  notes.md / notes.json  transcript + mouse coords + timestamps per shot

Setup (one time):
  pip install sounddevice numpy pynput pillow pyobjc-framework-Quartz mlx-whisper
  System Settings > Privacy & Security, grant your Terminal (or IDE):
    - Screen Recording  (for screencapture of other apps)
    - Microphone
    - Accessibility / Input Monitoring  (for the global hotkey)

Notes:
  - mlx-whisper is fast on Apple Silicon. On Intel Macs use
    `pip install openai-whisper` and swap the transcribe call (see below).
  - Change HOTKEY / QUIT_KEY below if these clash with your editor's shortcuts.
    Examples: keyboard.Key.space, keyboard.KeyCode.from_char('n'),
    keyboard.Key.f13 (Fn+1 on many MacBooks).
  - Captures the main display. For a second monitor change the -D value.
"""

import datetime
import json
import os
import subprocess

import numpy as np
import sounddevice as sd
from PIL import Image, ImageDraw
from pynput import keyboard
import Quartz

HOTKEY_LABEL = "Ctrl+Option+N"
QUIT_KEY_LABEL = "Ctrl+Option+E"

NOTE_HOTKEY = keyboard.HotKey(
    keyboard.HotKey.parse("<ctrl>+<alt>+n"),
    lambda: stop_capture() if recording else start_capture(),
)
QUIT_HOTKEY = keyboard.HotKey(
    keyboard.HotKey.parse("<ctrl>+<alt>+e"),
    finish,
)
HOTKEYS = keyboard.GlobalHotKeys({
    "<ctrl>+<alt>+n": lambda: stop_capture() if recording else start_capture(),
    "<ctrl>+<alt>+e": finish,
})
RATE = 16000                  # whisper expects 16 kHz mono
CROP_W, CROP_H = 800, 500     # size (in screen points) of the zoomed crop
WHISPER_MODEL = "mlx-community/whisper-base-mlx"  # try whisper-small-mlx for accuracy
# Partial device name or index. None = sounddevice default (often not macOS Sound setting).
MIC_DEVICE = "P.S.K"  # Continuity Camera mic; use None for system default

session_id = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
OUT = os.path.expanduser(f"~/Desktop/claude-session-{session_id}")
os.makedirs(OUT, exist_ok=True)

entries = []
frames = []
stream = None
recording = False
count = 0
pending = {}


def resolve_input_device():
    if MIC_DEVICE is None:
        return sd.default.device[0]
    if isinstance(MIC_DEVICE, int):
        return MIC_DEVICE
    needle = MIC_DEVICE.lower()
    for i, d in enumerate(sd.query_devices()):
        if d["max_input_channels"] > 0 and needle in d["name"].lower():
            return i
    raise RuntimeError(
        f"Microphone matching '{MIC_DEVICE}' not found. "
        "Run: python3 -c \"import sounddevice as sd; print(sd.query_devices())\""
    )


MIC_INDEX = resolve_input_device()
MIC_NAME = sd.query_devices(MIC_INDEX)["name"]


def mouse_pos():
    """Global cursor position in screen points, origin top-left."""
    event = Quartz.CGEventCreate(None)
    p = Quartz.CGEventGetLocation(event)
    return p.x, p.y


def take_screenshot(path):
    # -x = no sound, -D 1 = main display
    result = subprocess.run(["screencapture", "-x", "-D", "1", path], check=False)
    if result.returncode != 0:
        raise RuntimeError(
            "Screenshot failed — grant Screen Recording to Terminal/Cursor in "
            "System Settings > Privacy & Security > Screen Recording"
        )


def audio_callback(indata, n, t, status):
    frames.append(indata.copy())


def start_capture():
    global recording, stream, frames, count, pending
    count += 1
    mx, my = mouse_pos()

    shot_name = f"shot_{count:03d}.png"
    crop_name = f"crop_{count:03d}.png"
    shot_path = os.path.join(OUT, shot_name)
    take_screenshot(shot_path)

    img = Image.open(shot_path)
    # Retina scaling: screenshot pixels vs screen points
    bounds = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
    scale = img.width / bounds.size.width
    px, py = mx * scale, my * scale

    # circle the cursor position
    draw = ImageDraw.Draw(img)
    r = 18 * scale
    draw.ellipse([px - r, py - r, px + r, py + r],
                 outline="red", width=max(2, int(4 * scale)))
    img.save(shot_path)

    # zoomed crop around the cursor for tighter context
    cw, ch = CROP_W * scale, CROP_H * scale
    left = min(max(0, px - cw / 2), img.width - cw)
    top = min(max(0, py - ch / 2), img.height - ch)
    img.crop((left, top, left + cw, top + ch)).save(os.path.join(OUT, crop_name))

    pending = {
        "index": count,
        "time": datetime.datetime.now().isoformat(timespec="seconds"),
        "mouse_points": [round(mx), round(my)],
        "mouse_pixels": [round(px), round(py)],
        "screenshot": shot_name,
        "crop": crop_name,
    }

    frames = []
    stream = sd.InputStream(
        samplerate=RATE, channels=1, callback=audio_callback, device=MIC_INDEX
    )
    stream.start()
    recording = True
    print(f"[{count}] shot taken at ({round(mx)}, {round(my)}), recording... {HOTKEY_LABEL} to stop")


def stop_capture():
    global recording, stream
    stream.stop()
    stream.close()
    recording = False

    audio = (np.concatenate(frames, axis=0).flatten().astype(np.float32)
             if frames else np.zeros(1, dtype=np.float32))

    print("    transcribing...")
    import mlx_whisper
    result = mlx_whisper.transcribe(audio, path_or_hf_repo=WHISPER_MODEL)
    # Intel Mac alternative:
    #   import whisper; model = whisper.load_model("base")
    #   result = model.transcribe(audio)
    text = result["text"].strip()

    pending["note"] = text
    entries.append(dict(pending))
    print(f"    \"{text}\"")


def finish():
    if recording:
        stop_capture()
    with open(os.path.join(OUT, "notes.json"), "w") as f:
        json.dump(entries, f, indent=2)
    with open(os.path.join(OUT, "notes.md"), "w") as f:
        f.write(f"# Session {session_id}\n\n")
        for e in entries:
            f.write(f"## Note {e['index']} ({e['time']})\n")
            f.write(f"Cursor at {e['mouse_points']} (screen points)\n\n")
            f.write(f"![full]({e['screenshot']})\n\n")
            f.write(f"![zoom]({e['crop']})\n\n")
            f.write(f"> {e['note']}\n\n")
    print(f"\nSaved {len(entries)} notes to {OUT}")


def on_press(key):
    pass


def on_release(key):
    if key == keyboard.Key.esc:
        return False


print(f"Session folder: {OUT}")
print(f"Microphone: {MIC_NAME}")
print(f"{HOTKEY_LABEL} = take shot + start/stop talking, {QUIT_KEY_LABEL} = finish session\n")
HOTKEYS.start()
try:
    with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
        listener.join()
finally:
    HOTKEYS.stop()
