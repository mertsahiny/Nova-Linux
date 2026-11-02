#!/bin/bash
set -euo pipefail

# Nova Linux Assemble ISO Script
# Phase 7: Live boot environment ISO assembly

echo "=== NOVA LINUX - LIVE BOOT ISO ASSEMBLY PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/7] Creating ISO directory structure..."
mkdir -p /nova-iso/BOOT/GRUB2-EFI
mkdir -p /nova-iso/isolinux
mkdir -p /nova-iso/.disk

echo "[2/7] Generating SquashFS live filesystem from /nova-root..."
mksquashfs /nova-root /nova-iso/casper/filesystem.squashfs -e /proc /dev /sys /tmp /run /var /snap

echo "[3/7] Copying kernel and initramfs..."
# Copy the vmlinuz and initrd from the root filesystem
cp -r /nova-root/boot/vmlinuz* /nova-iso/
cp -r /nova-root/boot/initrd.img* /nova-iso/

echo "[4/7] Configuring GRUB for ISO boot with Debian live-boot infrastructure..."
mkdir -p /nova-iso/boot/grub
cat > /nova-iso/boot/grub/grub.cfg << 'EOF'
# Nova Linux GRUB Live Boot Configuration (Debian live-boot)
set timeout=5
set default=0

# Live boot menu entry using Debian live-boot
menuentry "Nova Linux Live" {
    linux /vmlinuz boot=live live-from-iso=/install/pressed
    initrd /initrd.img
}

# Failsafe live boot menu entry
menuentry "Nova Linux Live (Failsafe)" {
    linux /vmlinuz boot=live
    initrd /initrd.img
}
EOF

echo "[5/7] Installing GRUB EFI files for UEFI support..."
if [ -d /sys/firmware/efi/efivars ]; then
    mkdir -p /nova-iso/BOOT/GRUB2-EFI
    grub-mkimage -O x86_64-efi --prefix='(cd)/boot/grub' -o /nova-iso/BOOT/GRUB2-EFI/grubx64.efi \
        fat ext2 iso9660 loopback chain configfile normal
fi

echo "[6/7] Creating NOVA branding disk info..."
cat > /nova-iso/.disk << 'EOF'
newabel
nano
0.1.0
SUPERNOVA
EOF

echo "[7/7] Assembling the hybrid ISO..."
if [ -d /sys/firmware/efi/efivars ]; then
    # UEFI build
    grub-mkrescue -o /nova-nova-0.1.0.iso /nova-iso 2>/dev/null || \
    genisoimage -U -V "NOVA_LINUX_0.1.0" -b isolinux/isolinux.bin -c isolinux/boot.cat \
        -no-emul-boot -boot-length 2 -boot-info-table -o /nova-nova-0.1.0.iso /nova-iso
else
    # BIOS build
    genisoimage -b isolinux/isolinux.bin -c isolinux/boot.cat \
        -no-emul-boot -boot-size -o /nova-nova-0.1.0.iso /nova-iso
fi

echo ""
echo "=== LIVE BOOT ISO ASSEMBLY COMPLETE ==="
echo "Bootable ISO image created at /nova-nova-0.1.0.iso"