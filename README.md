# ubu-whisper-dictate

A lightweight voice-to-text dictation application for Ubuntu Linux using [whisper.cpp](https://github.com/ggerganov/whisper.cpp).

![GTK4](https://img.shields.io/badge/GTK-4.0-green)
![Python](https://img.shields.io/badge/Python-3.10+-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-orange)
![Wayland](https://img.shields.io/badge/Session-Wayland-purple)

## Features

- **Offline transcription** - Uses whisper.cpp locally, no internet required
- **Simple GUI** - Minimal GTK4 interface with one-button operation
- **Auto-paste** - Automatically pastes transcribed text into your active window
- **Two modes**:
  - **Terminal mode** (default): Uses `Ctrl+Shift+V` - works in terminals and Chrome
  - **Word/Apps mode**: Uses `Ctrl+V` - for LibreOffice, other applications

## Screenshots

```
┌──────────────┐
│      🎤      │  <- Click to record
│    Ready     │
│  Word/Apps ○ │  <- Toggle for paste mode
└──────────────┘
```

## Requirements

- Ubuntu 22.04+ (or compatible distro)
- Wayland session (recommended) or X11
- Working microphone
- ~500MB disk space (for whisper.cpp and model)

## Installation

### Quick Install

```bash
git clone https://github.com/YOUR_USERNAME/ubu-whisper-dictate.git
cd ubu-whisper-dictate
chmod +x install.sh
./install.sh
```

The install script will:
1. Install system dependencies (python3-gi, ydotool, etc.)
2. Build whisper.cpp from source
3. Download the tiny.en whisper model
4. Set up the ydotool daemon
5. Install the application to `~/.local/bin`
6. Create a desktop entry

### Manual Installation

If you prefer manual installation, see [INSTALL.md](INSTALL.md) for detailed steps.

## Usage

### Launch the App

```bash
whisper-dictate-gui
```

Or find "Whisper Dictate" in your application menu.

### Basic Workflow

1. Open the app (keep it visible or in background)
2. Click on the window where you want to type
3. Click the microphone button (turns red = recording)
4. Speak clearly
5. Click again to stop (turns yellow = processing)
6. Text is automatically pasted into your previous window

### Toggle Modes

- **OFF (default)**: Terminal mode - `Ctrl+Shift+V`
  - Use for: Terminal emulators, Chrome, Firefox, VS Code
- **ON**: Word/Apps mode - `Ctrl+V`
  - Use for: LibreOffice Writer, Gedit, other GTK apps

### Setting Up a Hotkey (Recommended)

For hands-free operation, set up a global keyboard shortcut:

**GNOME Settings:**
1. Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts
2. Add new shortcut:
   - Name: `Whisper Dictate`
   - Command: `whisper-dictate-gui`
   - Shortcut: `Super+D` (or your preference)

## Configuration

The application uses these default paths:

| Component | Path |
|-----------|------|
| whisper.cpp | `~/.local/share/whisper.cpp/` |
| Whisper model | `~/.local/share/whisper.cpp/models/ggml-tiny.en.bin` |
| ydotool socket | `~/.ydotool_socket` |
| Application | `~/.local/bin/whisper-dictate-gui` |

### Using a Different Model

For better accuracy (at the cost of speed), download a larger model:

```bash
cd ~/.local/share/whisper.cpp
./models/download-ggml-model.sh small.en   # ~500MB, more accurate
./models/download-ggml-model.sh medium.en  # ~1.5GB, even better
```

Then edit the `MODEL` variable in the script.

## Uninstallation

```bash
./uninstall.sh
```

This will remove the application and optionally clean up whisper.cpp and the ydotool service.

## Troubleshooting

### "No audio recorded"
- Check your microphone: `arecord -l`
- Test recording: `arecord -d 3 test.wav && aplay test.wav`

### "ydotool not working"
- Ensure the daemon is running: `systemctl --user status ydotoold`
- Check the socket exists: `ls -la ~/.ydotool_socket`

### "Paste not working in some apps"
- Try toggling the Word/Apps switch
- Some Electron apps may need the Word/Apps mode

### "whisper-cli not found"
- Rebuild whisper.cpp: `cd ~/.local/share/whisper.cpp/build && cmake --build .`

## How It Works

1. **Recording**: Uses `arecord` (ALSA) to capture audio from your microphone
2. **Transcription**: Runs `whisper-cli` with the tiny.en model for fast, local transcription
3. **Clipboard**: Copies text using `wl-copy` (Wayland clipboard)
4. **Paste**: Uses `ydotool` to simulate keyboard input (`Alt+Tab` back, then paste)

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see [LICENSE](LICENSE) file.

## Acknowledgments

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance C++ port of OpenAI's Whisper
- [ydotool](https://github.com/ReimuNotMoe/ydotool) - Generic command-line automation tool for Wayland
