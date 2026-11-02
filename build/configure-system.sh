#!/bin/bash
set -euo pipefail

# Nova Linux Configure System Script
# Phase 2: System Foundation

echo "=== NOVA LINUX - SYSTEM FOUNDATION PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/8] Installing Linux kernel and firmware..."
apt-get install -y \
    linux-image-amd64 \
    linux-headers-amd64 \
    firmware-linux \
    firmware-linux-nonfree \
    intel-microcode \
    amd64-microcode

echo "[2/8] Installing initramfs-tools..."
apt-get install -y initramfs-tools

echo "[3/8] Installing systemd and udev..."
apt-get install -y systemd systemd-sysv udev

echo "[4/8] Installing GRUB bootloader..."
apt-get install -y grub grub-pc grub-efi
grub-install /dev/sda
update-grub

echo "[5/8] Configuring APT and essential utilities..."
apt-get install -y \
    aptitude \
    sudo \
    curl \
    wget \
    net-tools \
    iproute2 \
    usbutils \
    pciutils

echo "[6/8] Installing NetworkManager..."
apt-get install -y network-manager
systemctl enable NetworkManager

echo "[7/8] Creating system users and groups..."
useradd -m -G sudo -s /bin/bash nova || true
echo "nova ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nova

echo "[8/8] Essential filesystem setup..."
mkdir -p /boot/efi
mkdir -p /home
mkdir -p /var/cache/apt/archives
mkdir -p /var/log

echo ""
echo "=== SYSTEM FOUNDATION COMPLETE ==="
echo "Kernel, initramfs, GRUB, and system configuration ready."