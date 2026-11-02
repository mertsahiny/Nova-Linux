#!/bin/bash
set -euo pipefail

# Nova Linux Configure Kernel Script
# Phase 2: Kernel and initramfs configuration

echo "=== NOVA LINUX - KERNEL CONFIGURATION PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/5] Installing kernel packages..."
apt-get install -y \
    linux-image-amd64 \
    linux-headers-amd64 \
    amd64-microcode \
    intel-microcode

echo "[2/5] Installing firmware packages..."
apt-get install -y \
    firmware-linux \
    firmware-linux-nonfree \
    firmware-misc-nonfree

echo "[3/5] Configuring initramfs-tools..."
# Add required hooks for Nova Linux
echo "HOOKS=\"base udevmod autodetect keyboard modconf block filesystems fsck\"" > /etc/initramfs-tools/nova-hooks
cp /etc/initramfs-tools/nova-hooks /etc/initramfs-tools/hooks

echo "[4/5] Enabling systemd in initramfs..."
echo "COMPRESS=xz" > /etc/initramfs-tools/config
echo "BOOT=" >> /etc/initramfs-tools/config
if ! grep -q "systemd" /etc/initramfs-tools/hooks; then
    sed -i 's/^HOOKS=.*/HOOKS="base systemd udevmod autodetect keyboard modconf block filesystems fsck"/' /etc/initramfs-tools/hooks
fi

echo "[5/5] Generating initramfs..."
update-initramfs -u -k all

echo ""
echo "=== KERNEL CONFIGURATION COMPLETE ==="
echo "Linux kernel, firmware, and initramfs configured and generated."