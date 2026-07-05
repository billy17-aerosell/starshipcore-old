@echo off
chcp 65001 >nul
title Starship Core Manager
color 0B

REM ═══════════════════════════════════════════════════════════
REM CONFIG LOADER
REM - If you run this file directly, ADMIN_SECRET is loaded from .env.
REM - run-manager.bat can still override/provide ADMIN_SECRET before calling this.
REM ═══════════════════════════════════════════════════════════
pushd "%~dp0" >nul
if not defined ADMIN_SECRET (
    if exist ".env" (
        for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
            if /i "%%A"=="ADMIN_SECRET" set "ADMIN_SECRET=%%B"
        )
    )
)

if not defined ADMIN_SECRET (
    cls
    echo.
    echo  ❌ ADMIN_SECRET belum diset.
    echo.
    echo  Penyebab: endpoint admin menolak request tanpa header x-admin-secret yang benar.
    echo  Solusi: isi ADMIN_SECRET di file .env atau jalankan run-manager.bat.
    echo.
    pause
    goto EXIT
)
:MENU
cls
echo.
echo  ╔═══════════════════════════════════════════════════════════╗
echo  ║           🚀 STARSHIP CORE MANAGER 🚀                     ║
echo  ╠═══════════════════════════════════════════════════════════╣
echo  ║                 STATUS - BOTH (PC ^& Mobile)              ║
echo  ║  [1] 🟢 Set ALL: ONLINE                                   ║
echo  ║  [2] 🟡 Set ALL: MAINTENANCE                              ║
echo  ║  [3] 🔴 Set ALL: OFFLINE                                  ║
echo  ╠═══════════════════════════════════════════════════════════╣
echo  ║                 STATUS - PC ONLY                          ║
echo  ║  [4] � Set PC: ONLINE                                    ║
echo  ║  [5] 🟡 Set PC: MAINTENANCE                               ║
echo  ║  [6] 🔴 Set PC: OFFLINE                                   ║
echo  ╠═══════════════════════════════════════════════════════════╣
echo  ║                 STATUS - MOBILE ONLY                      ║
echo  ║  [7] � Set Mobile: ONLINE                                ║
echo  ║  [8] � Set Mobile: MAINTENANCE                           ║
echo  ║  [9] � Set Mobile: OFFLINE                               ║
echo  ╠═══════════════════════════════════════════════════════════╣
echo  ║                 OTHER OPTIONS                             ║
echo  ║  [S] � Check Current Status                              ║
echo  ║  [C] 📝 Update Changelog                                  ║
echo  ║  [G] 📦 Git: Add + Commit + Push                          ║
echo  ║  [P] 📤 Git: Push Only                                    ║
echo  ║  [L] 📥 Git: Pull                                         ║
echo  ║  [T] 📋 Git: Status                                       ║
echo  ║  [0] ❌ Exit                                              ║
echo  ╚═══════════════════════════════════════════════════════════╝
echo.
set /p choice="  Select option: "

if /i "%choice%"=="1" goto SET_ALL_ONLINE
if /i "%choice%"=="2" goto SET_ALL_MAINTENANCE
if /i "%choice%"=="3" goto SET_ALL_OFFLINE
if /i "%choice%"=="4" goto SET_PC_ONLINE
if /i "%choice%"=="5" goto SET_PC_MAINTENANCE
if /i "%choice%"=="6" goto SET_PC_OFFLINE
if /i "%choice%"=="7" goto SET_MOBILE_ONLINE
if /i "%choice%"=="8" goto SET_MOBILE_MAINTENANCE
if /i "%choice%"=="9" goto SET_MOBILE_OFFLINE
if /i "%choice%"=="S" goto CHECK_STATUS
if /i "%choice%"=="C" goto UPDATE_CHANGELOG
if /i "%choice%"=="G" goto GIT_FULL
if /i "%choice%"=="P" goto GIT_PUSH
if /i "%choice%"=="L" goto GIT_PULL
if /i "%choice%"=="T" goto GIT_STATUS
if /i "%choice%"=="0" goto EXIT

