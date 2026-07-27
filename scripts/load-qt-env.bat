@echo off
rem Load the Qt/MinGW environment without changing the global Windows PATH.
rem
rem Resolution order:
rem   1. Existing QT_ROOT and MINGW_ROOT environment variables
rem   2. A qt-env.bat specified by WINREMINDER_QT_ENV
rem   3. The shared toolchain used by this workspace

if defined QT_ROOT if defined MINGW_ROOT goto verify

if defined WINREMINDER_QT_ENV (
    if not exist "%WINREMINDER_QT_ENV%" (
        echo [ERROR] WINREMINDER_QT_ENV does not exist:
        echo         %WINREMINDER_QT_ENV%
        exit /b 1
    )
    call "%WINREMINDER_QT_ENV%"
    if errorlevel 1 exit /b 1
    goto verify
)

set "DEFAULT_QT_ENV=%~dp0..\..\_toolchains\Qt-6.11.1-MinGW13\qt-env.bat"
if exist "%DEFAULT_QT_ENV%" (
    call "%DEFAULT_QT_ENV%"
    if errorlevel 1 exit /b 1
    goto verify
)

echo [ERROR] A compatible Qt 6.11 and MinGW environment was not found.
echo.
echo Set QT_ROOT and MINGW_ROOT before running this script, or point
echo WINREMINDER_QT_ENV to a local qt-env.bat file. Example:
echo.
echo   set "WINREMINDER_QT_ENV=C:\QtToolchain\qt-env.bat"
echo   build.bat
exit /b 1

:verify
if not exist "%QT_ROOT%\bin\Qt6Core.dll" (
    echo [ERROR] QT_ROOT is not a compatible Qt installation:
    echo         %QT_ROOT%
    exit /b 1
)

if not exist "%MINGW_ROOT%\bin\g++.exe" (
    echo [ERROR] MINGW_ROOT is not a compatible MinGW installation:
    echo         %MINGW_ROOT%
    exit /b 1
)

exit /b 0
