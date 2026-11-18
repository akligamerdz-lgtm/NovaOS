@echo off
rem ---------------------------------------------------------------
rem  NovaOS - run it in a window.
rem
rem  Double-click this file. A QEMU window opens and boots NovaOS.
rem  Click inside it, then type "help" and press Enter.
rem
rem  Ctrl+Alt+G releases the keyboard/mouse grab.
rem  Close the window (or type "shutdown") when you are done.
rem  Windows itself is never affected.
rem ---------------------------------------------------------------
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
echo.
echo QEMU has closed. Nothing on your PC was changed.
echo Press any key to close this window...
pause >nul
