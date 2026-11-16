
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

echo "==> Branding Calamares for NOVA"

# Debian's settings package supplies working Calamares modules and install jobs.
# Reuse those modules, but give Calamares its own NOVA branding component.
if [[ ! -f /etc/calamares/settings.conf || ! -f /etc/calamares/branding/debian/branding.desc ]]; then
    echo "ERROR: Debian Calamares settings or branding files are missing." >&2
    exit 1
fi

mkdir -p /etc/calamares/branding/nova

cat > /etc/calamares/branding/nova/branding.desc <<'NOVA_BRANDING'
---
componentName: NOVA Linux Installer
welcomeStyleCalamares: true
welcomeExpandingLogo: true
windowExpanding: normal
windowSize: 900px,620px
windowPlacement: center

strings:
    productName: NOVA Linux
    shortProductName: NOVA
    version: 0.1.0
    shortVersion: 0.1.0
    versionedName: NOVA Linux 0.1.0
    shortVersionedName: NOVA 0.1.0
    bootloaderEntryName: NOVA Linux
    productUrl: https://github.com/mertsahiny/Nova-Linux
    supportUrl: https://github.com/mertsahiny/Nova-Linux/issues
    knownIssuesUrl: https://github.com/mertsahiny/Nova-Linux/issues
    releaseNotesUrl: https://github.com/mertsahiny/Nova-Linux/releases

sidebar: widget
navigation: widget

images:
    productBanner: "nova-banner.svg"
    productIcon: "nova-logo.svg"
    productLogo: "nova-logo.svg"
    productWallpaper: "nova-wallpaper.svg"
    productWelcome: "nova-welcome.svg"

style:
    SidebarBackground: "#111827"
    SidebarText: "#E5E7EB"
    SidebarTextCurrent: "#FFFFFF"
    SidebarBackgroundCurrent: "#26334D"
NOVA_BRANDING

# Shared NOVA orbital-N artwork for the installer window and sidebar.
cat > /etc/calamares/branding/nova/nova-logo.svg <<'NOVA_LOGO'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="nova" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#42e8ff"/>
      <stop offset=".52" stop-color="#6875ff"/>
      <stop offset="1" stop-color="#f08bff"/>
    </linearGradient>
    <linearGradient id="orbit" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#42e8ff"/>
      <stop offset="1" stop-color="#f08bff"/>
    </linearGradient>
  </defs>
  <circle cx="256" cy="256" r="202" fill="#111827"/>
  <ellipse cx="256" cy="256" rx="218" ry="94" transform="rotate(-34 256 256)" fill="none" stroke="url(#orbit)" stroke-width="17" stroke-linecap="round"/>
  <path d="M153 355V157h48l158 132V157h48v198h-46L201 222v133z" fill="url(#nova)" stroke="#d9f8ff" stroke-opacity=".28" stroke-width="4" stroke-linejoin="round"/>
  <circle cx="432" cy="132" r="15" fill="#f08bff"/>
</svg>
NOVA_LOGO

cat > /etc/calamares/branding/nova/nova-banner.svg <<'NOVA_BANNER'
<svg xmlns="http://www.w3.org/2000/svg" width="720" height="120" viewBox="0 0 720 120">
  <defs><linearGradient id="word" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#42e8ff"/><stop offset=".55" stop-color="#8790ff"/><stop offset="1" stop-color="#f08bff"/></linearGradient></defs>
  <rect width="720" height="120" rx="18" fill="#111827"/>
  <text x="30" y="79" font-family="sans-serif" font-size="64" font-weight="700" letter-spacing="8" fill="url(#word)">NOVA LINUX</text>
</svg>
NOVA_BANNER

cat > /etc/calamares/branding/nova/nova-welcome.svg <<'NOVA_WELCOME'
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
  <rect width="640" height="360" rx="28" fill="#111827"/>
  <image href="nova-logo.svg" x="190" y="20" width="260" height="260"/>
  <text x="320" y="325" text-anchor="middle" font-family="sans-serif" font-size="34" font-weight="700" letter-spacing="7" fill="#42e8ff">NOVA LINUX</text>
</svg>
NOVA_WELCOME

