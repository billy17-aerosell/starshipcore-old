@echo off
setlocal
chcp 65001 >nul 2>&1
title Starship Local Upload Server
color 0A

pushd "%~dp0"
if errorlevel 1 (
    color 0C
    echo [ERROR] Failed to open the project directory.
    pause
    exit /b 1
)

echo +---------------------------------------------------------------+
echo ^|          Starting Local Upload Server                        ^|
echo +---------------------------------------------------------------+
echo.

where node >nul 2>&1
if errorlevel 1 (
    color 0C
    echo [ERROR] Node.js is not installed or is not available in PATH.
    goto :finish_error
)

if not exist "scripts\local-upload-server.js" (
    color 0C
    echo [ERROR] scripts\local-upload-server.js was not found.
    goto :finish_error
)

echo [INFO] Starting Node upload service at http://localhost:4000 ...
node scripts\local-upload-server.js
set "SERVER_EXIT=%ERRORLEVEL%"

if not "%SERVER_EXIT%"=="0" (
    color 0C
    echo.
    echo [ERROR] Upload Server stopped with exit code %SERVER_EXIT%.
) else (
    color 0E
    echo.
    echo [INFO] Upload Server stopped.
)

echo.
pause
popd
exit /b %SERVER_EXIT%

:finish_error
echo.
pause
popd
exit /b 1
