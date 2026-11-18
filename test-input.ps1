# Drive the NovaOS shell with real (emulated) keystrokes, without a window.
#
# Usage:
#     .\test-input.ps1
#
# How it works: QEMU exposes its "human monitor" on a TCP port. The monitor
# has a "sendkey" command that injects PS/2 key events into the virtual
# machine - exactly what a physical keyboard does. So this exercises the real
# path: emulated keyboard -> IRQ1 -> keyboard.c ring buffer -> shell -> command.
#
# The guest's serial output goes to build\serial-kbd.log, which we print at the
# end so you can see the commands actually ran.

param(
    [int]$BootWaitSeconds = 40
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$iso  = Join-Path $root "build\nova.iso"
$log  = Join-Path $root "build\serial-kbd.log"

$qemuCandidates = @(
    "C:\msys64\ucrt64\bin\qemu-system-x86_64.exe",
    "C:\msys64\mingw64\bin\qemu-system-x86_64.exe",
    "C:\Program Files\qemu\qemu-system-x86_64.exe",
    "$env:USERPROFILE\qemu\qemu-system-x86_64.exe"
)
$qemu = $qemuCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $qemu) { throw "QEMU not found." }
if (-not (Test-Path $iso)) { throw "build\nova.iso is missing - run .\build.ps1 first." }

Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

function Start-Guest([int]$port, [string]$logPath) {
    $argLine = "-m 512M -cdrom `"$iso`" -boot d -display none " +
               "-serial `"file:$logPath`" -monitor tcp:127.0.0.1:$port,server,nowait -no-reboot"
    return Start-Process -FilePath $qemu -ArgumentList $argLine -PassThru -WindowStyle Hidden
}

function Connect-Monitor([int]$port, $proc, [int]$attempts = 60) {
    for ($i = 0; $i -lt $attempts; $i++) {
        if ($proc.HasExited) { return $null }   # QEMU died before we got in
        try {
            $c = New-Object System.Net.Sockets.TcpClient
            $c.Connect("127.0.0.1", $port)
            return $c
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    return $null
}

$client = $null
$proc = $null
for ($attempt = 1; $attempt -le 5 -and -not $client; $attempt++) {
    $port = 4500 + $attempt
    Remove-Item $log -Force -ErrorAction SilentlyContinue

    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Write-Host "==> Starting QEMU (attempt $attempt, monitor port $port)..." -ForegroundColor Cyan
    $proc = Start-Guest -port $port -logPath $log

    $client = Connect-Monitor -port $port -proc $proc
    if (-not $client) {
        Write-Host "    QEMU exited before the monitor was ready; retrying." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 700
    }
}

if (-not $client) {
    Write-Host "FAIL: could not attach to the QEMU monitor." -ForegroundColor Red
    exit 1
}

$stream = $client.GetStream()
$stream.ReadTimeout = 800

function Pump-Monitor {
    # Read and discard whatever the monitor has to say, so its output buffer
    # never fills up and blocks QEMU.
    $buf = New-Object byte[] 8192
    try { while ($stream.DataAvailable) { [void]$stream.Read($buf, 0, $buf.Length) } } catch { }
}

function Send-Monitor([string]$line) {
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($line + "`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
}

function Send-Text([string]$text) {
    # sendkey takes key names: letters are themselves, space is "spc".
    foreach ($ch in $text.ToCharArray()) {
        $key = switch ($ch) {
            ' '  { 'spc' }
            '-'  { 'minus' }
            '.'  { 'dot' }
            '/'  { 'slash' }
            default { [string]$ch }
        }
        Send-Monitor "sendkey $key"
        Start-Sleep -Milliseconds 120
        Pump-Monitor
    }
    Send-Monitor "sendkey ret"
    Start-Sleep -Milliseconds 400
    Pump-Monitor
}

# NovaOS now starts in its graphical desktop. Wait for that, then press Esc
# to switch to the text console before testing the keyboard and shell.
Write-Host "==> Waiting for the desktop..." -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds($BootWaitSeconds)
$ready = $false
while ((Get-Date) -lt $deadline -and -not $ready) {
    if ($proc.HasExited) { break }
    if (Test-Path $log) {
        $t = Get-Content $log -Raw -ErrorAction SilentlyContinue
        if ($t -match 'gui: welcome ready') { $ready = $true }
    }
    if (-not $ready) { Start-Sleep -Milliseconds 500 }
}

if (-not $ready) {
    Write-Host "FAIL: the kernel never reached the desktop." -ForegroundColor Red
    if (Test-Path $log) { Get-Content $log }
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "    desktop is ready; pressing Esc for the text console." -ForegroundColor DarkGray

Send-Monitor "sendkey esc"
Start-Sleep -Milliseconds 500
Pump-Monitor

Write-Host "==> Waiting for the text shell prompt..." -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds($BootWaitSeconds)
$ready = $false
while ((Get-Date) -lt $deadline -and -not $ready) {
    if ($proc.HasExited) { break }
    if (Test-Path $log) {
        $t = Get-Content $log -Raw -ErrorAction SilentlyContinue
        if ($t -match 'nova> ') { $ready = $true }
    }
    if (-not $ready) { Start-Sleep -Milliseconds 500 }
}

if (-not $ready) {
    Write-Host "FAIL: the shell prompt never appeared after Esc." -ForegroundColor Red
    if (Test-Path $log) { Get-Content $log }
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "    shell is ready." -ForegroundColor DarkGray

Write-Host "==> Typing commands..." -ForegroundColor Cyan
Send-Text "help"
Send-Text "uptime"
Send-Text "cpu"
Send-Text "mem"
Send-Text "echo hello from a real keyboard"

Start-Sleep -Seconds 1
Pump-Monitor
$client.Close()
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 600

$text = Get-Content $log -Raw -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "----- serial-kbd.log -----" -ForegroundColor DarkGray
Write-Host $text
Write-Host "---------------------------" -ForegroundColor DarkGray

$expected = @(
    @{ Name = "help listed commands";     Pattern = "show this list" },
    @{ Name = "uptime ran";               Pattern = "Uptime:" },
    @{ Name = "cpu info ran";             Pattern = "CPU vendor" },
    @{ Name = "mem stats ran";            Pattern = "Physical memory" },
    @{ Name = "echo echoed the text";     Pattern = "hello from a real keyboard" }
)

$failed = 0
foreach ($e in $expected) {
    if ($text -match [regex]::Escape($e.Pattern)) {
        Write-Host ("[ ok ] " + $e.Name) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] " + $e.Name) -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "PASS: keyboard IRQ + shell commands work." -ForegroundColor Green
    exit 0
}
Write-Host "FAIL: $failed check(s) failed." -ForegroundColor Red
exit 1
