# NOVA Linux

**Sürüm:** 0.1.0 — **Kod adı:** Supernova

Debian 13 Trixie temel alınarak geliştirilen bir Linux dağıtımıdır.

## Masaüstü sürümleri

- KDE Plasma 6
- GNOME (OpenRC üzerinde açılış ve oturum testleri tamamlanana kadar deneysel)
- Xfce
- Cinnamon
- LXQt
- LXDE
- MATE

## Başlatma sistemleri (Init)

NOVA, birbirinden ayrı iki başlatma sistemi sürümüyle derlenir:

- **OpenRC:** Servisleri ve çalışma seviyelerini OpenRC yönetir. Debian Trixie'nin `sysvinit-core` paketi PID 1 görevini üstlenir.
- **systemd:** PID 1 görevini üstlenir ve sistem servislerini yönetir.

Her başlatma sistemi için ayrı bir GitHub Actions iş akışı bulunur. Her iş akışı yedi masaüstü sürümünün tamamını derler.

ISO dosyaları şu adlandırma biçimini kullanır:

`NOVA-Linux-<sürüm>-<init>-<masaüstü>-amd64.iso`

## Yerel derleme

Tüm OpenRC sürümlerini derlemek için:

```bash
sudo bash build/build-openrc.sh
```

Tüm systemd sürümlerini derlemek için:

```bash
sudo bash build/build-systemd.sh
```

Tek bir sürüm derlemek için:

```bash
sudo env NOVA_INIT=openrc NOVA_DESKTOP=kde bash build/build-one.sh
sudo env NOVA_INIT=systemd NOVA_DESKTOP=xfce bash build/build-one.sh
```

NOVA, değiştirilmiş hazır ISO dosyaları yerine debootstrap kullanılarak, ana dağıtımın bileşenlerinden oluşturulur.

Derleme aşamaları ve hedefler için `TODO.md` dosyasına göz atın.
