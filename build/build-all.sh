#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${ROOTFS:-/nova-root}"
ISO_ROOT="${ISO_ROOT:-/nova-iso}"
OUT_DIR="${OUT_DIR:-$PWD/out}"
VERSION="${NOVA_VERSION:-0.1.0}"
ARCH=amd64
MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"

if [[ $EUID -ne 0 ]]; then
  echo "Run this build script as root." >&2
  exit 1
fi

for cmd in debootstrap chroot mksquashfs grub-mkrescue xorriso; do
  command -v "$cmd" >/dev/null || { echo "Missing host dependency: $cmd" >&2; exit 1; }
done

cleanup() {
  set +e
  for mountpoint in "$ROOTFS/dev/pts" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run"; do
    mountpoint -q "$mountpoint" && umount -lf "$mountpoint"
  done
}
trap cleanup EXIT

rm -rf "$ROOTFS" "$ISO_ROOT"
mkdir -p "$ROOTFS" "$ISO_ROOT/live" "$ISO_ROOT/boot/grub" "$OUT_DIR"

echo "==> Bootstrapping Debian 13 Trixie"
debootstrap --arch="$ARCH" --components=main,contrib,non-free,non-free-firmware \
  trixie "$ROOTFS" "$MIRROR"

cat > "$ROOTFS/etc/apt/sources.list" <<'EOF'
deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb https://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

mount --bind /dev "$ROOTFS/dev"
mount --make-rslave "$ROOTFS/dev"
mount -t proc proc "$ROOTFS/proc"
mount -t sysfs sysfs "$ROOTFS/sys"
mount --bind /run "$ROOTFS/run"

chroot "$ROOTFS" /bin/bash -e <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
dpkg --add-architecture i386
apt-get update

# Base system, KDE Plasma 6, networking, audio and live environment.
apt-get install -y --no-install-recommends \
  systemd-sysv dbus sudo locales ca-certificates curl wget \
  linux-image-amd64 live-boot live-config live-config-systemd \
  network-manager \
  xserver-xorg sddm kde-plasma-desktop plasma-workspace-wayland \
  dolphin konsole kate systemsettings ark gwenview kcalc discover \
  pipewire pipewire-audio pipewire-pulse wireplumber bluez \
  polkit-kde-agent-1 \
  firefox-esr fastfetch \
  calamares calamares-settings-debian \
  squashfs-tools

# Hardware firmware and open graphics stack.
apt-get install -y --no-install-recommends \
  intel-microcode amd64-microcode firmware-misc-nonfree \
  firmware-intel-graphics firmware-amd-graphics firmware-iwlwifi \
  firmware-realtek mesa-utils libgl1-mesa-dri libglx-mesa0 \
  mesa-vulkan-drivers libvulkan1 mesa-va-drivers

# Gaming stack. i386 was enabled above so Steam/Wine 32-bit dependencies resolve.
apt-get install -y --no-install-recommends \
  steam-installer lutris wine wine64 wine32 winetricks \
  gamemode mangohud \
  libgl1-mesa-dri:i386 libglx-mesa0:i386 \
  mesa-vulkan-drivers:i386 libvulkan1:i386

# Locale, user and NOVA identity.
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
echo "nova" > /etc/hostname
useradd -m -s /bin/bash -G sudo,audio,video,plugdev nova || true
passwd -l nova || true
printf 'nova ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/90-nova-live
chmod 0440 /etc/sudoers.d/90-nova-live

# Live session defaults; don't set a shared root password.
mkdir -p /etc/sddm.conf.d /usr/share/wallpapers/Vibes /usr/share/fastfetch
cat > /etc/sddm.conf.d/nova.conf <<'EOF'
[Autologin]
User=nova
Session=plasma.desktop
Relogin=false

[Theme]
Current=breeze
EOF

