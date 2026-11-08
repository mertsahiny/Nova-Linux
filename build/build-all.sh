
#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${ROOTFS:-/nova-root}"
ISO_ROOT="${ISO_ROOT:-/nova-iso}"
OUT_DIR="${OUT_DIR:-$PWD/out}"
VERSION="${NOVA_VERSION:-0.1.0}"
ARCH="amd64"
MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this build script as root." >&2
    exit 1
fi

for cmd in debootstrap chroot mksquashfs grub-mkrescue xorriso; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: Missing host dependency: $cmd" >&2
        exit 1
    }
done

cleanup() {
    set +e
    for mountpoint in \
        "$ROOTFS/dev/pts" \
        "$ROOTFS/dev" \
        "$ROOTFS/proc" \
        "$ROOTFS/sys"; do
        if mountpoint -q "$mountpoint"; then
            umount -lf "$mountpoint"
        fi
    done
}
trap cleanup EXIT

echo "==> Cleaning previous build"
rm -rf "$ROOTFS" "$ISO_ROOT"
mkdir -p "$ROOTFS" "$ISO_ROOT/live" "$ISO_ROOT/boot/grub" "$OUT_DIR"

echo "==> Bootstrapping Debian 13 Trixie"

debootstrap \
    --arch="$ARCH" \
    --components=main,contrib,non-free,non-free-firmware \
    trixie "$ROOTFS" "$MIRROR"

echo "==> Configuring repositories"

cat > "$ROOTFS/etc/apt/sources.list" <<'EOF'
deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb https://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

echo "==> Preparing chroot mounts"

mount --bind /dev "$ROOTFS/dev"
mount --make-rslave "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
mount -t proc proc "$ROOTFS/proc"
mount -t sysfs sysfs "$ROOTFS/sys"

# Do not bind the host's /run into the chroot.
mkdir -p "$ROOTFS/run"
chmod 0755 "$ROOTFS/run"

cat > "$ROOTFS/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
chmod +x "$ROOTFS/usr/sbin/policy-rc.d"

echo "==> Entering Debian chroot"

chroot "$ROOTFS" /bin/bash -e <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package lists"
apt-get update

echo "==> Enabling i386 architecture"
dpkg --add-architecture i386
apt-get update

echo "==> Installing OpenRC and SysVinit"

# Keep sysusers compatibility for Debian packages such as udev.
# systemd is not required to be PID 1.
apt-get --purge --allow-remove-essential install -y \
    --no-install-recommends \
    sysvinit-core \
    openrc \
    systemd-standalone-sysusers \
    elogind \
    libpam-elogind \
    dbus-x11 \
    orphan-sysvinit-scripts \
    live-config \
    live-config-sysvinit \
    systemd-sysv- \
    systemd- \
    live-config-systemd- \
    libpam-systemd-

echo "==> Checking init packages"
apt-get check

if ! dpkg-query -W -f='${Status}' openrc 2>/dev/null | grep -q "install ok installed"; then
    echo "ERROR: OpenRC is not installed." >&2
    exit 1
fi

if ! dpkg-query -W -f='${Status}' sysvinit-core 2>/dev/null | grep -q "install ok installed"; then
    echo "ERROR: SysVinit is not installed." >&2
    exit 1
fi

if ! dpkg-query -W -f='${Status}' systemd-standalone-sysusers 2>/dev/null | grep -q "install ok installed"; then
    echo "ERROR: systemd-standalone-sysusers is missing." >&2
    exit 1
fi

echo "==> Installing desktop and live system"

apt-get install -y --no-install-recommends \
    dbus \
    sudo \
    locales \
    ca-certificates \
    curl \
    wget \
    linux-image-amd64 \
    live-boot \
    network-manager \
    xserver-xorg \
    sddm \
    kde-plasma-desktop \
    dolphin \
    konsole \
    kate \
    systemsettings \
    ark \
    gwenview \
    kcalc \
    discover \
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    wireplumber \
    bluez \
    polkit-kde-agent-1 \
    firefox-esr \
    fastfetch \
    calamares \
    calamares-settings-debian \
    squashfs-tools

echo "==> Installing firmware and graphics"

apt-get install -y --no-install-recommends \
    intel-microcode \
    amd64-microcode \
    firmware-misc-nonfree \
    firmware-intel-graphics \
    firmware-amd-graphics \
    firmware-iwlwifi \
    firmware-realtek \
    mesa-utils \
    libgl1-mesa-dri \
    libglx-mesa0 \
    mesa-vulkan-drivers \
    libvulkan1 \
    mesa-va-drivers

echo "==> Installing gaming packages"

apt-get install -y --no-install-recommends \
    steam-installer \
    lutris \
    wine \
    wine64 \
    wine32 \
    winetricks \
    gamemode \
    mangohud \
    libgl1-mesa-dri:i386 \
    libglx-mesa0:i386 \
    mesa-vulkan-drivers:i386 \
    libvulkan1:i386

echo "==> Configuring locale"

sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

echo "==> Configuring hostname"
echo "nova" > /etc/hostname

echo "==> Creating live user"

if ! id nova >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,plugdev nova
fi

passwd -l nova || true

mkdir -p /etc/sudoers.d
printf 'nova ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/90-nova-live
chmod 0440 /etc/sudoers.d/90-nova-live

