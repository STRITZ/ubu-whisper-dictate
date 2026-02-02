# Manual Installation Guide

This guide covers manual installation steps if you prefer not to use the automated `install.sh` script.

## Prerequisites

### System Packages

```bash
sudo apt update
sudo apt install -y \
    python3 \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-4.0 \
    alsa-utils \
    wl-clipboard \
    ydotool \
    git \
    cmake \
    build-essential \
    xdotool \
    x11-utils
```

## Step 1: Build whisper.cpp

```bash
# Clone whisper.cpp
mkdir -p ~/.local/share
git clone https://github.com/ggerganov/whisper.cpp.git ~/.local/share/whisper.cpp

# Build
cd ~/.local/share/whisper.cpp
mkdir -p build && cd build
cmake ..
cmake --build . --config Release
```

## Step 2: Download Whisper Model

```bash
cd ~/.local/share/whisper.cpp
./models/download-ggml-model.sh tiny.en
```

Available models (speed vs accuracy tradeoff):
- `tiny.en` - Fastest, ~75MB
- `base.en` - ~150MB
- `small.en` - ~500MB
- `medium.en` - ~1.5GB

## Step 3: Setup ydotool Daemon

Create the systemd user service:

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/ydotoold.service << 'EOF'
[Unit]
Description=ydotool daemon

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold --socket-path=%h/.ydotool_socket --socket-own=%U:%G
Restart=always

[Install]
WantedBy=default.target
EOF
```

Enable and start:

```bash
systemctl --user daemon-reload
systemctl --user enable ydotoold.service
systemctl --user start ydotoold.service
```

Verify it's running:

```bash
systemctl --user status ydotoold
ls -la ~/.ydotool_socket
```

## Step 4: Install the Application

```bash
# Ensure ~/.local/bin exists and is in PATH
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Copy the script
cp whisper-dictate-gui ~/.local/bin/
chmod +x ~/.local/bin/whisper-dictate-gui
```

## Step 5: Create Desktop Entry (Optional)

```bash
mkdir -p ~/.local/share/applications

cat > ~/.local/share/applications/whisper-dictate.desktop << 'EOF'
[Desktop Entry]
Name=Whisper Dictate
Comment=Voice-to-text dictation using whisper.cpp
Exec=whisper-dictate-gui
Icon=audio-input-microphone
Terminal=false
Type=Application
Categories=Utility;AudioVideo;
EOF

update-desktop-database ~/.local/share/applications
```

## Verification

Test each component:

```bash
# Test microphone
arecord -d 3 /tmp/test.wav && aplay /tmp/test.wav

# Test whisper
~/.local/share/whisper.cpp/build/bin/whisper-cli \
    -m ~/.local/share/whisper.cpp/models/ggml-tiny.en.bin \
    -f /tmp/test.wav

# Test ydotool
YDOTOOL_SOCKET=~/.ydotool_socket ydotool type "Hello World"

# Test clipboard
echo "test" | wl-copy && wl-paste
```

## Run the Application

```bash
whisper-dictate-gui
```