cat > /etc/calamares/branding/nova/nova-wallpaper.svg <<'NOVA_WALLPAPER'
<svg xmlns="http://www.w3.org/2000/svg" width="900" height="620" viewBox="0 0 900 620">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0b1020"/><stop offset=".55" stop-color="#171a3b"/><stop offset="1" stop-color="#241532"/></linearGradient>
    <radialGradient id="glow"><stop offset="0" stop-color="#526dff" stop-opacity=".32"/><stop offset="1" stop-color="#526dff" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="900" height="620" fill="url(#bg)"/>
  <circle cx="730" cy="110" r="360" fill="url(#glow)"/>
  <circle cx="150" cy="540" r="300" fill="url(#glow)"/>
</svg>
NOVA_WALLPAPER

# Select the NOVA branding component and verify the setting.
sed -i 's/^branding: debian$/branding: nova/' /etc/calamares/settings.conf
if ! grep -q '^branding: nova$' /etc/calamares/settings.conf; then
    echo "ERROR: Calamares did not switch to NOVA branding." >&2
    exit 1
fi

# Remove the Debian branding assets after switching to the NOVA component.
rm -rf /etc/calamares/branding/debian
rm -f /usr/share/pixmaps/install-debian.png
install -D -m 0644 /etc/calamares/branding/nova/nova-logo.svg /usr/share/pixmaps/nova-installer.svg

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

echo "==> Installing NOVA KDE application launcher icon"

# A small icon theme that inherits Breeze but replaces KDE's start-menu logo.
mkdir -p /usr/share/icons/NOVA/places/scalable

cat > /usr/share/icons/NOVA/index.theme <<'NOVA_ICON_THEME'
[Icon Theme]
Name=NOVA
Comment=NOVA Linux icon overrides with Breeze fallback
Inherits=Breeze,hicolor
Directories=places/scalable

[places/scalable]
Size=48
Type=Scalable
MinSize=16
MaxSize=512
Context=Places
NOVA_ICON_THEME

cat > /usr/share/icons/NOVA/places/scalable/start-here-kde.svg <<'NOVA_MENU_ICON'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="nova" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#42e8ff"/>
      <stop offset="0.52" stop-color="#6875ff"/>
      <stop offset="1" stop-color="#f08bff"/>
    </linearGradient>
    <linearGradient id="orbit" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#42e8ff"/>
      <stop offset="1" stop-color="#f08bff"/>
    </linearGradient>
  </defs>
  <circle cx="256" cy="256" r="202" fill="#111827"/>
  <ellipse cx="256" cy="256" rx="218" ry="94" transform="rotate(-34 256 256)"
           fill="none" stroke="url(#orbit)" stroke-width="17" stroke-linecap="round"/>
  <path d="M153 355V157h48l158 132V157h48v198h-46L201 222v133z"
        fill="url(#nova)" stroke="#d9f8ff" stroke-opacity=".28" stroke-width="4"
        stroke-linejoin="round"/>
  <circle cx="432" cy="132" r="15" fill="#f08bff"/>
</svg>
NOVA_MENU_ICON

cat > /etc/xdg/kdeglobals <<'NOVA_KDE_GLOBALS'
[Icons]
Theme=NOVA
NOVA_KDE_GLOBALS

echo "==> Configuring Fastfetch"

mkdir -p /usr/share/fastfetch /etc/xdg/fastfetch

cat > /usr/share/fastfetch/nova.txt <<'EOF'
                    ..                                              ...........
                    -*=-                                  ...:::::::::::....:::----:
                    -+-++=:                          ..:::::::................. ..:=*=
                    -=:::=**-.                   ..::......                  .::....:**
                    -=::..:-+*+:              ....                ::           -...::=#-
                    -=......:-+**=.                            .:-=-           ::..:-=#-
                    -=........::=*#+:                        .::::--          .-..:-=##
                    -=...........::::=+*+:                   .....::=-         .-..:-+#%:
                    --.........:::-+**+:                   ....:=-        .-..:-=*%#:
                    --...........::::=+*+:                   ....:=-        .-..:-+#%*.
                    :-....... .....:::::=++=.                ....:=-      .--.:-+#%*:
                    :-.......   .........::-==:               ...:=-     :-::-=#%*:
                    :-.......     ..:........:--:.            ...:=-  .---:-=*#*:
                    :-........      .:::.........::.          ...:=-.---:-+**+:
                ... ::......:.  .      :-::.....  ...          .:===---=+*+-
              .::.  ::......:.   ..      .--:..              .:===---=+=-.
           .:--.    :-......:. .   ..      .:-:.          .-===---==-:.
         ::=+:      :-....:::. .      ..      :--.    .:==+==-==-:::
       .==++.       :-::::.    .        ..      .---==+===---:..  .-
      -+=#+         :==-:    ...             ..:-====----:.      .:-
     =*+*#          -*:      .::          .:-------::...       ...:-
    -#=+#=          ..     .:-:      .:::---:::::.     .:..  .....--
    #*===*:             ..--:   ..:::::::...             :-:...:::==
    ##=-----:..       ....:  ........                      :==----+=
    .*#+=-:.......         ...                               :+*++*=
      :-===--::.......:.                                       :+#%=
                    ..                                     ...  .:*=
                                                             .:.. .-
                                                               .:::-
                                                                 .:-
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
    echo "ERROR: /sbin/init is missing or not executable." >&2
    exit 1
