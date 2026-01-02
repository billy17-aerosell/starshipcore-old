@echo off
title Discord Presence - Auto Start Installer
color 0B

echo.
echo  ====================================================
echo         Discord Presence - Auto Start Installer
echo  ====================================================
echo.

:: Get the startup folder path
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SCRIPT_DIR=%~dp0"

:: Create shortcut to START-HIDDEN.vbs in Startup folder
echo Creating shortcut in Startup folder...

:: Use PowerShell to create shortcut
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%STARTUP%\DiscordPresence.lnk'); $s.TargetPath = '%SCRIPT_DIR%START-HIDDEN.vbs'; $s.WorkingDirectory = '%SCRIPT_DIR%'; $s.Description = 'Discord Rich Presence Auto Start'; $s.Save()"

if exist "%STARTUP%\DiscordPresence.lnk" (
    echo.
    echo  ====================================================
    echo   SUCCESS! Discord Presence akan auto-start saat
    echo   Windows boot.
    echo  ====================================================
    echo.
    echo   Shortcut created at:
    echo   %STARTUP%\DiscordPresence.lnk
    echo.
) else (
    echo.
    echo   ERROR: Gagal membuat shortcut!
    echo.
)

pause
