#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="$1"
if [[ -z "$ROOTFS" || ! -d "$ROOTFS/var/lib/dpkg" || ! -s "$ROOTFS/var/lib/dpkg/status" ]]; then
    echo "ERROR: Pass a configured Debian root filesystem as the first argument." >&2
    exit 1
fi

fail() {
    echo "FAIL: $*" >&2
    exit 1
}
ok() {
    echo "PASS: $*"
}

package_installed() {
    local package="$1"
    local status
    status="$(dpkg-query --admindir="$ROOTFS/var/lib/dpkg" -W -f='${Status}' "$package" 2>/dev/null || true)"
    [[ "$status" == "install ok installed" ]]
}

echo "=== NOVA ROOT FILESYSTEM VALIDATION ==="

required_packages=(
    sysvinit-core openrc systemd-standalone-sysusers orphan-sysvinit-scripts
    initscripts udev
    live-boot live-boot-initramfs-tools initramfs-tools live-tools
    live-config live-config-sysvinit
    linux-image-amd64
    dbus elogind libpam-elogind
    network-manager wpasupplicant plasma-nm rfkill wireless-regdb bluez blueman firmware-atheros powerdevil brightnessctl
    sddm sddm-theme-breeze kde-plasma-desktop kwin-x11
    pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber
    libspa-0.2-modules alsa-utils alsa-ucm-conf plasma-pa
    calamares calamares-settings-debian
    firmware-misc-nonfree firmware-iwlwifi firmware-realtek
    firmware-intel-graphics firmware-amd-graphics
    mesa-utils libgl1-mesa-dri:amd64 libglx-mesa0:amd64
    mesa-vulkan-drivers:amd64 libvulkan1:amd64 mesa-va-drivers:amd64
    steam-installer lutris wine wine64 wine32:i386 winetricks gamemode mangohud
)

for package in "${required_packages[@]}"; do
    package_installed "$package" || fail "Required package is not installed: $package"
done
ok "All required boot, desktop, firmware, audio and gaming packages are installed"

init_target="$(chroot "$ROOTFS" readlink -f /sbin/init)"
[[ -n "$init_target" ]] || fail "/sbin/init does not resolve"
chroot "$ROOTFS" test -x "$init_target" || fail "PID 1 target is not executable: $init_target"
package_installed sysvinit-core || fail "sysvinit-core is not installed"

grep -Fxq 'id:3:initdefault:' "$ROOTFS/etc/inittab" || fail "OpenRC default runlevel 3 is not selected"
grep -Fxq 'si::sysinit:/sbin/openrc sysinit' "$ROOTFS/etc/inittab" || fail "inittab does not start OpenRC sysinit"
grep -Fxq 'rc::bootwait:/sbin/openrc boot' "$ROOTFS/etc/inittab" || fail "inittab does not start the OpenRC boot runlevel"
grep -Fxq 'l3:3:wait:/sbin/openrc default' "$ROOTFS/etc/inittab" || fail "SysV runlevel 3 is not mapped to OpenRC default"
grep -Fxq 'l2:2:wait:/sbin/openrc nonetwork' "$ROOTFS/etc/inittab" || fail "SysV runlevel 2 is not mapped to OpenRC nonetwork"

for command in openrc halt reboot shutdown agetty; do
    [[ -x "$ROOTFS/sbin/$command" || -x "$ROOTFS/usr/sbin/$command" ]] || fail "Required boot command is missing: $command"
done
ok "SysVinit PID 1 is mapped to OpenRC's sysinit, boot and default runlevels"

for service in dbus elogind nova-laptop-hardware network-manager sddm nova-boot-smoke; do
    [[ -x "$ROOTFS/etc/init.d/$service" ]] || fail "OpenRC service is missing: $service"
    [[ -L "$ROOTFS/etc/runlevels/default/$service" ]] || fail "OpenRC service is not enabled: $service"
done
grep -Fq 'pidfile="/run/dbus/openrc.pid"' "$ROOTFS/etc/init.d/dbus" || fail "D-Bus pidfile is outside /run/dbus"
[[ ! -e "$ROOTFS/etc/runlevels/boot/bootlogs" && ! -e "$ROOTFS/etc/runlevels/default/bootlogs" ]] || fail "Legacy bootlogs service is enabled"
for service in udev cgroups; do
    [[ -x "$ROOTFS/etc/init.d/$service" ]] || fail "Early-boot service script is missing: $service"
    [[ -L "$ROOTFS/etc/runlevels/sysinit/$service" ]] || fail "$service is not enabled in sysinit"
