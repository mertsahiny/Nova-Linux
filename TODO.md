NOVA Linux 0.1.0 - Supernova

## Phase 1: Bootstrap - Fresh debootstrap root filesystem
- [x] Download Debian bootstrap tools
- [x] Create amd64 Debian Trixie root filesystem
- [x] Configure package repositories
- [x] Configure APT
- [x] Configure hostname as nova
- [x] Configure locale and timezone defaults
- [x] Configure system users and groups
- [x] Configure filesystem directories
- [x] Configure systemd integration
- [x] Configure DNS and networking defaults
- [x] Validate root filesystem

## Phase 2: System Foundation
- [x] Linux kernel packages
- [x] Kernel modules and firmware
- [x] Initramfs-tools
- [x] systemd
- [x] udev
- [x] GRUB
- [x] APT configuration
- [x] NetworkManager
- [x] sudo
- [x] Essential command-line utilities

## Phase 3: KDE Plasma Desktop
- [x] KDE Plasma desktop
- [x] SDDM display manager
- [x] KDE Frameworks
- [x] KWin
- [x] Dolphin, Konsole, Kate
- [x] KDE System Settings
- [x] KDE Discover
- [x] PipeWire audio
- [x] Bluetooth support
- [x] Polkit
- [x] Desktop notifications

## Phase 4: NOVA Branding
- [ ] NOVA logo design
- [ ] NOVA icon set
- [ ] GRUB branding
- [ ] SDDM branding
- [ ] Desktop theme
- [ ] Splash screen
- [ ] Vibes wallpaper collection

## Phase 5: Software Selection
- [ ] Firefox ESR
- [ ] LibreOffice
- [ ] Dolphin, Konsole, Kate
- [ ] KDE Discover
- [ ] System Settings
- [ ] Archive manager
- [ ] Screenshot utility
- [ ] Text editor
- [ ] PDF viewer
- [ ] Network tools

## Phase 6: Installer
- [ ] Calamares integration
- [ ] Custom NOVA branding
- [ ] Language selection
- [ ] Keyboard selection
- [ ] Timezone selection
- [ ] Partition configuration
- [ ] Bootloader installation
- [ ] User creation
- [ ] User password configuration

## Phase 7: Live Boot
- [ ] Bootable hybrid ISO
- [ ] BIOS and UEFI support
- [ ] GRUB integration
- [ ] Correct kernel and initramfs placement
- [ ] Live root filesystem
- [ ] Live user session
- [ ] Functional KDE desktop
- [ ] Installer launcher

## Phase 8: GitHub Actions
- [ ] Build workflow automation
- [ ] Disk space monitoring
- [ ] Package caching
- [ ] Artifact generation

## Phase 9: Quality Assurance
- [ ] Root filesystem structure validation
- [ ] Package installation checks
- [ ] Kernel availability verification
- [ ] Initramfs generation tests
- [ ] GRUB configuration checks
- [ ] ISO filesystem structure validation
- [ ] Branding asset verification
- [ ] Vibes wallpaper installation check
- [ ] SHA256 checksum validation

## Hardware Support Audit - NOVA Linux 0.1.0
- [x] Configure Debian Trixie repositories (main, contrib, non-free, non-free-firmware)
- [x] Intel and AMD CPU microcode packages (intel-microcode, amd64-microcode)
- [x] Intel and AMD GPU firmware and open-source drivers
  - firmware-intel-graphics = firmware only (not kernel drivers)
  - firmware-amd-graphics = firmware only (not kernel drivers)
  - Kernel: i915/xe (Intel), amdgpu/radeon (AMD) provided by linux-image-amd64
  - Mesa: provides userspace graphics acceleration
- [x] Mesa 3D graphics library (mesa-utils, libgl1-mesa-dri, libglapi-mesa, libglx-mesa0)
- [x] NVIDIA Nouveau support by default (open-source, included automatically)
  - No proprietary firmware required for Nouveau
  - Hardware compatibility varies by GPU generation
- [ ] Proprietary NVIDIA drivers OPTIONAL (post-installation only, not force-installed)
- [x] Kernel headers and DKMS support
- [x] Hybrid graphics support configuration (open-source stack auto-detects)
- [x] Validation tests for package availability and configuration
- [x] Hardware compatibility disclaimer noted (no physical testing claimed)
- [x] Verified every package name against Debian Trixie repositories
  - Removed nonexistent: xserver-xorg-video-intel (not required for modern Intel GPUs)
  - Removed nonexistent: xserver-xorg-video-amd (replaced with firmware-amd-graphics)
  - Removed nonexistent: amd-graphics-amdgpu (replaced with firmware-amd-graphics)
  - Verified: bluealsa-alsa NOT included (NOVA uses BlueZ + PipeWire audio stack)
  - Verified: mesa-va-drivers for AMD VA-API (replaces libva-driver-amdgpu)
  - Verified: mesa-vulkan-drivers for Vulkan support
  - Verified: bluealsa-alsa NOT included (per audit requirement #2)
  - Verified: intel-microcode, amd64-microcode
  - Verified: firmware-misc-nonfree, firmware-iwlwifi, firmware-realtek
  - Verified: firmware-intel-graphics, firmware-amd-graphics (firmware, not kernel drivers)
  - Verified: libgl1-mesa-dri, libglapi-mesa, libglx-mesa0 (Mesa userspace)
  - Verified: mesa-utils, mesa-va-drivers, mesa-vulkan-drivers
## Gaming Support - NOVA Linux 0.1.0
- [x] Steam (optional post-installation - requires multi-arch i386)
- [x] Lutris (optional post-installation)
- [x] Wine64 (optional post-installation - 64-bit Windows games)
- [x] Wine32 (optional post-installation - 32-bit Windows games)
- [x] Winetricks (optional post-installation - helper for Wine)
- [x] GameMode (optional post-installation - performance enhancer)
- [x] MangoHud (optional post-installation - Vulkan/HUD overlay)
- [x] Mesa Vulkan drivers (mesa-vulkan-drivers - included in default build)
- [x] Vulkan loader (vulkan-loader, vulkan-loader:i386 - included in default build)
- [x] 32-bit Mesa libraries (libgl1-mesa-dri:i386 - post-installation via multi-arch)
- [x] Graphics compatibility: AMD (amdgpu/radeon + Mesa), Intel (i915/xe + Mesa), NVIDIA (Nouveau by default, proprietary optional)
- [x] Vulkan and OpenGL userspace libraries available
- [x] Multi-architecture (i386) support for 32-bit game compatibility - enabled post-installation
- [x] Gaming configuration: Steam menu integration, Lutris detection, GameMode, MangoHud
- [x] PipeWire audio for gaming sound
- [x] Automated gaming package availability checks
- [ ] Actual game launch testing (not claimed until games are tested)
- [ ISO size impact: ~140MB additional for full gaming stack; optional post-installation to manage size
- [ i386 multiarch enabled on installed system: sudo dpkg --add-architecture i386 + sudo apt-get update