#!/usr/bin/env bash
set -Eeuo pipefail

ISO="${1:-}"
if [[ -z "$ISO" || ! -s "$ISO" ]]; then
    echo "Usage: bash tests/smoke-boot.sh path/to/NOVA.iso" >&2
    exit 2
fi

QEMU="$(command -v qemu-system-x86_64 || true)"
if [[ -z "$QEMU" ]]; then
    echo "ERROR: qemu-system-x86_64 is required for the live-boot smoke test." >&2
    exit 1
fi

LOG="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/nova-live-boot-serial.log"
rm -f "$LOG"

echo "Starting NOVA ISO in QEMU (BIOS, serial console)..."
"$QEMU" \
    -machine accel=tcg \
    -m 3072 \
    -smp 2 \
    -cpu max \
    -cdrom "$ISO" \
    -boot order=d \
    -display none \
    -serial "file:$LOG" \
    -monitor none \
    -nic none \
    -no-reboot \
    -no-shutdown \
    >/dev/null 2>&1 &
QEMU_PID=$!

cleanup() {
    if kill -0 "$QEMU_PID" 2>/dev/null; then
        kill "$QEMU_PID" 2>/dev/null || true
        wait "$QEMU_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

for attempt in $(seq 1 120); do
    if grep -Fq "NOVA_BOOT_COMPLETED" "$LOG" 2>/dev/null; then
        echo "PASS: NOVA reached its OpenRC default runlevel."
        exit 0
    fi

    if grep -Eiq "Kernel panic|Attempted to kill init|No working init found|Unable to find a medium containing a live file system" "$LOG" 2>/dev/null; then
        echo "ERROR: The virtual machine reported a boot failure." >&2
        cat "$LOG" >&2 || true
        exit 1
    fi

    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        echo "ERROR: QEMU exited before NOVA completed boot." >&2
        cat "$LOG" >&2 || true
        exit 1
    fi

    sleep 1
done

echo "ERROR: NOVA did not reach the OpenRC default runlevel within 120 seconds." >&2
cat "$LOG" >&2 || true
exit 1
