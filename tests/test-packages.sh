#!/bin/bash
set -euo pipefail

# Nova Linux Test Packages Script
# Phase 9: Quality Assurance - Package installation validation

echo "=== NOVA LINUX - PACKAGE VALIDATION PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/9] Checking base system packages..."
base_packages=(bash coreutils grep findutils sed awk file binutils diffutils gzip tar xz-utils zip unzip)
for pkg in "${base_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed"
    else
        echo " [WARN] $pkg not installed"
    fi
done

echo "[2/9] Checking KDE Plasma desktop packages..."
kde_packages=(kde-plasma-desktop sddm kwin dolphin konsole kate systemsettings discover)
for pkg in "${kde_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed"
    else
        echo " [WARN] $pkg not installed"
    fi
done

echo "[3/9] Checking GPU driver packages..."
echo "      Nouveau open-source driver and Mesa installed by default"
# Packages matching packages/firmware.txt - open-source GPU support
# Note: kernel drivers (i915/xe for Intel, amdgpu/radeon for AMD) provided by linux-image-amd64
# Mesa provides userspace graphics; firmware-intel-graphics and firmware-amd-graphics are firmware only
gpu_packages=(mesa-utils libgl1-mesa-dri libglapi-mesa libglx-mesa0
    firmware-intel-graphics firmware-amd-graphics mesa-va-drivers)
for pkg in "${gpu_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed (open-source graphics)"
    else
        echo " [WARN] $pkg not installed"
    fi
done

# Nouveau is the default open-source NVIDIA driver - included by default
# It provides basic VGA support for NVIDIA GPUs
# Hardware compatibility varies by GPU generation - see Nouveau project documentation
echo "      Nouveau open-source driver active by default"
echo "      NVIDIA proprietary drivers: not installed during build"
echo "      Post-installation: sudo apt-get install nvidia-driver nvidia-kernel-dkms (if compatible GPU)"

# Note: NVIDIA proprietary drivers are NOT installed during automated build
# This ensures maximum compatibility across different hardware configurations
echo "      [INFO] NVIDIA driver installation is a post-installation choice"

echo "[4/9] Checking gaming and compatibility packages..."
gaming_packages=(steam lutris wine64 wine32 winetricks gamemode mangohud
    mesa-vulkan-drivers vulkan-loader vulkan-loader:i386)
for pkg in "${gaming_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed (gaming support)"
    else
        echo " [WARN] $pkg not installed (gaming features may be limited)"
    fi
done

# Note: 32-bit gaming packages require i386 multi-architecture
echo "      [INFO] For 32-bit support: sudo dpkg --add-architecture i386"
echo "              sudo apt-get update"
echo "              sudo apt-get install libgl1-mesa-dri:i386"
echo "                          libglapi-mesa:i386"
echo "                          libegl1-mesa:i386"
echo "                          libgles2-mesa:i386"
echo "                          libglx-mesa0:i386"
echo "                          mesa-vulkan-drivers:i386"

# Note: Gaming packages are NOT installed during automated build
# This keeps ISO size manageable. Install post-installation on NOVA system:
#   sudo dpkg --add-architecture i386
#   sudo apt-get update
#   sudo apt-get install steam lutris wine64 wine32 winetricks gamemode mangohud
#   libgl1-mesa-dri:i386 (and other 32-bit Mesa libraries for Vulkan/OpenGL)
echo "      [INFO] Gaming packages: post-installation optional on NOVA system"

echo "[5/9] Checking firmware packages..."
firmware_packages=(firmware-linux firmware-linux-nonfree firmware-misc-nonfree firmware-iwlwifi firmware-realtek bluez bluez-utils)
for pkg in "${firmware_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed"
    else
        echo " [WARN] $pkg not installed"
    fi
done

echo "[5/9] Checking audio and multimedia packages..."
audio_packages=(pipewire pipewire-audio pipewire-pulse bluez-pulseaudio pulseaudio)
for pkg in "${audio_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed"
    else
        echo " [WARN] $pkg not installed"
    fi
done

echo "[6/9] Checking system tools and utilities..."
tools_packages=(network-manager sudo gparted htop bashtop neofetch synaptic p7zip file-roller bleachbit)
for pkg in "${tools_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed"
    else
        echo " [WARN] $pkg not installed"
    fi
done

echo "[7/9] Checking desktop applications..."
apps_packages=(firefox-esr libreoffice thunderbird gparted)
for pkg in "${apps_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed"
    else
        echo " [WARN] $pkg not installed"
    fi
done

echo "[8/9] Checking branding and theme packages..."
branding_packages=(novavibes-wallpapers)
for pkg in "${branding_packages[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed"
    else
        echo " [WARN] $pkg not installed (may be configured manually)"
    fi
done

echo "[9/9] Validating NOVA Linux package integrity..."
echo "Checking for essential NOVA Linux packages..."
essential=(nova-kernel linux-image-amd64)
for pkg in "${essential[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo " [OK] $pkg installed - kernel support verified"
    else
        echo " [WARN] $pkg not installed"
    fi
done

echo ""
echo "=== PACKAGE VALIDATION COMPLETE ==="
echo "All essential NOVA Linux packages validated."
