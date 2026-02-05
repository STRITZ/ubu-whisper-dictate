# CLAUDE.md - Whisper Dictate GUI

## Project Overview

Whisper Dictate is a lightweight, single-purpose voice-to-text dictation application for Ubuntu Linux. The user opens the application, clicks a record button (or triggers via hotkey), speaks, stops recording, and the transcribed text is automatically pasted into whatever field/window had focus before the app was activated. All transcription runs locally via whisper.cpp -- no internet or API keys required.

IMPORTANT - The application is designed to hover above all active windows. Never, when opened should the application dissapear from the view.

## Architecture

**Monolithic single-file application.** The entire app is one Python script (`whisper-dictate-gui`, 318 lines) with no modules or packages. This is intentional -- keep it simple.

### End-to-End Flow

**Hotkey mode (Alt double-tap):**
1. User places cursor in target text field (terminal, browser, editor, etc.)
2. User double-taps Alt to start recording -- target window keeps focus
3. `arecord` captures audio to `/tmp/dictation_audio.wav` (16kHz, mono, WAV)
4. User double-taps Alt again to stop -- button turns yellow (processing)
5. `whisper-cli` transcribes the audio using the `ggml-tiny.en.bin` model
6. Output is checked against a hallucination filter (common false positives from silence)
7. `ydotool type` injects text directly into the focused window (no clipboard, no Alt+Tab)
8. UI resets to "Ready" state

**Button-click mode:**
1. User places cursor in target text field, then clicks the mic button (steals focus)
2-6. Same as hotkey mode
7. `ydotool` sends Alt+Tab to return to the previous window
8. `ydotool type` injects text directly into the focused window
9. UI resets to "Ready" state

### IPC Toggle System

The app runs a Unix socket server at `/tmp/whisper-dictate.sock`. External processes can send a `"toggle"` message to start/stop recording without raising the window. This enables hotkey integration:

```bash
whisper-dictate-gui --toggle
```

If no instance is running, `--toggle` exits with an error. The intent is for users to bind this command to a system keyboard shortcut (e.g., via GNOME Settings). The Alt double-tap hotkey is a design goal but is not yet implemented natively in the app -- it requires external system-level shortcut configuration.

## Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| GUI | GTK 4.0 (PyGObject) | Window, button, status label, toggle switch |
| Audio capture | `arecord` (ALSA) | Records microphone to WAV |
| Transcription | whisper.cpp (`whisper-cli`) | Local speech-to-text via tiny.en model |
| Clipboard | `wl-copy` / `wl-paste` | Wayland clipboard operations |
| Input simulation | `ydotool` | Sends keystrokes (Alt+Tab, Ctrl+V) on Wayland |
| Window detection | `xdotool` / `xprop` | Identifies focused window for terminal detection |
| Language | Python 3.10+ | No pip dependencies -- only system packages and stdlib |
| Session | Wayland (primary), X11 (fallback) | Ubuntu 22.04+ default session |

## File Structure

```
whisper-dictate-gui    # Main executable script (Python 3, GTK4)
install.sh             # Automated installer (apt deps, builds whisper.cpp, systemd service)
uninstall.sh           # Selective uninstaller with interactive prompts
README.md              # User-facing documentation
INSTALL.md             # Manual installation guide with verification steps
LICENSE                # MIT
```

No subdirectories, no Python packages, no virtual environments.

## Key Constants and Paths

Defined at the top of `whisper-dictate-gui`:

```python
WHISPER_DIR   = ~/.local/share/whisper.cpp
MODEL         = ~/.local/share/whisper.cpp/models/ggml-tiny.en.bin
WHISPER_BIN   = ~/.local/share/whisper.cpp/build/bin/whisper-cli
AUDIO_FILE    = /tmp/dictation_audio.wav
YDOTOOL_SOCKET = ~/.ydotool_socket
IPC_SOCKET    = /tmp/whisper-dictate.sock
```

Application ID: `com.local.whisper-dictate`

## GUI States

The button cycles through three visual states:

