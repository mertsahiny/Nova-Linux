
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
    live-boot-initramfs-tools \
    initramfs-tools \
    live-tools \
    initscripts \
    network-manager \
    plasma-nm \
    wpasupplicant \
    wireless-regdb \
    rfkill \
    x11-xserver-utils \
    pkexec \
    xserver-xorg \
    sddm \
    sddm-theme-breeze \
    kde-plasma-desktop \
    kwin-x11 \
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
    pipewire-alsa \
    pipewire-pulse \
    wireplumber \
    libspa-0.2-modules \
    alsa-utils \
    alsa-ucm-conf \
    plasma-pa \
    procps \
    bluez \
    blueman \
    powerdevil \
    brightnessctl \
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
    firmware-linux \
    firmware-linux-nonfree \
    firmware-intel-graphics \
    firmware-amd-graphics \
    firmware-iwlwifi \
    firmware-realtek \
    firmware-atheros \
    firmware-brcm80211 \
    firmware-mediatek \
    firmware-libertas \
    mesa-utils \
    libgl1-mesa-dri:amd64 \
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

echo "==> Regenerating initramfs with live-boot support"

# live-boot's initramfs-tools backend is required to find and mount
# /live/filesystem.squashfs. Rebuild after all live-boot packages are installed.
kernel_count=0
for module_dir in /lib/modules/*; do
    [[ -d "$module_dir" ]] || continue
    kernel_version="${module_dir##*/}"
    initrd="/boot/initrd.img-${kernel_version}"
    if [[ -s "$initrd" ]]; then
        update-initramfs -u -k "$kernel_version"
    else
        update-initramfs -c -k "$kernel_version"
    fi
    kernel_count=$((kernel_count + 1))
done

if [[ "$kernel_count" -eq 0 ]]; then
    echo "ERROR: No installed kernel modules were found." >&2
    exit 1
fi

LIVE_INITRD="$(find /boot -maxdepth 1 -type f -name 'initrd.img-*' | sort -V | tail -n1)"
if [[ -z "$LIVE_INITRD" || ! -s "$LIVE_INITRD" ]]; then
    echo "ERROR: No generated initramfs was found." >&2
    exit 1
fi

INITRD_CONTENTS="$(lsinitramfs "$LIVE_INITRD")"
if ! grep -Fxq 'scripts/live' <<<"$INITRD_CONTENTS"; then
    echo "ERROR: ${LIVE_INITRD} does not contain the live-boot initramfs script." >&2
    echo "Install live-boot-initramfs-tools and regenerate the initramfs." >&2
    exit 1
fi
echo "Verified live-boot script in ${LIVE_INITRD}"

echo "==> Configuring locale"

sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

echo "==> Configuring hostname"
echo "nova" > /etc/hostname

echo "==> Creating live user"

for group in netdev audio; do
    if ! getent group "$group" >/dev/null 2>&1; then
        groupadd --system "$group"
    fi
done

if ! id nova >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev nova
else
    usermod -aG audio,netdev nova
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

if [[ ! -s /usr/share/sddm/themes/breeze/theme.conf ]]; then
    echo "ERROR: Breeze SDDM theme is missing. Install sddm-theme-breeze." >&2
    exit 1
fi

rm -rf /usr/share/sddm/themes/nova
cp -a /usr/share/sddm/themes/breeze /usr/share/sddm/themes/nova
install -m 0644 /etc/calamares/branding/nova/nova-logo.svg /usr/share/sddm/themes/nova/default-logo.svg
if [[ -f /usr/share/sddm/themes/nova/metadata.desktop ]]; then
    sed -i 's/^Name=.*/Name=NOVA/' /usr/share/sddm/themes/nova/metadata.desktop
fi

cat > /etc/sddm.conf.d/nova.conf <<'EOF'
[Autologin]
User=nova
Session=plasmax11.desktop
Relogin=false

[Theme]
Current=nova
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

# Plasma versions and applets may request one of these standard launcher names.
cp /usr/share/icons/NOVA/places/scalable/start-here-kde.svg /usr/share/icons/NOVA/places/scalable/start-here.svg
cp /usr/share/icons/NOVA/places/scalable/start-here-kde.svg /usr/share/icons/NOVA/places/scalable/start-here-plasma.svg

