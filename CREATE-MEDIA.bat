@echo off
rem ---------------------------------------------------------------
rem  NovaOS Media Creation Tool.
rem
rem  Double-click this file. A Windows wizard opens that can make:
rem    - a bootable NovaOS .iso file, or
rem    - a bootable USB flash drive (removable FAT32 only).
rem
rem  You can pick a language, and choose to keep the files already on
rem  the USB drive. Nothing is installed and no Administrator rights
rem  are needed. Your Windows disks can never be selected.
rem ---------------------------------------------------------------
cd /d "%~dp0"
echo Building NovaOS and the media files...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
if errorlevel 1 goto fail
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build-media-tool.ps1"
if errorlevel 1 goto fail
echo Starting the Media Creation Tool...
powershell -NoProfile -Command "Start-Process '%~dp0NovaOS-MediaCreationTool.exe'"
exit /b 0
:fail
echo Build failed - see the errors above.
echo Press any key to close...
pause >nul
