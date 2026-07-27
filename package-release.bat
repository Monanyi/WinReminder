@echo off
rem Build a clean GitHub Release ZIP without personal reminder data.
setlocal
cd /d %~dp0

set "VERSION=2.0.0"
set "RELEASE_DIR=%~dp0release"
set "PACKAGE_NAME=WinReminder-%VERSION%-windows-x64"
set "PACKAGE_DIR=%RELEASE_DIR%\%PACKAGE_NAME%"
set "ZIP_PATH=%RELEASE_DIR%\%PACKAGE_NAME%.zip"

call deploy.bat
if errorlevel 1 exit /b 1

if exist "%PACKAGE_DIR%" rmdir /s /q "%PACKAGE_DIR%"
mkdir "%PACKAGE_DIR%"
if errorlevel 1 (
    echo [ERROR] Cannot create the release staging directory.
    exit /b 1
)

robocopy "%~dp0dist" "%PACKAGE_DIR%" /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP ^
    /XF reminders.json* reminders.dat
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
    echo [ERROR] Cannot prepare the clean release package.
    exit /b 1
)

where tar.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Windows tar.exe was not found.
    exit /b 1
)

if exist "%ZIP_PATH%" del /q "%ZIP_PATH%"
tar.exe -a -c -f "%ZIP_PATH%" -C "%RELEASE_DIR%" "%PACKAGE_NAME%"
if errorlevel 1 (
    echo [ERROR] Cannot create the release ZIP.
    exit /b 1
)

rmdir /s /q "%PACKAGE_DIR%"

echo.
echo Release package OK: %ZIP_PATH%
exit /b 0
