# Build and run NovaOS in QEMU.
#
# Usage (from PowerShell, in this folder):
#     .\run.ps1
#
# Press Ctrl+Alt+G to release the mouse/keyboard grab, or close the window.

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

& "$root\build.ps1"

$qemu = Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
if (-not $qemu) {
    $candidates = @(
        "C:\msys64\ucrt64\bin\qemu-system-x86_64.exe",
        "C:\msys64\mingw64\bin\qemu-system-x86_64.exe",
        "C:\Program Files\qemu\qemu-system-x86_64.exe",
        "C:\Program Files (x86)\qemu\qemu-system-x86_64.exe",
        "$env:USERPROFILE\qemu\qemu-system-x86_64.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $qemu = @{ Source = $c }; break }
    }
}
if (-not $qemu) {
    throw "QEMU not found. Install it with:  C:\msys64\usr\bin\bash -lc 'pacman -S --needed --noconfirm mingw-w64-x86_64-qemu'"
}

Write-Host "==> Starting QEMU..." -ForegroundColor Cyan
& $qemu.Source `
    -m 512M `
    -cdrom "$root\build\nova.iso" `
    -boot d `
    -vga std `
    -serial "file:$root\build\serial.log" `
    -no-reboot `
    -name "NovaOS"
