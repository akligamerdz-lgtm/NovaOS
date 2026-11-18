# Build NovaOS (native Windows toolchain: LLVM/clang + xorriso + limine).
#
# Usage (from PowerShell, in this folder):
#     .\build.ps1
#
# One-time requirements:
#   winget install LLVM.LLVM
#   winget install MSYS2.MSYS2     (for xorriso)
#   winget install SoftwareFreedomConservancy.QEMU   (only needed to run)
#
# See README.md for details.

$ErrorActionPreference = "Stop"
$root      = $PSScriptRoot
$kernelDir = Join-Path $root "kernel"
$buildDir  = Join-Path $root "build"
$objDir    = Join-Path $buildDir "obj"

function Find-Tool {
    param([string]$Name, [string[]]$Candidates)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($c in $Candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

# xorriso is an MSYS program and expects Unix-style paths (/d/...).
function To-MsysPath {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    $drive = $full.Substring(0, 1).ToLower()
    return "/$drive" + ($full.Substring(2) -replace '\\', '/')
}

$clang = Find-Tool "clang.exe"     @("C:\Program Files\LLVM\bin\clang.exe")
$lld   = Find-Tool "ld.lld.exe"    @("C:\Program Files\LLVM\bin\ld.lld.exe")
$xorr  = Find-Tool "xorriso.exe"   @("C:\msys64\usr\bin\xorriso.exe")
$limine = Join-Path $root "tools\limine.exe"

# If clang came from PATH, ld.lld is usually right next to it.
if ($clang -and -not $lld) {
    $candidate = Join-Path (Split-Path $clang) "ld.lld.exe"
    if (Test-Path $candidate) { $lld = $candidate }
}

if (-not $clang -or -not $lld) {
    throw "LLVM not found. Install it with:  winget install LLVM.LLVM"
}
if (-not $xorr -or -not (Test-Path $xorr)) {
    throw "xorriso not found. Install MSYS2, then run:  C:\msys64\usr\bin\bash -lc 'pacman -S --noconfirm xorriso'"
}

New-Item -ItemType Directory -Force -Path $buildDir, $objDir | Out-Null

$target   = @("--target=x86_64-none-elf")
$freestnd = $target + @(
    "-ffreestanding", "-fno-builtin", "-fno-stack-protector",
    "-fno-pic", "-fno-pie", "-fno-asynchronous-unwind-tables",
    "-fno-unwind-tables", "-mno-red-zone", "-mcmodel=kernel",
    "-mno-sse", "-mno-sse2", "-mno-mmx", "-mno-80387",
    "-I$kernelDir\include"
)
$cflags = @("-std=gnu11", "-O2", "-g", "-Wall", "-Wextra") + $freestnd

Write-Host "==> Compiling kernel..." -ForegroundColor Cyan
$objects = @()

Get-ChildItem (Join-Path $kernelDir "src\*.c") | ForEach-Object {
    $obj = Join-Path $objDir ($_.BaseName + ".o")
    & $clang @cflags -c $_.FullName -o $obj
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($_.Name)" }
    $objects += $obj
}

Get-ChildItem (Join-Path $kernelDir "arch\*.S") | ForEach-Object {
    $obj = Join-Path $objDir ($_.BaseName + ".o")
    & $clang @freestnd -c $_.FullName -o $obj
    if ($LASTEXITCODE -ne 0) { throw "Assemble failed: $($_.Name)" }
    $objects += $obj
}

$kernelElf = Join-Path $buildDir "kernel.elf"
& $lld -nostdlib -static -z max-page-size=0x1000 `
    -T (Join-Path $kernelDir "linker.ld") `
    -o $kernelElf @objects
if ($LASTEXITCODE -ne 0) { throw "Link failed." }
Write-Host ("    kernel.elf  {0:N0} bytes" -f (Get-Item $kernelElf).Length) -ForegroundColor DarkGray

Write-Host "==> Creating bootable ISO..." -ForegroundColor Cyan
$isoRoot = Join-Path $buildDir "iso_root"
if (Test-Path $isoRoot) { Remove-Item -Recurse -Force $isoRoot }
New-Item -ItemType Directory -Force -Path (Join-Path $isoRoot "boot"), (Join-Path $isoRoot "EFI\BOOT") | Out-Null

Copy-Item $kernelElf                          (Join-Path $isoRoot "boot\kernel")
Copy-Item (Join-Path $root "limine.conf")     (Join-Path $isoRoot "limine.conf")
Copy-Item (Join-Path $root "boot\limine-bios.sys")    (Join-Path $isoRoot "boot\")
Copy-Item (Join-Path $root "boot\limine-bios-cd.bin") (Join-Path $isoRoot "boot\")
Copy-Item (Join-Path $root "boot\limine-uefi-cd.bin") (Join-Path $isoRoot "boot\")
Copy-Item (Join-Path $root "boot\EFI\BOOT\BOOTX64.EFI") (Join-Path $isoRoot "EFI\BOOT\")

$iso = Join-Path $buildDir "nova.iso"
if (Test-Path $iso) { Remove-Item -Force $iso }

& $xorr -as mkisofs -R -r -J `
    -b boot/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table `
    --efi-boot boot/limine-uefi-cd.bin -efi-boot-part --efi-boot-image `
    --protective-msdos-label `
    (To-MsysPath $isoRoot) -o (To-MsysPath $iso) | Out-Null
if ($LASTEXITCODE -ne 0) { throw "xorriso failed." }

Write-Host "==> Installing Limine BIOS boot code..." -ForegroundColor Cyan
& $limine bios-install $iso | Out-Null
if ($LASTEXITCODE -ne 0) { throw "limine bios-install failed." }

Write-Host ""
Write-Host ("Done: {0:N0} byte ISO at build\nova.iso" -f (Get-Item $iso).Length) -ForegroundColor Green
Write-Host "Run it with:  .\run.ps1" -ForegroundColor Green
