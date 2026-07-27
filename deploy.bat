@echo off
rem =====================================================
rem  Build and create a self-contained dist directory
rem =====================================================
setlocal
cd /d %~dp0

call build.bat
if errorlevel 1 exit /b 1

set "BUILD_DIR=%~dp0build-qt"
set "DIST_DIR=%~dp0dist"
set "STAGE_DIR=%~dp0dist-staging"
call "%~dp0scripts\load-qt-env.bat"
if errorlevel 1 exit /b 1

"%QT_ROOT%\bin\ctest.exe" --test-dir "%BUILD_DIR%" --output-on-failure
if errorlevel 1 (
    echo [ERROR] Automated tests failed; dist was not updated.
    exit /b 1
)

if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
mkdir "%STAGE_DIR%"
if errorlevel 1 (
    echo [ERROR] Cannot create clean deployment staging directory.
    exit /b 1
)

copy /y "%BUILD_DIR%\WinReminder.exe" "%STAGE_DIR%\WinReminder.exe" >nul
if errorlevel 1 (
    echo [ERROR] Cannot stage WinReminder.exe.
    exit /b 1
)

"%QT_ROOT%\bin\windeployqt.exe" ^
    --release ^
    --qmldir "%~dp0qml" ^
    --no-translations ^
    --skip-plugin-types qmltooling,generic ^
    --no-system-d3d-compiler ^
    --no-system-dxc-compiler ^
    --compiler-runtime ^
    "%STAGE_DIR%\WinReminder.exe"
if errorlevel 1 (
    echo [ERROR] Qt deployment failed
    exit /b 1
)

if not exist "%STAGE_DIR%\licenses" mkdir "%STAGE_DIR%\licenses"
copy /y "%~dp0licenses\Qt-LGPLv3.txt" "%STAGE_DIR%\licenses\Qt-LGPLv3.txt" >nul
if errorlevel 1 (
    echo [ERROR] Cannot copy the Qt LGPLv3 license text from licenses\Qt-LGPLv3.txt.
    exit /b 1
)

copy /y "%~dp0LICENSE" "%STAGE_DIR%\LICENSE.txt" >nul
if errorlevel 1 (
    echo [ERROR] Cannot copy the WinReminder license.
    exit /b 1
)

copy /y "%~dp0THIRD_PARTY_NOTICES.md" "%STAGE_DIR%\THIRD_PARTY_NOTICES.md" >nul
if errorlevel 1 (
    echo [ERROR] Cannot copy third-party notices.
    exit /b 1
)

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
robocopy "%STAGE_DIR%" "%DIST_DIR%" /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP ^
    /XF reminders.json* reminders.dat
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
    echo [ERROR] Cannot update the dist directory.
    echo         Exit WinReminder from the system tray, then run deploy.bat again.
    exit /b 1
)

if exist "%~dp0reminders.dat" if not exist "%DIST_DIR%\reminders.dat" (
    copy /y "%~dp0reminders.dat" "%DIST_DIR%\reminders.dat" >nul
)

rmdir /s /q "%STAGE_DIR%"

echo.
echo Deploy OK: %DIST_DIR%\WinReminder.exe
exit /b 0
