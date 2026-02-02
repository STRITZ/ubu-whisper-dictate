#!/bin/bash
#
# Whisper Dictate GUI - Uninstallation Script
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

WHISPER_DIR="$HOME/.local/share/whisper.cpp"
INSTALL_DIR="$HOME/.local/bin"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Whisper Dictate GUI - Uninstallation Script           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Remove application
if [ -f "$INSTALL_DIR/whisper-dictate-gui" ]; then
    print_status "Removing whisper-dictate-gui..."
    rm -f "$INSTALL_DIR/whisper-dictate-gui"
    print_success "Application removed"
else
    print_warning "Application not found at $INSTALL_DIR/whisper-dictate-gui"
fi

# Remove desktop entry
if [ -f ~/.local/share/applications/whisper-dictate.desktop ]; then
    print_status "Removing desktop entry..."
    rm -f ~/.local/share/applications/whisper-dictate.desktop
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
    print_success "Desktop entry removed"
fi

# Ask about ydotoold service
echo ""
read -p "Stop and disable ydotoold service? (other apps may use it) [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl --user stop ydotoold.service 2>/dev/null || true
    systemctl --user disable ydotoold.service 2>/dev/null || true
    rm -f ~/.config/systemd/user/ydotoold.service
    systemctl --user daemon-reload
    print_success "ydotoold service removed"
fi

# Ask about whisper.cpp
echo ""
read -p "Remove whisper.cpp and models? (~500MB) [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$WHISPER_DIR" ]; then
        rm -rf "$WHISPER_DIR"
        print_success "whisper.cpp removed"
    fi
fi

echo ""
print_success "Uninstallation complete!"
echo ""
print_warning "System packages (python3-gi, ydotool, etc.) were not removed."
print_warning "Remove them manually with apt if no longer needed."
echo ""