cat > /etc/os-release <<'EOF'
PRETTY_NAME="NOVA Linux 0.1.0 (Supernova)"
NAME="NOVA Linux"
VERSION_ID="0.1.0"
VERSION="0.1.0 (Supernova)"
ID=nova
ID_LIKE=debian
VERSION_CODENAME=trixie
EOF

cat > /usr/share/fastfetch/nova.txt <<'EOF'
             .-=========-.
          .-'   .---.     '-.
        .'     /  N  \       '.
       /      |  O   |         \
      |       |  V   |          |
      |       |  A   |          |
       \       \____/          /
        '.                   .'
          '-._____________.-'
EOF

cat > /etc/xdg/fastfetch/config.jsonc <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "file", "source": "/usr/share/fastfetch/nova.txt" },
  "display": { "separator": "  " },
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime",
    "packages", "shell", "display", "de", "wm", "terminal",
    "cpu", "gpu", "memory",
    { "type": "custom", "format": "OS made by: Mert Şahin Yazgaç." }
  ]
}
EOF

# Make the live user convenient without enabling a dangerous default password.
mkdir -p /etc/skel
systemctl enable NetworkManager sddm
apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT

echo "==> Preparing Calamares settings"
# Debian's settings package supplies its own working distro configuration.
# Add a NOVA launcher only when the package's desktop entry exists.
mkdir -p "$ROOTFS/usr/share/applications"
CALAMARES_DESKTOP="$ROOTFS/usr/share/applications/calamares-install-debian.desktop"
if [[ -f "$CALAMARES_DESKTOP" ]]; then
  cp "$CALAMARES_DESKTOP" "$ROOTFS/usr/share/applications/nova-installer.desktop"
  sed -i 's/^Name=.*/Name=Install NOVA Linux/' "$ROOTFS/usr/share/applications/nova-installer.desktop"
  mkdir -p "$ROOTFS/home/nova/Desktop"
  cp "$ROOTFS/usr/share/applications/nova-installer.desktop" "$ROOTFS/home/nova/Desktop/Install NOVA Linux.desktop"
  chmod +x "$ROOTFS/home/nova/Desktop/Install NOVA Linux.desktop"
  chown -R 1000:1000 "$ROOTFS/home/nova/Desktop"
else
  echo "ERROR: Debian Calamares desktop entry not found." >&2
  exit 1
fi

# Include the project's own wallpaper in the user-facing Vibes collection.
if [[ -f "$PWD/Nova Wallpaper.png" ]]; then
  install -D -m 0644 "$PWD/Nova Wallpaper.png" \
    "$ROOTFS/usr/share/wallpapers/Vibes/Nova Wallpaper.png"
fi

echo "==> Building live filesystem"
mksquashfs "$ROOTFS" "$ISO_ROOT/live/filesystem.squashfs" -comp xz -b 1M -noappend \
  -e dev proc sys run tmp

KERNEL="$(basename "$(find "$ROOTFS/boot" -maxdepth 1 -name 'vmlinuz-*' | sort -V | tail -n1)")"
INITRD="$(basename "$(find "$ROOTFS/boot" -maxdepth 1 -name 'initrd.img-*' | sort -V | tail -n1)")"
[[ -n "$KERNEL" && -n "$INITRD" ]] || { echo "Kernel or initrd not found." >&2; exit 1; }
cp "$ROOTFS/boot/$KERNEL" "$ISO_ROOT/live/vmlinuz"
cp "$ROOTFS/boot/$INITRD" "$ISO_ROOT/live/initrd.img"

cat > "$ISO_ROOT/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "NOVA Linux Live" {
    linux /live/vmlinuz boot=live components quiet splash username=nova hostname=nova
    initrd /live/initrd.img
}
EOF

echo "==> Creating hybrid BIOS/UEFI ISO"
ISO="$OUT_DIR/NOVA-Linux-${VERSION}-amd64.iso"
grub-mkrescue -o "$ISO" "$ISO_ROOT"
sha256sum "$ISO" > "$ISO.sha256"

echo "==> ISO created:"
ls -lh "$ISO" "$ISO.sha256"