cat > /etc/xdg/kdeglobals <<'NOVA_KDE_GLOBALS'
[Icons]
Theme=NOVA
NOVA_KDE_GLOBALS

# Plasma reads per-user settings ahead of the system defaults. Set the live
# user's icon theme explicitly so the panel launcher uses NOVA artwork too.
mkdir -p /home/nova/.config
cat > /home/nova/.config/kdeglobals <<'NOVA_USER_KDE_GLOBALS'
[Icons]
Theme=NOVA
NOVA_USER_KDE_GLOBALS
chown -R nova:nova /home/nova/.config

echo "==> Configuring NOVA audio autostart"

# OpenRC does not provide systemd --user socket activation. Start PipeWire
# components inside the logged-in Plasma session instead.
mkdir -p /usr/local/bin /etc/xdg/autostart
cat > /usr/local/bin/nova-audio-session <<'NOVA_AUDIO_SESSION'
#!/bin/sh
# Start the PipeWire user services in dependency order and leave diagnostics
# in the user's cache if the desktop session cannot provide audio.
set -u
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || exit 0

if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$(id -u)" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
[ -d "${XDG_RUNTIME_DIR:-/nonexistent}" ] || exit 0

mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/nova-audio.log"

if ! pgrep -u "$(id -u)" -x pipewire >/dev/null 2>&1; then
    pipewire >>"$LOG" 2>&1 &
fi

# Wait for PipeWire's core socket before starting its session manager and
# PulseAudio compatibility server.
attempt=0
while [ "$attempt" -lt 10 ]; do
    if pw-cli info 0 >/dev/null 2>&1; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done

if ! pw-cli info 0 >/dev/null 2>&1; then
    echo "PipeWire did not become ready; see this log and the desktop session journal." >>"$LOG"
    exit 1
fi

if ! pgrep -u "$(id -u)" -x wireplumber >/dev/null 2>&1; then
    wireplumber >>"$LOG" 2>&1 &
fi
if ! pgrep -u "$(id -u)" -x pipewire-pulse >/dev/null 2>&1; then
    pipewire-pulse >>"$LOG" 2>&1 &
fi
NOVA_AUDIO_SESSION
chmod 0755 /usr/local/bin/nova-audio-session

cat > /etc/xdg/autostart/nova-audio.desktop <<'NOVA_AUDIO_DESKTOP'
[Desktop Entry]
Type=Application
Name=NOVA Audio
Comment=Start PipeWire audio services for this desktop session
Exec=/usr/local/bin/nova-audio-session
Terminal=false
OnlyShowIn=KDE;
X-GNOME-Autostart-enabled=true
NOVA_AUDIO_DESKTOP

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

mkdir -p /etc/runlevels/sysinit /etc/runlevels/default /etc/runlevels/boot /etc/runlevels/shutdown

# Debian may enable bootlogs through package defaults, but its legacy bootlogd
# backend is not configured in this live image. It exits non-zero under OpenRC.
rc-update del bootlogs boot >/dev/null 2>&1 || true
rc-update del bootlogs default >/dev/null 2>&1 || true
rm -f /etc/runlevels/boot/bootlogs /etc/runlevels/default/bootlogs

# udev must be running before desktop and network services. Debian supplies
# its SysV-compatible service in initscripts; OpenRC can manage it in sysinit.
if [[ ! -x /etc/init.d/udev ]]; then
    echo "ERROR: Debian udev init script is missing." >&2
    exit 1
fi
rc-update add udev sysinit

# Mount cgroups during early boot so elogind and applications see a working
# resource-control hierarchy on kernels that expose cgroup support.
if [[ -x /etc/init.d/cgroups ]]; then
    rc-update add cgroups sysinit
else
    echo "ERROR: OpenRC cgroups service is missing." >&2
    exit 1
fi

cat > /etc/rc.conf <<'EOF'
rc_logger="YES"
rc_log_path="/var/log/rc.log"
rc_parallel="NO"
rc_verbose="YES"
EOF