fi

INIT_TARGET="$(readlink -f /sbin/init)"
if [[ -z "$INIT_TARGET" || ! -x "$INIT_TARGET" ]]; then
    echo "ERROR: /sbin/init does not resolve to an executable." >&2
    exit 1
fi

if [[ ! -s /etc/inittab ]]; then
    echo "ERROR: /etc/inittab is missing or empty; SysVinit cannot start normally." >&2
    exit 1
fi

INIT_DEPS="$(ldd "$INIT_TARGET" 2>&1 || true)"
if grep -q "not found" <<<"$INIT_DEPS"; then
    echo "ERROR: PID 1 has missing shared-library dependencies:" >&2
    printf '%s\\n' "$INIT_DEPS" >&2
    exit 1
fi

echo "PID 1 executable: $INIT_TARGET"
echo "SysVinit configuration and shared-library checks passed."

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

    sed -i \
        -e 's/^Name=.*/Name=Install NOVA Linux/' \
        -e 's/^GenericName=.*/GenericName=NOVA Linux Installer/' \
        -e 's/^Comment=.*/Comment=Install NOVA Linux on this computer/' \
        -e 's/^Keywords=.*/Keywords=nova;linux;system;install;installer/' \
        -e 's/^Icon=.*/Icon=nova-installer/' \
        "$ROOTFS/usr/share/applications/nova-installer.desktop"

    # Supply a NOVA icon and remove Debian's duplicate launcher/autostart icon.
    install -D -m 0644 \
        "$ROOTFS/etc/calamares/branding/nova/nova-logo.svg" \
        "$ROOTFS/usr/share/pixmaps/nova-installer.svg"
    rm -f "$ROOTFS/usr/share/applications/calamares-install-debian.desktop"
    rm -f "$ROOTFS/etc/xdg/autostart/calamares-desktop-icon.desktop"

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

echo "==> Preparing live-root mount points"

# The chroot bind mounts must be removed before packaging the root filesystem.
# Otherwise the build host's /dev, /proc and /sys could leak into the live image.
cleanup

# Keep the mount-point directories in SquashFS, but never package transient
# contents from the build host or the chroot.
mkdir -p "$ROOTFS/dev/pts" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run" "$ROOTFS/tmp"
find "$ROOTFS/dev" -mindepth 1 -maxdepth 1 ! -name pts -exec rm -rf -- {} +
find "$ROOTFS/dev/pts" -mindepth 1 -delete
find "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run" "$ROOTFS/tmp" -mindepth 1 -delete
chmod 0755 "$ROOTFS/dev" "$ROOTFS/dev/pts" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run"
chmod 1777 "$ROOTFS/tmp"

echo "==> Validating live root before SquashFS"

if [[ ! -x "$ROOTFS/sbin/init" ]]; then
    echo "ERROR: live root has no executable /sbin/init." >&2
    exit 1
fi

if [[ ! -s "$ROOTFS/etc/inittab" ]]; then
    echo "ERROR: live root has no /etc/inittab." >&2
    exit 1
fi

INIT_TARGET="$(chroot "$ROOTFS" readlink -f /sbin/init)"
if [[ -z "$INIT_TARGET" ]] || ! chroot "$ROOTFS" test -x "$INIT_TARGET"; then
    echo "ERROR: /sbin/init does not resolve to an executable inside the live root." >&2
    exit 1
fi

echo "Live PID 1 target: $INIT_TARGET"
echo "Live mount-point directories:"
ls -ld "$ROOTFS/dev" "$ROOTFS/dev/pts" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run" "$ROOTFS/tmp"

echo "==> Building SquashFS"

mksquashfs \
    "$ROOTFS" \
    "$ISO_ROOT/live/filesystem.squashfs" \
    -comp xz \
    -b 1M \
    -noappend

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
