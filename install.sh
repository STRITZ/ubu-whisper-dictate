#!/bin/bash
#
# Whisper Dictate GUI - Installation Script
#
# This script installs all dependencies and sets up the dictation application
# for Ubuntu Linux (22.04+ with Wayland recommended)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# Configuration
WHISPER_DIR="$HOME/.local/share/whisper.cpp"
MODEL_NAME="ggml-tiny.en.bin"
INSTALL_DIR="$HOME/.local/bin"
YDOTOOL_SOCKET="$HOME/.ydotool_socket"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Whisper Dictate GUI - Installation Script            ║"
echo "║                  For Ubuntu Linux (Wayland)                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    print_warning "This script is designed for Ubuntu. It may work on other distros."
fi

# Ensure ~/.local/bin exists and is in PATH
mkdir -p "$INSTALL_DIR"
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    print_warning "~/.local/bin is not in your PATH"
    print_status "Adding to ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.local/bin:$PATH"
fi

# Step 1: Install system dependencies
print_status "Installing system dependencies..."
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

print_success "System dependencies installed"

# Step 2: Build whisper.cpp if not present
if [ ! -f "$WHISPER_DIR/build/bin/whisper-cli" ]; then
    print_status "Building whisper.cpp (this may take a few minutes)..."

    mkdir -p "$WHISPER_DIR"

    if [ ! -d "$WHISPER_DIR/.git" ]; then
        git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
    fi

    cd "$WHISPER_DIR"
    git pull origin master 2>/dev/null || true

    mkdir -p build
    cd build
    cmake ..
    cmake --build . --config Release

    print_success "whisper.cpp built successfully"
else
    print_success "whisper.cpp already installed"
fi

# Step 3: Download whisper model if not present
MODEL_PATH="$WHISPER_DIR/models/$MODEL_NAME"
if [ ! -f "$MODEL_PATH" ]; then
    print_status "Downloading whisper model ($MODEL_NAME)..."
    mkdir -p "$WHISPER_DIR/models"
    cd "$WHISPER_DIR"
    ./models/download-ggml-model.sh tiny.en
    print_success "Whisper model downloaded"
else
    print_success "Whisper model already present"
fi

# Step 4: Setup ydotool daemon
print_status "Setting up ydotool daemon..."

# Create systemd user service for ydotoold
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/ydotoold.service << EOF
[Unit]
Description=ydotool daemon
Documentation=man:ydotool(1)

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold --socket-path=${YDOTOOL_SOCKET} --socket-own=$(id -u):$(id -g)
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# Enable and start ydotoold
systemctl --user daemon-reload
systemctl --user enable ydotoold.service
systemctl --user start ydotoold.service || print_warning "ydotoold may already be running"

print_success "ydotool daemon configured"

# Step 5: Install the main application
print_status "Installing whisper-dictate-gui..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/whisper-dictate-gui" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/whisper-dictate-gui"

print_success "Application installed to $INSTALL_DIR/whisper-dictate-gui"

# Step 6: Create desktop entry for application menu
print_status "Creating desktop entry..."

mkdir -p ~/.local/share/applications

cat > ~/.local/share/applications/whisper-dictate.desktop << EOF
[Desktop Entry]
Name=Whisper Dictate
Comment=Voice-to-text dictation using whisper.cpp
Exec=$INSTALL_DIR/whisper-dictate-gui
Icon=audio-input-microphone
Terminal=false
Type=Application
Categories=Utility;AudioVideo;
Keywords=voice;dictation;speech;transcribe;whisper;
EOF

print_success "Desktop entry created"

# Step 7: Update desktop database
print_status "Updating desktop database..."
update-desktop-database ~/.local/share/applications 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   Installation Complete!                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
print_success "You can now run: whisper-dictate-gui"
print_success "Or find 'Whisper Dictate' in your application menu"
echo ""
print_status "Optional: Set up a global hotkey in your system settings"
print_status "          to launch whisper-dictate-gui for quick access"
echo ""

# Offer to run the app
read -p "Would you like to launch the app now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    "$INSTALL_DIR/whisper-dictate-gui" &
fi