# Provide native OpenRC service scripts instead of relying on Debian's
# systemd units or SysV compatibility wrappers.
cat > /etc/init.d/dbus <<'NOVA_DBUS_INIT'
#!/sbin/openrc-run
description="D-Bus System Message Bus"
command="/usr/bin/dbus-daemon"
command_args="--system --nofork --nopidfile"
command_background="yes"
pidfile="/run/dbus/openrc.pid"

start_pre() {
    checkpath --directory --mode 0755 /run/dbus
}
NOVA_DBUS_INIT
chmod 0755 /etc/init.d/dbus

cat > /etc/init.d/elogind <<'NOVA_ELOGIND_INIT'
#!/sbin/openrc-run
description="Elogind seat and session manager"
command="/usr/libexec/elogind"
command_args_background="-D"
pidfile="/run/elogind.pid"

depend() {
    need dbus
}
NOVA_ELOGIND_INIT
chmod 0755 /etc/init.d/elogind

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/90-nova-managed.conf <<'NOVA_NETWORKMANAGER_CONF'
[ifupdown]
managed=true
NOVA_NETWORKMANAGER_CONF

# Use the NetworkManager OpenRC init script supplied by Debian's
# orphan-sysvinit-scripts package. Do not replace it with a hand-written
# backgrounding wrapper: the packaged script handles daemon and pidfile state.
if [[ ! -x /etc/init.d/network-manager ]]; then
    echo "ERROR: Debian's NetworkManager OpenRC init script is missing." >&2
    echo "Check that orphan-sysvinit-scripts was installed." >&2
    exit 1
fi

# Laptop platform, Qualcomm Atheros Wi-Fi and Bluetooth kernel support.
# The V15 G2-ALC uses ideapad_laptop, ath10k_pci (PCI ID 168c:003e),
# and btusb (Bluetooth USB ID 0cf3:e300). These modules are harmless to
# attempt on other machines; missing/inapplicable modules are non-fatal.
cat > /etc/init.d/nova-laptop-hardware <<'NOVA_LAPTOP_HARDWARE'
#!/sbin/openrc-run
description="NOVA laptop hotkeys, wireless drivers and radio unblock"

depend() {
    need udev
    before network-manager sddm
}

start() {
    ebegin "Loading NOVA laptop hardware support"
    for module in ideapad_laptop ath10k_pci btusb; do
        if modprobe "$module"; then
            einfo "Loaded $module (or it is already loaded)"
        else
            ewarn "Could not load $module on this hardware; continuing"
        fi
    done

    if command -v rfkill >/dev/null 2>&1; then
        rfkill unblock all || ewarn "Could not clear software radio blocks"
    fi
    eend 0
}
NOVA_LAPTOP_HARDWARE
chmod 0755 /etc/init.d/nova-laptop-hardware

cat > /etc/init.d/sddm <<'NOVA_SDDM_INIT'
#!/sbin/openrc-run
description="Simple Desktop Display Manager"
command="/usr/bin/sddm"
command_background="yes"
pidfile="/run/sddm-openrc.pid"

depend() {
    need dbus elogind
    after localmount
}
NOVA_SDDM_INIT
chmod 0755 /etc/init.d/sddm

for service in dbus elogind nova-laptop-hardware network-manager sddm; do
    if [[ ! -x "/etc/init.d/$service" ]]; then
        echo "ERROR: Required OpenRC service is missing: $service" >&2
        exit 1
    fi
    echo "Enabling $service"
    rc-update add "$service" default
done

