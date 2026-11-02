#!/bin/bash
set -euo pipefail

# Nova Linux Configure Desktop Script
# Phase 3: KDE Plasma desktop integration

echo "=== NOVA LINUX - KDE PLASMA DESKTOP PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/8] Ensuring SDDM display manager is configured..."
apt-get install -y sddm
systemctl enable sddm

echo "[2/8] Applying NOVA SDDM theme..."
mkdir -p /usr/share/sddm/themes/nova
cat > /usr/share/sddm/themes/nova/theme.conf << 'EOF'
[Theme]
Name=NOVA
GreeterTitle=NOVA Linux
DisplayError=Failed to start NOVA Linux session
EOF

echo "[3/8] Configuring KDE Plasma defaults..."
kwriteconfig6 --file=kdeglobals --group=General --key=Theme Breeze
kwriteconfig6 --file=kdeglobals --group=General --key=CursorTheme breeze

echo "[4/8] Configuring PipeWire audio..."
if ! systemctl is-enabled pipewire.socket > /dev/null 2>&1; then
    systemctl enable pipewire.socket
fi
if ! systemctl is-enabled pipewire-pulse.socket > /dev/null 2>&1; then
    systemctl enable pipewire-pulse.socket
fi

echo "[5/8] Configuring Polkit for administrative tools..."
apt-get install -y polkit-kde-agent-1

echo "[6/8] Configuring KDE Discover for updates..."
kwriteconfig6 --file=discoverrc --group=General --key=CheckForUpdates true

echo "[7/8] Setting up user session defaults..."
mkdir -p /etc/xdg/autostart
# Ensure KDE session starts correctly

echo "[8/8] Finalizing desktop configuration..."
# Set NOVA as default user theme
user-dir-icon -c nova 2>/dev/null || true

echo ""
echo "=== KDE PLASMA DESKTOP COMPLETE ==="
echo "SDDM login screen and KDE Plasma desktop configured."