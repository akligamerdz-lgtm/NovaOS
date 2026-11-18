# Copy a freshly built NovaOS onto a FAT32 USB stick.
#
# Usage (from PowerShell, in this folder):
#     .\make-usb.ps1              # writes to E:
#     .\make-usb.ps1 -Drive F     # writes to F: instead
#
# This does NOT format the drive and does NOT touch any other disk. It only
# copies three files: the Limine UEFI bootloader, limine.conf and the kernel.
# Run .\build.ps1 first so build\iso_root is up to date.

param(
    [string]$Drive = "E"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$source = Join-Path $root "build\iso_root"

$letter = $Drive.TrimEnd(':').ToUpperInvariant()
if ($letter.Length -ne 1 -or $letter -notmatch '^[A-Z]$') {
    throw "Drive must be a single letter, for example E."
}

$volume = Get-Volume -DriveLetter $letter
if (-not $volume) { throw "Drive ${letter}: does not exist." }
if ($volume.FileSystem -ne "FAT32") {
    throw "Drive ${letter}: is $($volume.FileSystem); NovaOS needs FAT32."
}
if ($volume.DriveType -ne "Removable") {
    throw "Drive ${letter}: is not removable. Refusing to write to a fixed disk."
}

$partition = Get-Partition -DriveLetter $letter
$disk = Get-Disk -Number $partition.DiskNumber
Write-Host "Target: ${letter}: = $($disk.FriendlyName) (disk $($disk.Number), $($volume.FileSystem))"
Write-Host "Disk  : 0 and 1 (your Windows disks) will NOT be touched."

$bootloader = Join-Path $source "EFI\BOOT\BOOTX64.EFI"
$config     = Join-Path $source "limine.conf"
$kernel     = Join-Path $source "boot\kernel"

foreach ($f in @($bootloader, $config, $kernel)) {
    if (-not (Test-Path $f)) { throw "Missing $f - run .\build.ps1 first." }
}

$target = "${letter}:\"
New-Item -ItemType Directory -Force -Path (Join-Path $target "EFI\BOOT") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $target "boot") | Out-Null

Copy-Item $bootloader (Join-Path $target "EFI\BOOT\BOOTX64.EFI") -Force
Copy-Item $config     (Join-Path $target "limine.conf") -Force
Copy-Item $kernel     (Join-Path $target "boot\kernel") -Force

Write-Host ""
Write-Host "Done. To try it:"
Write-Host "  1. Reboot and open your firmware/boot menu (often F12, F11, F8 or Esc)."
Write-Host "  2. Choose the USB / 'UEFI: <USB name>' entry."
Write-Host "  3. Click 'Try it first' on the welcome screen."
Write-Host "Windows is unaffected - NovaOS has no disk driver and cannot write to any disk."
