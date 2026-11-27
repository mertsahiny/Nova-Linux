#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"
export NOVA_DESKTOP="xfce"

if [[ "$NOVA_DESKTOP" == "gnome" ]]; then
    echo "WARNING: GNOME on OpenRC is experimental. Test this edition separately before publishing it."
fi

exec bash "$REPO_ROOT/build/build-all.sh"
