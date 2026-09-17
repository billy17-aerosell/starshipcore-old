@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Starship Development Environment
color 0A
echo.
echo ========================================================
echo          STARSHIP DEVELOPMENT ENVIRONMENT
echo ========================================================
echo.
echo Starting servers...
echo.

:: Navigate to script directory (handles special chars like ^& in path)
pushd "%~dp0"
if !ERRORLEVEL! neq 0 (
    color 0C
    echo [ERROR] Failed to navigate to script directory!
    pause
    exit /b 1
)

echo [OK] Working directory set successfully.
echo.

:: Check if node is installed
where node >nul 2>&1
if !ERRORLEVEL! neq 0 (
    color 0C
    echo [ERROR] Node.js is not installed or not in PATH!
    echo Please install Node.js from https://nodejs.org/
    echo.
    pause
    exit /b 1
)

:: Check if node_modules exists
if not exist "node_modules" (
    color 0E
    echo [WARNING] node_modules not found. Running npm install...
    echo.
    call npm install
    if !ERRORLEVEL! neq 0 (
        color 0C
        echo [ERROR] npm install failed!
        pause
        exit /b 1
    )
    echo.
)

:: Check if vercel is available (try global, then fallback to npx)
where vercel >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo [INFO] Vercel CLI not found globally. Will use npx vercel...
    set "VERCEL_CMD=npx -y vercel"
) else (
    set "VERCEL_CMD=vercel"
)

:: Check if Vercel project is linked (v54+ uses repo.json, older uses project.json)
if not exist ".vercel\project.json" if not exist ".vercel\repo.json" (
    color 0E
    echo [SETUP] Vercel project is not linked yet.
    echo Please follow the prompts to link your project:
    echo.
    !VERCEL_CMD! link
    :: Check if link actually created the config file
    if not exist ".vercel\project.json" if not exist ".vercel\repo.json" (
        color 0C
        echo [ERROR] Vercel link failed! No project config was created.
        echo Please try running "npx vercel link" manually.
        pause
        exit /b 1
    )
    echo.
    color 0A
    echo [OK] Vercel project linked successfully!
    echo.
)

:: Start Local Upload Server in a persistent new window.
:: The health endpoint below is the source of truth; START can preserve an older ERRORLEVEL.
echo [1/2] Checking Upload Server on port 4000...
powershell -NoProfile -Command "try { $r = Invoke-RestMethod -Uri 'http://127.0.0.1:4000/' -TimeoutSec 2; if ($r.status -eq 'ok') { exit 0 } } catch {}; exit 1" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo [OK] Upload Server is already running on port 4000.
) else (
    if not exist "scripts\local-upload-server.js" (
        color 0C
        echo [ERROR] scripts\local-upload-server.js was not found!
        popd
        pause
        exit /b 1
    )

    echo [INFO] Opening Upload Server in a separate window...
    start "Starship Upload Server (4000)" /D "%~dp0" "%ComSpec%" /d /k call "START-UPLOAD-SERVER.bat"

    :: Wait up to five seconds for Node to bind and answer the health endpoint.
    powershell -NoProfile -Command "for ($i = 0; $i -lt 10; $i++) { try { $r = Invoke-RestMethod -Uri 'http://127.0.0.1:4000/' -TimeoutSec 1; if ($r.status -eq 'ok') { exit 0 } } catch {}; Start-Sleep -Milliseconds 500 }; exit 1" >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        color 0E
        echo [WARNING] Upload Server did not respond on port 4000.
        echo           Check the separate Upload Server window for the error.
    ) else (
        color 0A
        echo [OK] Upload Server is ready on http://localhost:4000
    )
)

:: Start Vercel Dev in this window
echo.
echo ========================================================
echo   [2/2] Vercel Dev Server starting on port 3000...
echo   Upload Server running in separate window (port 4000)
echo ========================================================
echo.
!VERCEL_CMD! dev --listen 0.0.0.0:3000

:: If vercel dev exits, keep window open
echo.
echo ========================================================
echo   Server stopped. Press any key to close.
echo ========================================================
popd
pause
