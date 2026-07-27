@echo off
setlocal
cd /d %~dp0

call build.bat
if errorlevel 1 exit /b 1

call "%~dp0scripts\load-qt-env.bat"
if errorlevel 1 exit /b 1

start "" "%~dp0build-qt\WinReminder.exe"
exit /b 0
