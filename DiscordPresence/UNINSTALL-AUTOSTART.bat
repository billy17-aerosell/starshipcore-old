@echo off
title Discord Presence - Remove Auto Start
color 0C

echo.
echo  ====================================================
echo       Discord Presence - Remove Auto Start
echo  ====================================================
echo.

set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

if exist "%STARTUP%\DiscordPresence.lnk" (
    del "%STARTUP%\DiscordPresence.lnk"
    echo   Auto-start removed successfully!
) else (
    echo   Auto-start shortcut not found.
)

echo.
pause
