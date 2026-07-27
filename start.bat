@echo off
setlocal
cd /d %~dp0

if not exist "%~dp0dist\WinReminder.exe" (
    echo [ERROR] Published Qt application was not found.
    echo         Run deploy.bat first.
    pause
    exit /b 1
)

start "" "%~dp0dist\WinReminder.exe"
exit /b 0
