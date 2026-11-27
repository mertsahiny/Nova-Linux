# NOVA Linux

Version 0.1.0 - Codename: Supernova

A Debian-derived Linux distribution.

## Architecture

- amd64 (x86_64)
- Upstream: Debian 13 Trixie
- Desktop editions: KDE Plasma 6, GNOME (experimental), Xfce, Cinnamon, LXQt, LXDE, MATE
- Default desktop: KDE Plasma 6
- Init: OpenRC service manager with Debian Trixie `sysvinit-core` as PID 1
- Default KDE display manager: SDDM
- Bootloader: GRUB
- Installer: Calamares

## Build Philosophy

NOVA is assembled from upstream components using debootstrap, not modified ISOs.

## Repository Structure

Desktop editions are selected with `NOVA_DESKTOP` (default: `kde`). Use the matching wrapper in `build/editions/` or dispatch the GitHub Actions build workflow and choose an edition.

On Debian 13 Trixie, OpenRC manages services and runlevels while `sysvinit-core` provides PID 1; Trixie’s `openrc` package does not include the separate `openrc-init` package. GNOME is marked experimental because Debian documents known compatibility issues between GNOME and OpenRC. It should not be considered a supported release until it passes its own boot and session tests.

See TODO.md for build phases and milestones.
