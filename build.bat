@echo off
rem =====================================================
rem  WinReminder Qt Quick build - everything stays here
rem =====================================================
setlocal
cd /d %~dp0

set "BUILD_DIR=%~dp0build-qt"
call "%~dp0scripts\load-qt-env.bat"
if errorlevel 1 exit /b 1

"%QT_ROOT%\bin\cmake.exe" ^
    -S "%~dp0." ^
    -B "%BUILD_DIR%" ^
    -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DBUILD_TESTING=ON ^
    -DCMAKE_PREFIX_PATH="%QT_ROOT%" ^
    -DCMAKE_MAKE_PROGRAM="%QT_ROOT%\ninja.exe" ^
    -DCMAKE_CXX_COMPILER="%MINGW_ROOT%\bin\g++.exe"
if errorlevel 1 (
    echo [ERROR] CMake configure failed
    exit /b 1
)

"%QT_ROOT%\bin\cmake.exe" --build "%BUILD_DIR%" --parallel
if errorlevel 1 (
    echo [ERROR] Build failed
    exit /b 1
)

echo.
echo Build OK: %BUILD_DIR%\WinReminder.exe
exit /b 0
