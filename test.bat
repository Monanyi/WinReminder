@echo off
rem =====================================================
rem  Build and run the automated Qt/CTest test suite
rem =====================================================
setlocal
cd /d %~dp0

call build.bat
if errorlevel 1 exit /b 1

call "%~dp0scripts\load-qt-env.bat"
if errorlevel 1 exit /b 1

"%QT_ROOT%\bin\ctest.exe" --test-dir "%~dp0build-qt" --output-on-failure
if errorlevel 1 (
    echo [ERROR] Automated tests failed
    exit /b 1
)

echo.
echo Tests OK
exit /b 0