# SysVinit PID 1 with OpenRC's native runlevel integration.
# OpenRC uses named runlevels, so map the traditional SysV runlevels explicitly.
cat > /etc/inittab <<'NOVA_INITTAB'
id:3:initdefault:
si::sysinit:/sbin/openrc sysinit
rc::bootwait:/sbin/openrc boot
l0:0:wait:/sbin/openrc shutdown
l0s:0:wait:/sbin/halt -d -f -i -p
l1:1:wait:/sbin/openrc single
l2:2:wait:/sbin/openrc nonetwork
l3:3:wait:/sbin/openrc default
l4:4:wait:/sbin/openrc default
l5:5:wait:/sbin/openrc default
l6:6:wait:/sbin/openrc reboot
l6r:6:wait:/sbin/reboot -d
ca:12345:ctrlaltdel:/sbin/shutdown -r now
c1:12345:respawn:/sbin/agetty --noclear 38400 tty1 linux
c2:2345:respawn:/sbin/agetty 38400 tty2 linux
c3:2345:respawn:/sbin/agetty 38400 tty3 linux
c4:2345:respawn:/sbin/agetty 38400 tty4 linux
c5:2345:respawn:/sbin/agetty 38400 tty5 linux
c6:2345:respawn:/sbin/agetty 38400 tty6 linux
NOVA_INITTAB

# A harmless serial marker lets CI prove that the live root switched to
# SysVinit/OpenRC and reached the default runlevel in a virtual machine.
cat > /etc/init.d/nova-boot-smoke <<'NOVA_BOOT_SMOKE_INIT'
#!/sbin/openrc-run
description="NOVA live boot smoke-test marker"

depend() {
    after dbus elogind network-manager sddm
}

start() {
    ebegin "Checking NOVA networking and marking live boot complete"
    if ! pgrep -x NetworkManager >/dev/null 2>&1; then
        printf '%s\\n' "NOVA_NETWORK_MANAGER_MISSING" > /dev/ttyS0 2>/dev/null || true
        eend 1 "NetworkManager did not start"
        return 1
    fi

    # In CI, QEMU presents an e1000 NIC with user-mode DHCP. Wait for the
    # interface to become connected so the smoke test checks more than a PID.
    attempt=0
    while [ "$attempt" -lt 45 ]; do
        if nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q '^ethernet:connected$'; then
            printf '%s\\n' "NOVA_NETWORK_MANAGER_RUNNING" > /dev/ttyS0 2>/dev/null || true
            printf '%s\\n' "NOVA_NETWORK_CONNECTED" > /dev/ttyS0 2>/dev/null || true
            printf '%s\\n' "NOVA_BOOT_COMPLETED" > /dev/ttyS0 2>/dev/null || true
            eend 0
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    printf '%s\\n' "NOVA_NETWORK_NOT_CONNECTED" > /dev/ttyS0 2>/dev/null || true
    eend 1 "NetworkManager did not connect the QEMU Ethernet device"
    return 1
}
NOVA_BOOT_SMOKE_INIT
chmod 0755 /etc/init.d/nova-boot-smoke
rc-update add nova-boot-smoke default

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

# /sbin/init may be a usr-merged symlink, so checking its dpkg file
# ownership is unreliable. The sysvinit-core package status was checked above;
# here we verify that the resolved init target is present and executable.

if [[ ! -s /etc/inittab ]]; then
    echo "ERROR: /etc/inittab is missing or empty; SysVinit cannot start normally." >&2
    exit 1
fi

if ! grep -Eq '^id:[0-6]:initdefault:' /etc/inittab; then
    echo "ERROR: /etc/inittab has no default runlevel." >&2
    exit 1
fi

INIT_DEPS="$(ldd "$INIT_TARGET" 2>&1 || true)"
if grep -q "not found" <<<"$INIT_DEPS"; then
    echo "ERROR: PID 1 has missing shared-library dependencies:" >&2
    printf '%s\n' "$INIT_DEPS" >&2
    exit 1
fi

echo "PID 1 executable: $INIT_TARGET"
echo "SysVinit configuration and shared-library checks passed."

for package in live-boot live-boot-initramfs-tools initramfs-tools live-config live-config-sysvinit; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        echo "ERROR: Required live-boot package is not installed: $package" >&2
        exit 1
    fi
done

if [[ ! -x /usr/bin/sddm || ! -x /usr/libexec/elogind || ! -x /usr/sbin/NetworkManager || ! -x /usr/bin/dbus-daemon ]]; then
    echo "ERROR: One or more required desktop/session/network daemons are missing." >&2
    exit 1
fi

