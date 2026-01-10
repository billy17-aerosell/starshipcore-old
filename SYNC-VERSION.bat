@echo off
title Starship Version Sync
echo ==========================================
echo      STARSHIP VERSION SYNCHRONIZER
echo ==========================================
echo.
echo Reading changelogs and updating scripts...
echo.

node sync-version.js

echo.
echo ==========================================
echo               DONE!
echo ==========================================
pause
