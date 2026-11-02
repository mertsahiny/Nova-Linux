#!/bin/bash
set -euo pipefail

# Nova Linux Configure Bootloader Script
# Phase 2: GRUB configuration for BIOS and UEFI

echo "=== NOVA LINUX - BOOTLOADER CONFIGURATION PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/6] Installing GRUB packages..."
apt-get install -y \
    grub \
    grub-pc \
    grub-efi \
    efibootmgr

echo "[2/6] Configuring BIOS boot..."
if [ -f /sys/firmware/efi/efivars ]; then
    echo "UEFI system detected - skipping BIOS GRUB install"
else
    echo "BIOS system detected - installing GRUB for BIOS"
    grub-install /dev/sda
fi

echo "[3/6] Configuring UEFI boot..."
if [ -f /sys/firmware/efi/efivars ]; then
    echo "UEFI system detected - installing GRUB for UEFI"
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --uefi-secure-boot
fi

echo "[4/6] Generating GRUB configuration..."
update-grub

echo "[5/6] Configuring GRUB theme and branding..."
if [ -d /usr/share/grub/themes ]; then
    mkdir -p /usr/share/grub/themes/nova
    # Apply NOVA branding to GRUB
    cat > /usr/share/grub/themes/nova/theme.txt << 'THEMEEOF'
# NOVA Linux GRUB Theme
set theme=/usr/share/grub/themes/nova/theme.txt
set background_image=/usr/share/grub/nova/background.png

export COLOR_NORMAL=white/black
export COLOR_HIGHLIGHT=black/cyan
THEMEEOF
fi

echo "[6/6] Setting boot parameters..."
# Add Nova-specific boot parameters
if [ -f /etc/default/grub ]; then
    # Append Nova boot parameters
    sed -i 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nova modest"/' /etc/default/grub
    # Update the GRUB config
    update-grub
fi

echo ""
echo "=== BOOTLOADER CONFIGURATION COMPLETE ==="
echo "GRUB configured for BIOS and UEFI boot with NOVA branding."