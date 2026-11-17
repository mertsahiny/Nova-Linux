#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "\${EUID}" -ne 0 ]]; then
    echo "ERROR: NOVA Calamares configuration must run as root." >&2
    exit 1
fi

SETTINGS="/etc/calamares/settings.conf"
BRANDING_SOURCE="/usr/share/nova/calamares"

echo "==> Configuring the Debian Calamares modules for NOVA"

if [[ ! -s "$SETTINGS" ]]; then
    echo "ERROR: Debian's Calamares settings.conf is missing." >&2
    exit 1
fi

for module_config in mount.conf unpackfs.conf users.conf bootloader.conf; do
    if [[ ! -s "/etc/calamares/modules/$module_config" ]]; then
        echo "ERROR: Required Calamares module configuration is missing: $module_config" >&2
        exit 1
    fi
done

if [[ ! -s "$BRANDING_SOURCE/branding.desc" || ! -s "$BRANDING_SOURCE/stylesheet.qss" || ! -s "$BRANDING_SOURCE/nova-welcome.png" ]]; then
    echo "ERROR: NOVA Calamares branding assets are incomplete." >&2
    exit 1
fi

install -d -m 0755 /etc/calamares/branding/nova
install -m 0644 "$BRANDING_SOURCE/branding.desc" /etc/calamares/branding/nova/branding.desc
install -m 0644 "$BRANDING_SOURCE/stylesheet.qss" /etc/calamares/branding/nova/stylesheet.qss
install -m 0644 "$BRANDING_SOURCE/nova-welcome.png" /etc/calamares/branding/nova/nova-welcome.png

if grep -qE '^branding:' "$SETTINGS"; then
    sed -i -E 's/^branding:.*/branding: nova/' "$SETTINGS"
else
    printf '\nbranding: nova\n' >> "$SETTINGS"
fi

grep -qE '^branding:[[:space:]]+nova$' "$SETTINGS" || {
    echo "ERROR: Failed to select NOVA Calamares branding." >&2
    exit 1
}

DESKTOP_SOURCE="/usr/share/applications/calamares-install-debian.desktop"
DESKTOP_TARGET="/usr/share/applications/nova-installer.desktop"

if [[ ! -s "$DESKTOP_SOURCE" ]]; then
    echo "ERROR: Debian's Calamares launcher is missing." >&2
    exit 1
fi

install -m 0644 "$DESKTOP_SOURCE" "$DESKTOP_TARGET"
sed -i \
    -e 's/^Name=.*/Name=Install NOVA Linux/' \
    -e 's/^GenericName=.*/GenericName=System Installer/' \
    -e 's/^Comment=.*/Comment=Install NOVA Linux on this computer/' \
    -e 's/^Icon=.*/Icon=calamares/' \
    "$DESKTOP_TARGET"

echo "==> NOVA Calamares branding and launcher configured"
