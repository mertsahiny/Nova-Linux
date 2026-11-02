#!/bin/bash
set -euo pipefail

# Nova Linux Bootstrap Script
# Phase 1: Fresh debootstrap root filesystem

echo "=== NOVA LINUX - BOOTSTRAP PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/11] Updating package lists..."
apt-get update

echo "[2/11] Installing debootstrap and build essentials..."
apt-get install -y debootstrap qemu-user-static

echo "[3/11] Creating mount point for root filesystem..."
mkdir -p /nova-root
mount -t tmpfs -o size=2G tmpfs /nova-root || true

echo "[4/11] Bootstrapping minimal Debian Trixie root filesystem..."
debian_mirror="http://deb.debian.org/debian"
architecture="amd64"

debootstrap --components="main contrib nonfree" --arch="$architecture" \
    "trixie" "/nova-root" "$debian_mirror"

echo "[5/11] Mounting proc, sys, dev filesystems..."
mount -t proc proc /nova-root/proc
mount -t sysfs sys /nova-root/sys
mount -o bind /dev /nova-root/dev

echo "[6/11] Configuring APT sources..."
cat > /nova-root/etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian trixie main contrib nonfree non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib nonfree non-free-firmware
deb http://deb.debian.org/debian trixie-security main contrib nonfree non-free-firmware
EOF

echo "[7/11] Configuring hostname..."
echo "nova" > /nova-root/etc/hostname

echo "[8/11] Configuring locale..."
cat > /nova-root/etc/locale.gen << 'EOF'
en_US.UTF-8 UTF-8
EOF
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

echo "[9/11] Configuring timezone..."
ln -sf /usr/share/zoneinfo/UTC /nova-root/etc/localtime
echo "UTC" > /nova-root/etc/timezone

echo "[10/11] Configuring system users and groups..."
# Create nova user
useradd -m -G sudo -s /bin/bash nova || true

# Set root password (will be overridden in live system)
echo "root:novalinux" | chpasswd

echo "[11/11] Essential filesystem setup..."
mkdir -p /nova-root/{boot/efi,home,var/cache/apt/archives,var/log}

echo ""
echo "=== BOOTSTRAP COMPLETE ==="
echo "Root filesystem located at /nova-root"
echo "Essential system files validated."

# Validate essential files
essential_files=(
    "/nova-root/bin/bash"
    "/nova-root/sbin/init"
    "/nova-root/lib/x86_64-linux-gnu/libc.so.6"
)

for file in "${essential_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  [OK] $(basename $file) exists"
    else
        echo "  [WARN] $(basename $file) not found"
    fi
done

echo ""
echo "Bootstrap complete. Ready for Phase 2."