echo "==> Configuring NOVA identity"

cat > /etc/os-release <<'EOF'
PRETTY_NAME="NOVA Linux 0.1.0 (Supernova)"
NAME="NOVA Linux"
VERSION_ID="0.1.0"
VERSION="0.1.0 (Supernova)"
ID=nova
ID_LIKE=debian
VERSION_CODENAME=trixie
EOF

echo "==> Configuring SDDM"

mkdir -p /etc/sddm.conf.d

cat > /etc/sddm.conf.d/nova.conf <<'EOF'
[Autologin]
User=nova
Session=plasma.desktop
Relogin=false

[Theme]
Current=breeze
EOF

echo "==> Configuring Fastfetch"

mkdir -p /usr/share/fastfetch /etc/xdg/fastfetch

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
  "logo": {
    "type": "file",
    "source": "/usr/share/fastfetch/nova.txt"
  },
  "display": {
    "separator": "  "
  },
  "modules": [
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "display",
    "de",
    "wm",
    "terminal",
    "cpu",
    "gpu",
    "memory",
    {
      "type": "custom",
      "format": "OS made by: Mert Şahin Yazgaç."
    }
  ]
}
EOF

echo "==> Configuring OpenRC"

mkdir -p /etc/runlevels/default /etc/runlevels/boot /etc/runlevels/shutdown

cat > /etc/rc.conf <<'EOF'
rc_logger="YES"
rc_log_path="/var/log/rc.log"
rc_parallel="NO"
rc_verbose="YES"
EOF

# Enable services only when their OpenRC init scripts exist.
for service in dbus elogind NetworkManager sddm; do
    if [[ -x "/etc/init.d/$service" ]]; then
        echo "Enabling $service"
        rc-update add "$service" default || true
    else
        echo "NOTICE: No OpenRC init script for $service"
    fi
done

echo "==> Checking OpenRC executables"

if [[ ! -x /sbin/openrc ]]; then
    echo "ERROR: /sbin/openrc is missing." >&2
    exit 1
fi

if [[ ! -x /sbin/init ]]; then
    echo "ERROR: /sbin/init is missing." >&2
    exit 1
fi

echo "==> Cleaning package cache"
apt-get clean
rm -rf /var/lib/apt/lists/*

rm -f /usr/sbin/policy-rc.d

echo "==> Chroot configuration complete"
CHROOT

echo "==> Preparing Calamares launcher"

mkdir -p "$ROOTFS/usr/share/applications"

CALAMARES_DESKTOP="$ROOTFS/usr/share/applications/calamares-install-debian.desktop"

if [[ -f "$CALAMARES_DESKTOP" ]]; then
    cp "$CALAMARES_DESKTOP" \
        "$ROOTFS/usr/share/applications/nova-installer.desktop"

    sed -i 's/^Name=.*/Name=Install NOVA Linux/' \
        "$ROOTFS/usr/share/applications/nova-installer.desktop"

    mkdir -p "$ROOTFS/home/nova/Desktop"

    cp "$ROOTFS/usr/share/applications/nova-installer.desktop" \
        "$ROOTFS/home/nova/Desktop/Install NOVA Linux.desktop"

    chmod +x "$ROOTFS/home/nova/Desktop/Install NOVA Linux.desktop"

    NOVA_UID="$(chroot "$ROOTFS" id -u nova)"
    NOVA_GID="$(chroot "$ROOTFS" id -g nova)"

    chown -R "$NOVA_UID:$NOVA_GID" "$ROOTFS/home/nova"
else
    echo "ERROR: Debian Calamares desktop entry not found." >&2
    exit 1
fi

echo "==> Installing wallpaper"

if [[ -f "$PWD/Nova Wallpaper.png" ]]; then
    install -D -m 0644 \
        "$PWD/Nova Wallpaper.png" \
        "$ROOTFS/usr/share/wallpapers/Vibes/Nova Wallpaper.png"
else
    echo "NOTICE: Nova Wallpaper.png not found."
fi

echo "==> Building SquashFS"

mksquashfs \
    "$ROOTFS" \
    "$ISO_ROOT/live/filesystem.squashfs" \
    -comp xz \
    -b 1M \
    -noappend \
    -e dev proc sys run tmp

echo "==> Finding kernel and initramfs"

KERNEL="$(basename "$(find "$ROOTFS/boot" -maxdepth 1 -name 'vmlinuz-*' | sort -V | tail -n1)")"
INITRD="$(basename "$(find "$ROOTFS/boot" -maxdepth 1 -name 'initrd.img-*' | sort -V | tail -n1)")"

if [[ -z "$KERNEL" || -z "$INITRD" ]]; then
    echo "ERROR: Kernel or initramfs not found." >&2
    exit 1
fi

cp "$ROOTFS/boot/$KERNEL" "$ISO_ROOT/live/vmlinuz"
cp "$ROOTFS/boot/$INITRD" "$ISO_ROOT/live/initrd.img"

echo "==> Writing GRUB configuration"

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

echo "==> Creating checksum"
sha256sum "$ISO" > "$ISO.sha256"

echo "==> NOVA Linux ISO created"

ls -lh "$ISO" "$ISO.sha256"
