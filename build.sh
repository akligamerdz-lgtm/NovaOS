#!/usr/bin/env bash
# NovaOS build script -- run this inside WSL/Ubuntu.
#
#   ./build.sh
#
# Produces build/nova.iso, a bootable CD image.
# The Windows wrapper build.ps1 also patches it with the Limine BIOS
# bootloader (that step needs tools/limine.exe).

set -euo pipefail
cd "$(dirname "$0")"

jobs="$(nproc 2>/dev/null || echo 4)"
make -C kernel -j"$jobs"

ROOT=build/iso_root
rm -rf "$ROOT"
mkdir -p "$ROOT/boot" "$ROOT/EFI/BOOT"

cp kernel/build/kernel "$ROOT/boot/kernel"
cp limine.conf          "$ROOT/limine.conf"
cp boot/limine-bios.sys "$ROOT/boot/"
cp boot/limine-bios-cd.bin "$ROOT/boot/"
cp boot/limine-uefi-cd.bin "$ROOT/boot/"
cp boot/EFI/BOOT/BOOTX64.EFI "$ROOT/EFI/BOOT/"

if ! command -v xorriso >/dev/null 2>&1; then
    echo
    echo "ERROR: xorriso is not installed."
    echo "Install it with:  sudo apt install -y xorriso"
    exit 1
fi

xorriso -as mkisofs -R -r -J \
    -b boot/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
    --efi-boot boot/limine-uefi-cd.bin -efi-boot-part --efi-boot-image \
    --protective-msdos-label \
    "$ROOT" -o build/nova.iso

echo
echo "Built build/nova.iso"
