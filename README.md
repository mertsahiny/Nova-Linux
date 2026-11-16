# NOVA Linux

Version `0.1.0` — codename **Supernova**.

NOVA is an amd64 Debian 13 (Trixie)-based live Linux distribution with KDE Plasma 6, SysVinit managed by OpenRC, SDDM, GRUB, and Calamares.

## Supported build path

The supported builder is **`build/build-all.sh`**. It creates the root filesystem, installs the live-boot backend, configures the desktop and OpenRC services, checks the root filesystem, builds the SquashFS and produces a hybrid BIOS/UEFI ISO.

On a Debian/Ubuntu build host, install the host tools:

```bash
sudo apt-get update
sudo apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin grub-common
```

Build from the repository root:

```bash
sudo env NOVA_VERSION="$(cat VERSION)" bash build/build-all.sh
```

The ISO and SHA-256 checksum are written to `out/`. GitHub Actions also runs a QEMU live-boot smoke test and uploads the ISO artifact only after the checks pass.

## System design

- **Base:** Debian 13 Trixie, amd64
- **Desktop:** KDE Plasma 6
- **Init:** SysVinit PID 1, with OpenRC runlevel/service management
- **Display manager:** SDDM with a NOVA-branded Breeze theme and Plasma X11 session
- **Networking:** NetworkManager, wpa_supplicant, managed-interface configuration and firmware packages
- **Audio:** PipeWire, WirePlumber, ALSA and Plasma volume controls
- **Installer:** Calamares with NOVA branding
- **Bootloader:** GRUB, BIOS and UEFI

## Repository notes

`build/build-all.sh` is the single supported end-to-end build. The older phase scripts under `build/configure-*.sh` and `build/assemble-iso.sh` are historical helpers and are not called by the current builder; do not mix them into the live build without first aligning them with the current SysVinit/OpenRC design.

See `TODO.md` for the project roadmap.
