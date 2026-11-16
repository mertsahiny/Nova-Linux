#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${1:-${ROOTFS:-/nova-root}}"
if [[ ! -d "$ROOTFS/var/lib/dpkg" || ! -s "$ROOTFS/var/lib/dpkg/status" ]]; then
    echo "ERROR: $ROOTFS is not a configured Debian root filesystem." >&2
    exit 1
fi

fail() {
    echo "FAIL: $*" >&2
    exit 1
}
ok() {
    echo "PASS: $*"
}

echo "=== NOVA ROOT FILESYSTEM VALIDATION ==="

required_packages=(
    sysvinit-core openrc systemd-standalone-sysusers
    initscripts udev
    live-boot live-boot-initramfs-tools initramfs-tools live-tools
    live-config live-config-sysvinit
    linux-image-amd64
    dbus elogind libpam-elogind
    network-manager wpasupplicant plasma-nm rfkill wireless-regdb
    sddm kde-plasma-desktop
    pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber
    libspa-0.2-modules alsa-utils alsa-ucm-conf plasma-pa
    calamares calamares-settings-debian
    firmware-misc-nonfree firmware-iwlwifi firmware-realtek
    firmware-intel-graphics firmware-amd-graphics
    mesa-utils libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers libvulkan1
    steam-installer lutris wine wine64 wine32 winetricks gamemode mangohud
)

for package in "${required_packages[@]}"; do
    status="$(dpkg-query --admindir="$ROOTFS/var/lib/dpkg" -W -f='${Status}' "$package" 2>/dev/null || true)"
    [[ "$status" == "install ok installed" ]] || fail "Required package is not installed: $package"
done
ok "All required boot, desktop, firmware, audio and gaming packages are installed"

init_target="$(chroot "$ROOTFS" readlink -f /sbin/init)"
[[ -n "$init_target" ]] || fail "/sbin/init does not resolve"
chroot "$ROOTFS" test -x "$init_target" || fail "PID 1 target is not executable: $init_target"
init_owner="$(dpkg-query --admindir="$ROOTFS/var/lib/dpkg" -S /sbin/init 2>/dev/null || true)"
grep -q '^sysvinit-core:' <<<"$init_owner" || fail "/sbin/init is not owned by sysvinit-core"
grep -Eq '^id:[0-6]:initdefault:' "$ROOTFS/etc/inittab" || fail "No default SysVinit runlevel"
ok "SysVinit is installed as PID 1 with a valid inittab"

for service in dbus elogind network-manager sddm nova-boot-smoke; do
    [[ -x "$ROOTFS/etc/init.d/$service" ]] || fail "OpenRC service is missing: $service"
    [[ -L "$ROOTFS/etc/runlevels/default/$service" ]] || fail "OpenRC service is not enabled: $service"
done
[[ -x "$ROOTFS/etc/init.d/udev" ]] || fail "udev service script is missing"
[[ -L "$ROOTFS/etc/runlevels/sysinit/udev" ]] || fail "udev is not enabled in sysinit"
ok "OpenRC services and early udev startup are configured"

initrd="$(find "$ROOTFS/boot" -maxdepth 1 -type f -name 'initrd.img-*' | sort -V | tail -n1)"
[[ -s "$initrd" ]] || fail "No kernel initramfs was generated"
initrd_inside="/boot/${initrd##*/}"
chroot "$ROOTFS" lsinitramfs "$initrd_inside" | grep -Fxq 'scripts/live' || fail "Initramfs is missing scripts/live"
ok "Generated initramfs contains the live-boot script"

[[ -x "$ROOTFS/usr/bin/calamares-install-debian" ]] || fail "Calamares live installer helper is missing"
grep -q '^branding: nova$' "$ROOTFS/etc/calamares/settings.conf" || fail "Calamares is not using NOVA branding"
grep -q '^Exec=/usr/bin/calamares-install-debian$' "$ROOTFS/usr/share/applications/nova-installer.desktop" || fail "NOVA installer launcher has an incorrect Exec"
[[ -s "$ROOTFS/usr/share/pixmaps/nova-installer.svg" ]] || fail "NOVA installer icon is missing"
ok "Calamares helper, branding and desktop launcher are present"

[[ -x "$ROOTFS/usr/local/bin/nova-audio-session" ]] || fail "NOVA PipeWire session launcher is missing"
[[ -s "$ROOTFS/etc/xdg/autostart/nova-audio.desktop" ]] || fail "NOVA audio autostart entry is missing"
[[ -s "$ROOTFS/home/nova/.config/kdeglobals" ]] || fail "NOVA user KDE configuration is missing"
grep -q '^Theme=NOVA$' "$ROOTFS/home/nova/.config/kdeglobals" || fail "NOVA icon theme is not selected for the live user"
ok "Audio autostart and NOVA desktop branding are present"

echo "=== ALL ROOT FILESYSTEM CHECKS PASSED ==="