done
[[ -x "$ROOTFS/etc/init.d/nova-laptop-hardware" ]] || fail "NOVA laptop hardware service is missing"
sh -n "$ROOTFS/etc/init.d/nova-laptop-hardware" || fail "NOVA laptop hardware service has invalid shell syntax"
grep -Fq 'rfkill unblock all' "$ROOTFS/etc/init.d/nova-laptop-hardware" || fail "NOVA does not unblock software radio blocks"
grep -Fq 'ideapad_laptop ath10k_pci btusb' "$ROOTFS/etc/init.d/nova-laptop-hardware" || fail "NOVA laptop driver modules are not configured"
ok "OpenRC desktop services, laptop hotkeys, wireless modules, udev and cgroups are enabled"

initrd="$(find "$ROOTFS/boot" -maxdepth 1 -type f -name 'initrd.img-*' | sort -V | tail -n1)"
[[ -s "$initrd" ]] || fail "No kernel initramfs was generated"
initrd_inside="/boot/${initrd##*/}"
chroot "$ROOTFS" lsinitramfs "$initrd_inside" | grep -Fxq 'scripts/live' || fail "Initramfs is missing scripts/live"
ok "Generated initramfs contains the live-boot script"

[[ -x "$ROOTFS/usr/bin/calamares-install-debian" ]] || fail "Calamares live installer helper is missing"
[[ -x "$ROOTFS/usr/local/bin/nova-installer-launcher" ]] || fail "NOVA installer diagnostic launcher is missing"
sh -n "$ROOTFS/usr/local/bin/nova-installer-launcher" || fail "NOVA installer launcher has invalid shell syntax"
grep -Fxq 'branding: nova' "$ROOTFS/etc/calamares/settings.conf" || fail "Calamares is not using NOVA branding"
grep -Fxq 'Exec=/usr/bin/konsole --hold -e /usr/local/bin/nova-installer-launcher' "$ROOTFS/usr/share/applications/nova-installer.desktop" || fail "NOVA installer launcher does not show startup errors"
[[ -s "$ROOTFS/usr/share/pixmaps/nova-installer.svg" ]] || fail "NOVA installer icon is missing"
ok "Calamares helper, NOVA branding and visible diagnostic launcher are present"

[[ -x "$ROOTFS/usr/local/bin/nova-audio-session" ]] || fail "NOVA PipeWire session launcher is missing"
[[ -s "$ROOTFS/etc/xdg/autostart/nova-audio.desktop" ]] || fail "NOVA audio autostart entry is missing"
grep -Fxq 'managed=true' "$ROOTFS/etc/NetworkManager/conf.d/90-nova-managed.conf" || fail "NetworkManager is not configured to manage ifupdown interfaces"
grep -q 'orphan-sysvinit-scripts' "$ROOTFS/var/lib/dpkg/status" || fail "Debian OpenRC NetworkManager service package is missing"
command -v nmcli >/dev/null 2>&1 || chroot "$ROOTFS" test -x /usr/bin/nmcli || fail "NetworkManager CLI is missing"
sh -n "$ROOTFS/usr/local/bin/nova-audio-session" || fail "NOVA audio startup script has invalid shell syntax"
[[ -s "$ROOTFS/usr/share/sddm/themes/nova/theme.conf" ]] || fail "NOVA SDDM theme is missing"
[[ -s "$ROOTFS/usr/share/sddm/themes/nova/default-logo.svg" ]] || fail "NOVA SDDM logo is missing"
[[ -s "$ROOTFS/home/nova/.config/kdeglobals" ]] || fail "NOVA user KDE configuration is missing"
grep -Fxq 'Theme=NOVA' "$ROOTFS/home/nova/.config/kdeglobals" || fail "NOVA icon theme is not selected for the live user"
grep -Fxq 'Session=plasmax11.desktop' "$ROOTFS/etc/sddm.conf.d/nova.conf" || fail "SDDM is not configured for the X11 Plasma session"
grep -Fxq 'Current=nova' "$ROOTFS/etc/sddm.conf.d/nova.conf" || fail "SDDM is not configured to use NOVA branding"
[[ -s "$ROOTFS/usr/share/xsessions/plasmax11.desktop" ]] || fail "Plasma X11 session desktop file is missing"
[[ -x "$ROOTFS/usr/bin/kwin_x11" ]] || fail "KWin X11 executable is missing"
ok "Audio autostart and NOVA desktop branding are present"

echo "=== ALL ROOT FILESYSTEM CHECKS PASSED ==="
