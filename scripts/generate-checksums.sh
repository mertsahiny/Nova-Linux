#!/bin/bash
set -euo pipefail

# Nova Linux Generate Checksums Script

echo "=== NOVA LINUX - CHECKSUM GENERATION PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <iso-file>"
    exit 1
fi

ISO_FILE="$1"
ISO_NAME=$(basename "$ISO_FILE")

if [ ! -f "$ISO_FILE" ]; then
    echo "ERROR: ISO file not found: $ISO_FILE"
    exit 1
fi

echo "[1/3] Generating SHA256 checksum..."
sha256sum "$ISO_FILE" | tee "${ISO_FILE}.sha256"

echo "[2/3] Verifying checksum..."
generated=$(sha256sum "$ISO_FILE" | awk '{print $1}')
stored=$(grep -o '^[a-f0-9]*' "${ISO_FILE}.sha256")

if [ "$generated" = "$stored" ]; then
    echo " [OK] SHA256 checksum verified: $generated"
else
    echo " [ERROR] SHA256 checksum mismatch!"
    echo "  Generated: $generated"
    echo "  Stored:    $stored"
    exit 1
fi

echo "[3/3] Generating MD5 checksum (for compatibility)..."
md5sum "$ISO_FILE" | tee "${ISO_FILE}.md5"

echo ""
echo "=== CHECKSUM GENERATION COMPLETE ==="
echo "Checksums generated for: $ISO_NAME"
echo "SHA256: $(sha256sum "$ISO_FILE" | awk '{print $1}')"
echo "MD5:    $(md5sum "$ISO_FILE" | awk '{print $1}')"