echo  Invalid option!
timeout /t 2 >nul
goto MENU

REM ═══════════════════════════════════════════════════════════
REM STATUS - ALL PLATFORMS
REM ═══════════════════════════════════════════════════════════

:SET_ALL_ONLINE
cls
echo.
echo  🟢 Setting ALL platforms to ONLINE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"online\",\"platform\":\"all\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU
:SET_ALL_MAINTENANCE
cls
echo.
echo  🟡 Setting ALL platforms to MAINTENANCE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"maintenance\",\"platform\":\"all\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

:SET_ALL_OFFLINE
cls
echo.
echo  🔴 Setting ALL platforms to OFFLINE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"offline\",\"platform\":\"all\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

REM ═══════════════════════════════════════════════════════════
REM STATUS - PC ONLY
REM ═══════════════════════════════════════════════════════════

:SET_PC_ONLINE
cls
echo.
echo  🟢 Setting PC to ONLINE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"online\",\"platform\":\"pc\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

:SET_PC_MAINTENANCE
cls
echo.
echo  🟡 Setting PC to MAINTENANCE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"maintenance\",\"platform\":\"pc\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

:SET_PC_OFFLINE
cls
echo.
echo  🔴 Setting PC to OFFLINE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"offline\",\"platform\":\"pc\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

REM ═══════════════════════════════════════════════════════════
REM STATUS - MOBILE ONLY
REM ═══════════════════════════════════════════════════════════

:SET_MOBILE_ONLINE
cls
echo.
echo  🟢 Setting Mobile to ONLINE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"online\",\"platform\":\"mobile\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

:SET_MOBILE_MAINTENANCE
cls
echo.
echo  🟡 Setting Mobile to MAINTENANCE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"maintenance\",\"platform\":\"mobile\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

:SET_MOBILE_OFFLINE
cls
echo.
echo  🔴 Setting Mobile to OFFLINE...
echo.
curl -X POST "https://starship-core.my.id/api/tags?action=set_status" -H "Content-Type: application/json" -H "x-admin-secret: %ADMIN_SECRET%" -d "{\"status\":\"offline\",\"platform\":\"mobile\"}"
echo.
echo.
echo  ✅ Done!
pause
goto MENU

REM ═══════════════════════════════════════════════════════════
REM OTHER OPTIONS
REM ═══════════════════════════════════════════════════════════

:CHECK_STATUS
cls
echo.
echo  📊 Checking current status...
echo.
echo  --- ALL ---
curl -s "https://starship-core.my.id/api/tags?action=get_status"
echo.
echo.
echo  --- PC ---
curl -s "https://starship-core.my.id/api/tags?action=get_status&platform=pc"
echo.
echo.
echo  --- MOBILE ---
curl -s "https://starship-core.my.id/api/tags?action=get_status&platform=mobile"
echo.
echo.
pause
goto MENU

:UPDATE_CHANGELOG
cls
echo.
echo  📝 Opening changelog.json in VS Code...
echo.
code "public\changelog.json"
echo.
echo  Edit the file, save, then use Git options to commit and push.
echo.
pause
goto MENU

:GIT_FULL
cls
echo.
echo  📦 Git: Add All + Commit + Push
echo.
set /p commitmsg="  Enter commit message: "
echo.
echo  Adding all changes...
git add .
echo.
echo  Committing...
git commit -m "%commitmsg%"
echo.
echo  Pushing...
git push
echo.
echo  ✅ Done!
pause
goto MENU

:GIT_PUSH
cls
echo.
echo  📤 Pushing to remote...
echo.
git push
echo.
echo  ✅ Done!
pause
goto MENU

:GIT_PULL
cls
echo.
echo  📥 Pulling from remote...
echo.
git pull
echo.
echo  ✅ Done!
pause
goto MENU

:GIT_STATUS
cls
echo.
echo  📋 Git Status:
echo.
git status
echo.
pause
goto MENU

:EXIT
popd >nul 2>nul
cls
echo.
echo  👋 Goodbye!
echo.
timeout /t 2 >nul
exit
