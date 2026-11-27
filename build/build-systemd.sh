#!/usr/bin/env bash
set -Eeuo pipefail
export NOVA_INIT=systemd
for desktop in kde gnome xfce cinnamon lxqt lxde mate; do
  echo "===== Building systemd / $desktop ====="
  NOVA_DESKTOP="$desktop" bash build/build-one.sh
done
