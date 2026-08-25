@echo off
cd /d "%~dp0"

title CashBook Backup To Archives

echo ==========================
echo CashBook Backup
echo ==========================
echo.

if not exist "pubspec.yaml" (
    echo ERROR: Run this BAT from CashBook project root.
    pause
    exit /b 1
)

if not exist "archives" (
    mkdir archives
)

for /f "tokens=1-4 delims=/ " %%a in ("%date%") do (
    set DATE=%%a-%%b-%%c
)

for /f "tokens=1-2 delims=: " %%a in ("%time%") do (
    set TIME=%%a-%%b
)

set BACKUP_NAME=archives\lib_backup_%DATE%_%TIME%_%RANDOM%.zip

echo Creating backup...
echo.

powershell -NoProfile -Command "Compress-Archive -Path '.\lib\*' -DestinationPath '%BACKUP_NAME%' -Force"

if exist "%BACKUP_NAME%" (
    echo.
    echo ==========================
    echo BACKUP COMPLETED
    echo ==========================
    echo Saved:
    echo %BACKUP_NAME%
) else (
    echo.
    echo BACKUP FAILED
)

pause