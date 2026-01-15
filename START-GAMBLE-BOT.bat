@echo off
cd DiscordGambleBot
if not exist .env (
    echo File .env tidak ditemukan!
    echo Silahkan copy .env.example menjadi .env dan isi tokennya.
    echo.
    pause
    exit
)
echo Starting Gamble Bot...
npm start
pause
