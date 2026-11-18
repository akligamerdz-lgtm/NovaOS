@echo off
rem ---------------------------------------------------------------
rem  NovaOS - safe headless test.
rem
rem  Double-click this file. It builds the ISO, boots it inside the
rem  QEMU emulator with the screen switched off, checks the kernel's
rem  serial log, and prints PASS or FAIL.
rem
rem  Nothing is installed and Windows is not touched: QEMU is just a
rem  normal program that pretends to be a PC. Your real PC keeps
rem  running the whole time.
rem ---------------------------------------------------------------
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test.ps1" %*
echo.
echo Press any key to close this window...
pause >nul
