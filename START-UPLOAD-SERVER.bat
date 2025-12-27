@echo off
title Starship Local Upload Server
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║          Starting Local Upload Server...                      ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo.
cd /d "%~dp0"
node scripts/local-upload-server.js
pause
