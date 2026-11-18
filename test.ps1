# Headless boot test for NovaOS.
#
# Usage (from PowerShell, in this folder):
#     .\test.ps1              # build, boot with no window, check the log
#     .\test.ps1 -Seconds 40  # give the kernel more time to start
#
# QEMU runs with the display disabled, so nothing pops up. The kernel talks to
# the serial port instead, and this script reads build\serial.log afterwards.
#
# Exit code 0 = the kernel reached the graphical desktop.
# Exit code 1 = something went wrong (the log is printed to help you debug).

param(
    [int]$Seconds = 25
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# Build first (this also regenerates build\nova.iso).
& "$root\build.ps1"

function Find-Qemu {
    $cmd = Get-Command "qemu-system-x86_64.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "C:\msys64\ucrt64\bin\qemu-system-x86_64.exe",
        "C:\msys64\mingw64\bin\qemu-system-x86_64.exe",
        "C:\Program Files\qemu\qemu-system-x86_64.exe",
        "C:\Program Files (x86)\qemu\qemu-system-x86_64.exe",
        "$env:USERPROFILE\qemu\qemu-system-x86_64.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

$qemu = Find-Qemu
if (-not $qemu) {
    throw "QEMU not found. Install it with:  C:\msys64\usr\bin\bash -lc 'pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-qemu'"
}

$iso = Join-Path $root "build\nova.iso"
if (-not (Test-Path $iso)) { throw "build\nova.iso is missing - the build failed." }

$log = Join-Path $root "build\serial.log"
$errLog = Join-Path $root "build\qemu-stderr.log"
if (Test-Path $log) { Remove-Item -Force $log }
if (Test-Path $errLog) { Remove-Item -Force $errLog }

Write-Host "==> Booting ISO headless for $Seconds seconds..." -ForegroundColor Cyan

# We route the guest serial port to QEMU's own stdio and redirect that to a
# file. Unlike "-serial file:", stdio output is not buffered in 4 KiB blocks,
# so the log is complete even though we stop QEMU ourselves.
$argLine = @(
    "-m 512M",
    "-cdrom `"$iso`"",
    "-boot d",
    "-display none",
    "-serial stdio",
    "-no-reboot",
    "-name `"NovaOS test`""
) -join " "

$proc = Start-Process -FilePath $qemu -ArgumentList $argLine -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $log -RedirectStandardError $errLog
$finished = $proc.WaitForExit($Seconds * 1000)

if (-not $finished) {
    # Still running: that is the normal case for a kernel sitting at the shell.
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
} else {
    Write-Host "    QEMU exited early (code $($proc.ExitCode)) - the kernel probably crashed." -ForegroundColor Yellow
}

if (-not (Test-Path $log)) {
    Write-Host "FAIL: no serial log was produced." -ForegroundColor Red
    if (Test-Path $errLog) {
        Write-Host "QEMU said:" -ForegroundColor Yellow
        Get-Content $errLog | Write-Host
    }
    exit 1
}

$text = Get-Content -Raw $log

Write-Host ""
Write-Host "----- serial.log -----" -ForegroundColor DarkGray
Write-Host $text
Write-Host "----------------------" -ForegroundColor DarkGray
Write-Host ""

# What a healthy boot looks like.
$checks = @(
    @{ Name = "kernel started";     Pattern = "NovaOS" },
    @{ Name = "framebuffer ready";  Pattern = "console: framebuffer ready" },
    @{ Name = "system info printed";Pattern = "System information" },
    @{ Name = "graphics ready";     Pattern = "gfx: drawing surface ready" },
    @{ Name = "mouse ready";        Pattern = "mouse: PS/2 mouse ready" },
    @{ Name = "desktop ready";      Pattern = "gui: welcome ready" }
)

$failed = 0
foreach ($c in $checks) {
    if ($text -match [regex]::Escape($c.Pattern)) {
        Write-Host ("[ ok ] " + $c.Name) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] " + $c.Name + "  (expected: " + $c.Pattern + ")") -ForegroundColor Red
        $failed++
    }
}

# A panic or exception means the boot went wrong even if the banner appeared.
if ($text -match "KERNEL PANIC|CPU EXCEPTION") {
    Write-Host "[FAIL] a panic or CPU exception was logged" -ForegroundColor Red
    $failed++
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "PASS: NovaOS booted and reached the desktop." -ForegroundColor Green
    exit 0
}

Write-Host "FAIL: $failed check(s) did not pass." -ForegroundColor Red
exit 1
