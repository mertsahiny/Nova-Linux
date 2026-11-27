#!/usr/bin/env bash
set -Eeuo pipefail
export NOVA_INIT=openrc
for desktop in kde gnome xfce cinnamon lxqt lxde mate; do
  echo "===== Building OpenRC / $desktop ====="
  NOVA_DESKTOP="$desktop" bash build/build-one.sh
done
