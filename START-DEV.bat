@echo off
title Starship Development Environment
color 0A
echo.
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║          STARSHIP DEVELOPMENT ENVIRONMENT                     ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo.
echo Starting servers...
echo.

cd /d "%~dp0"

:: Start Local Upload Server in new window
start "Starship Upload Server (4000)" cmd /k "node scripts/local-upload-server.js"

:: Give it a moment to start
timeout /t 2 /nobreak > nul

:: Start Vercel Dev in this window
echo ══════════════════════════════════════════════════════════════════
echo   Vercel Dev Server starting...
echo   Upload Server running in separate window (port 4000)
echo ══════════════════════════════════════════════════════════════════
echo.
vercel dev
