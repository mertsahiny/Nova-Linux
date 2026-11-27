# NOVA Linux

Version 0.1.0 - Codename: Supernova

A Debian-derived Linux distribution built from Debian 13 Trixie.

## Desktop editions

- KDE Plasma 6
- GNOME (experimental on OpenRC until its boot and session tests pass)
- Xfce
- Cinnamon
- LXQt
- LXDE
- MATE

## Init systems

NOVA has two separately built init variants:

- **OpenRC:** OpenRC manages services and runlevels; Debian Trixie's `sysvinit-core` provides PID 1.
- **systemd:** systemd provides PID 1 and manages system services.

Each init variant has its own GitHub Actions workflow. Each workflow builds all seven desktop editions. ISO names use:

`NOVA-Linux-<version>-<init>-<desktop>-amd64.iso`

## Build locally

Build all OpenRC editions:

```bash
sudo bash build/build-openrc.sh
```

Build all systemd editions:

```bash
sudo bash build/build-systemd.sh
```

Build one edition:

```bash
sudo env NOVA_INIT=openrc NOVA_DESKTOP=kde bash build/build-one.sh
sudo env NOVA_INIT=systemd NOVA_DESKTOP=xfce bash build/build-one.sh
```

NOVA is assembled from upstream components using debootstrap, not modified ISOs.

See TODO.md for build phases and milestones.