echo "==> Cleaning package cache"
apt-get clean
rm -rf /var/lib/apt/lists/*

rm -f /usr/sbin/policy-rc.d

echo "==> Chroot configuration complete"
CHROOT

echo "==> Preparing NOVA Calamares launcher"

mkdir -p "$ROOTFS/usr/share/applications" "$ROOTFS/home/nova/Desktop"

# Keep Debian's live-media helper: it prepares the live fstab, grants the
# temporary X access needed by root, and starts Calamares through pkexec.
if [[ ! -x "$ROOTFS/usr/bin/calamares-install-debian" ]]; then
    echo "ERROR: Debian Calamares live launcher is missing." >&2
    exit 1
fi

# Launch from Konsole so failures are visible instead of silently disappearing
# behind a desktop click. The Debian helper still handles X access and pkexec.
cat > "$ROOTFS/usr/local/bin/nova-installer-launcher" <<'NOVA_INSTALLER_LAUNCHER'
#!/bin/sh
set +e
echo "Starting the NOVA Linux installer..."
echo "If Calamares does not appear, inspect ~/.cache/nova-installer.log"
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/nova-installer.log"
/usr/bin/calamares-install-debian >>"$LOG" 2>&1
status=$?
echo
echo "Calamares launcher exited with status $status."
echo "Log: $LOG"
if [ "$status" -ne 0 ]; then
    echo "The installer failed. Log follows:"
    cat "$LOG"
fi
exit "$status"
NOVA_INSTALLER_LAUNCHER
chmod 0755 "$ROOTFS/usr/local/bin/nova-installer-launcher"

cat > "$ROOTFS/usr/share/applications/nova-installer.desktop" <<'NOVA_INSTALLER_DESKTOP'
[Desktop Entry]
Type=Application
Version=1.0
Name=Install NOVA Linux
GenericName=NOVA Linux Installer
Comment=Install NOVA Linux on this computer
Keywords=nova;linux;system;install;installer;
TryExec=/usr/bin/konsole
Exec=/usr/bin/konsole --hold -e /usr/local/bin/nova-installer-launcher
Icon=nova-installer
Terminal=false
StartupNotify=true
Categories=System;
NOVA_INSTALLER_DESKTOP

install -D -m 0644 \
    "$ROOTFS/etc/calamares/branding/nova/nova-logo.svg" \
    "$ROOTFS/usr/share/pixmaps/nova-installer.svg"

# Remove the Debian-branded launcher and its broken desktop-icon autostart.
rm -f "$ROOTFS/usr/share/applications/calamares-install-debian.desktop"
rm -f "$ROOTFS/etc/xdg/autostart/calamares-desktop-icon.desktop"

cp "$ROOTFS/usr/share/applications/nova-installer.desktop" \
    "$ROOTFS/home/nova/Desktop/Install NOVA Linux.desktop"
chmod 0755 "$ROOTFS/home/nova/Desktop/Install NOVA Linux.desktop"

NOVA_UID="$(chroot "$ROOTFS" id -u nova)"
NOVA_GID="$(chroot "$ROOTFS" id -g nova)"
chown -R "$NOVA_UID:$NOVA_GID" "$ROOTFS/home/nova"

echo "==> Installing wallpaper"

if [[ -f "$PWD/Nova Wallpaper.png" ]]; then
    install -D -m 0644 \
        "$PWD/Nova Wallpaper.png" \
        "$ROOTFS/usr/share/wallpapers/Vibes/Nova Wallpaper.png"
else
    echo "NOTICE: Nova Wallpaper.png not found."
fi

echo "==> Running root filesystem package and boot checks"
bash "$PWD/tests/test-packages.sh" "$ROOTFS"

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

serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
terminal_input console serial
terminal_output console serial

menuentry "NOVA Linux Live" {
    linux /live/vmlinuz boot=live components quiet splash username=nova hostname=nova console=tty0 console=ttyS0,115200n8
    initrd /live/initrd.img
}

menuentry "NOVA Linux Live (Safe Graphics)" {
    linux /live/vmlinuz boot=live components nomodeset username=nova hostname=nova console=tty0 console=ttyS0,115200n8
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
