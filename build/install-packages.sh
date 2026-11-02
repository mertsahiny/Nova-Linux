#!/bin/bash
set -euo pipefail

# Nova Linux Install Packages Script
# Phases 2 & 3: System packages and KDE Plasma desktop

echo "=== NOVA LINUX - PACKAGE INSTALLATION PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/6] Updating package lists..."
apt-get update

echo "[2/6] Installing core system packages..."
apt-get install -y \
    bash \
    coreutils \
    grep \
    findutils \
    sed \
    awk \
    file \
    binutils \
    diffutils \
    gzip \
    tar \
    xz-utils \
    zip \
    unzip

echo "[3/6] Installing KDE Plasma desktop and applications..."
apt-get install -y \
    kde-plasma-desktop \
    sddm \
    kwin \
    dolphin \
    konsole \
    kate \
    systemsettings \
    kded5 \
    kdeclarative \
    kio-extras \
    discover \
    discover-offline

echo "[4/6] Installing multimedia and audio..."
apt-get install -y \
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    pipewire-jack \
    bluez \
    bluez-utils \
    pulseaudio \
    pulsemixer \
    firefox-esr \
    libreoffice \
    thunderbird

echo "[4.5/6] Installing open-source Nouveau and Mesa by default"
echo "      NVIDIA proprietary drivers are optional post-installation"

# Open-source graphics: Intel and AMD kernel drivers + Mesa
# xserver-xorg-video-intel NOT required for modern Intel GPUs
# using kernel i915/xe drivers + Mesa + firmware-intel-graphics
apt-get install -y \
    mesa-utils \
    libgl1-mesa-dri \
    libglapi-mesa \
    libglx-mesa0

# Nouveau is the default open-source NVIDIA driver
# It's pulled in as a dependency of linux-image-amd64 and xorg
# NVIDIA proprietary drivers are NOT installed during build
# They are available as a post-installation configuration option
# Users can install them manually after boot if needed:
#   sudo apt-get install nvidia-driver nvidia-kernel-dkms

# Firmware and VA-API packages (matching packages/firmware.txt)
apt-get install -y \
    firmware-misc-nonfree \
    firmware-iwlwifi \
    firmware-realtek \
    firmware-intel-graphics \
    firmware-amd-graphics \
    mesa-va-drivers
echo "[4.5/6] Installing GPU drivers and firmware..."
echo "      Installing open-source Nouveau and Mesa by default"
echo "      NVIDIA proprietary drivers are optional post-installation"

apt-get install -y \
    xserver-xorg-video-intel \
    xserver-xorg-video-amd \
    mesa-utils \
    libgl1-mesa-dri \
    libglapi-mesa \
    libglx-mesa0

# Nouveau is the default open-source NVIDIA driver
# It's pulled in as a dependency of linux-image-amd64 and xorg

# NVIDIA proprietary drivers are NOT installed during build
# They are available as a post-installation configuration option
# Users can install them manually after boot if needed:
#   sudo apt-get install nvidia-driver nvidia-kernel-dkms
echo "      Nouveau open-source driver active by default"
echo "      NVIDIA proprietary drivers: optional post-installation"

apt-get install -y \
    firmware-misc-nonfree \
    firmware-iwlwifi \
    firmware-realtek

echo "[5/6] Installing desktop utilities and tools..."
apt-get install -y \
    ark \
    gwenview \
    kcalc \
    kdegraphics-thumbnailers \
    kde-wallpapers \
    kde-wallpapers-more \
    kbattleship \
    kmines \
    kolf \
    konquest \
    KGoldrunner \
    kpat \
    ksnakbar \
    ksysguard

echo "[6/6] Installing administration and utility tools..."
apt-get install -y \
    gparted \
    htop \
    bashtop \
    neofetch \
    synaptic \
    p7zip \
    rar \
    file-roller \
    bleachbit \
    gnome-disk-utility \
    firmware-misc-nonfree

echo ""
echo "[7/6] Installing gaming stack (optional - post-installation)"
echo "      Gaming packages are NOT installed during default build"
echo "      to keep ISO size manageable and avoid"
echo "      conflicting graphics driver stacks."
echo "      On installed NOVA system, first enable multi-architecture:"
echo "      sudo dpkg --add-architecture i386"
echo "      sudo apt-get update"
echo "      Then install gaming packages:"
echo "      sudo apt-get install steam lutris wine64 wine32"
echo "                   winetricks gamemode mangohud"
echo "      32-bit libraries:"
echo "      sudo apt-get install libgl1-mesa-dri:i386"
echo "                  libglapi-mesa:i386"
echo "                  libegl1-mesa:i386"
echo "                  libgles2-mesa:i386"
echo "                  libglx-mesa0:i386"
echo "                  mesa-vulkan-drivers:i386"
echo ""
echo "=== PACKAGE INSTALLATION COMPLETE ==="
echo "KDE Plasma desktop and essential packages installed."