| State | CSS Class | Color | Icon | Button Active |
|-------|-----------|-------|------|---------------|
| Ready | `mic-ready` | Blue (#3584e4) | `audio-input-microphone-symbolic` | Yes |
| Recording | `mic-recording` | Red (#e01b24) | `media-record-symbolic` | Yes |
| Processing | `mic-processing` | Yellow (#f5c211) | `emblem-synchronizing-symbolic` | No (disabled) |

Window is fixed at 120x140 pixels, non-resizable.

## Text Injection

Text is injected into the target window using `ydotool type`, which operates at the kernel level via `/dev/uinput`. This bypasses the clipboard entirely, avoiding the X11/Wayland clipboard mismatch problem (see Wayland/X11 Constraints below).

The `hotkey_triggered` flag determines whether Alt+Tab is needed:
- **Hotkey mode**: Target window keeps focus, `ydotool type` goes directly to it
- **Button-click mode**: App stole focus, `ydotool` sends Alt+Tab first to return to previous window

The `ydotool` key codes used for Alt+Tab:
- `56` = Alt, `15` = Tab
- Format: `keycode:1` = press, `keycode:0` = release

## Wayland/X11 Constraints

The app runs with `GDK_BACKEND=x11` so that `wmctrl` can set the window as always-on-top. This creates an important constraint:

- **Child processes inherit `GDK_BACKEND=x11`**, which breaks Wayland-native tools like `wl-copy`/`wl-paste` (they hang indefinitely)
- **X11 and Wayland have separate clipboards** -- `xclip` can set the X11 clipboard, but native Wayland apps (Chrome, Firefox, etc.) read the Wayland clipboard and won't see it
- **`xdotool` can only interact with XWayland windows** -- it cannot send keystrokes to native Wayland windows like Chrome
- **`ydotool` works everywhere** -- it operates at the kernel level (`/dev/uinput`), bypassing both X11 and Wayland entirely

**Bottom line**: Use `ydotool` for all keystroke/text injection. Do NOT use clipboard-based paste (`wl-copy`/`xclip` + Ctrl+V) -- it will fail for cross-session targets.

## Hallucination Filtering

Whisper's tiny model produces false positives from silence or background noise. The `HALLUCINATIONS` set (line 23-28) filters these out. A transcription result is discarded if:

1. `text.lower()` is in the `HALLUCINATIONS` set (common single words like "you", "the", "okay", markers like "[music]", "[silence]")
2. `len(text) < 3` (too short to be meaningful)

When filtered, the UI shows "No speech detected" for 1.5 seconds before resetting.

## External Tool Dependencies

These must all be available at runtime:

- `arecord` -- from `alsa-utils` package
- `whisper-cli` -- built from source at `~/.local/share/whisper.cpp/build/bin/`
- `ydotool` -- from `ydotool` package, requires `ydotoold` daemon running via systemd user service. Used for text injection (`ydotool type`) and keystrokes (`ydotool key`)
- `xdotool` -- from `xdotool` package (only for managing the app's own XWayland window)
- `wmctrl` -- from `wmctrl` package (setting always-on-top on the app's XWayland window)
- `xprop` -- from `x11-utils` package (window property queries)
- `python3-evdev` -- for Alt double-tap hotkey listener and UInput virtual keyboard

## Development Notes

### Running from source

```bash
./whisper-dictate-gui
```

No build step needed. The script is directly executable. Prerequisites must be installed first (`./install.sh` or manual steps in `INSTALL.md`).

### Testing

No formal test suite exists. Verification is manual:

```bash
arecord -d 3 /tmp/test.wav && aplay /tmp/test.wav                    # mic works
~/.local/share/whisper.cpp/build/bin/whisper-cli -m ~/.local/share/whisper.cpp/models/ggml-tiny.en.bin -f /tmp/test.wav  # whisper works
YDOTOOL_SOCKET=~/.ydotool_socket ydotool type "Hello World"          # ydotool works
echo "test" | wl-copy && wl-paste                                     # clipboard works
```

### Key Design Decisions

1. **Single file** -- No modules, no package structure. Everything in one script for simplicity and easy distribution.
2. **System tools over Python libraries** -- Uses `arecord`, `ydotool` via subprocess instead of Python audio libraries. Fewer Python dependencies, leverages well-tested system utilities.
3. **whisper.cpp over OpenAI API** -- Local processing, no internet needed, no API costs. The C++ implementation is fast enough for the tiny.en model.
4. **`ydotool type` over clipboard paste** -- Injects text directly at the kernel level, avoiding the X11/Wayland clipboard mismatch. Alt+Tab is only used when recording was started via button click (not hotkey).
5. **No configuration file** -- All settings are hardcoded constants. The only runtime toggle is the Word/Apps switch in the GUI.
6. **Hybrid X11/Wayland** -- GTK window runs as XWayland (`GDK_BACKEND=x11`) for `wmctrl` always-on-top support. `ydotool` handles all input injection on Wayland. `evdev` handles hotkey detection.

### Known Limitations / Future Work

- **Alt double-tap hotkey**: Implemented in-app via `evdev` keyboard listener. Also supports IPC toggle via `--toggle` flag for external shortcut configuration.
- **No auto-detection of paste mode**: The Word/Apps toggle is manual. The `is_terminal()` function and `TERMINAL_APPS` set exist in the code but are not currently wired into the paste logic -- the switch overrides everything.
- **Fixed whisper model**: The tiny.en model path is hardcoded. Switching models requires editing the script.
- **English only**: Uses the English-specific model (`tiny.en`). Supporting other languages would require using multilingual models and potentially adding a language selector.
- **No audio device selection**: Uses the system default microphone via `arecord` with no device picker.

### Code Conventions

- No pip/virtualenv dependencies -- only Python stdlib and system-installed `gi` (PyGObject)
- Subprocess calls use `check=False` or try/except for graceful failure handling
- GTK operations happen on the main thread; `GLib.idle_add()` is used to schedule UI updates from the IPC thread
- `GLib.timeout_add()` is used for delayed state transitions (e.g., showing "Done!" for 1.5s before resetting)
- The `transcribe()` method returns `False` to prevent GLib from re-scheduling it (one-shot timer callback)
