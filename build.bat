@echo off
setlocal EnableExtensions EnableDelayedExpansion
title CashBook Permanent APK Builder

echo ============================================================
echo            CashBook - APK Builder
echo ============================================================
echo.

REM ============================================================
REM PERMANENT VERSION SYSTEM
REM ------------------------------------------------------------
REM - pubspec.yaml is NEVER modified
REM - no PowerShell
REM - no flutter clean
REM - no flutter analyze
REM - no flutter pub get
REM - no Dart/source changes
REM - version is stored in .cashbook_version
REM - Flutter gets version through:
REM     --build-name
REM     --build-number
REM ============================================================

if not exist "pubspec.yaml" (
    echo [ERROR] pubspec.yaml not found.
    echo Put this BAT file in the CashBook project root.
    echo.
    pause
    exit /b 1
)

where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Flutter was not found in PATH.
    echo Make sure flutter --version works.
    echo.
    pause
    exit /b 1
)

set "VERSION_FILE=.cashbook_version"
set "FULL_VERSION="

REM ------------------------------------------------------------
REM First run:
REM Read initial version from pubspec.yaml.
REM After that, .cashbook_version is the source of truth.
REM ------------------------------------------------------------
if exist "%VERSION_FILE%" (
    set /p FULL_VERSION=<"%VERSION_FILE%"
) else (
    for /f "tokens=1,* delims=:" %%A in ('findstr /B /C:"version:" "pubspec.yaml"') do (
        set "FULL_VERSION=%%B"
    )

    for /f "tokens=* delims= " %%A in ("!FULL_VERSION!") do (
        set "FULL_VERSION=%%A"
    )

    if not defined FULL_VERSION (
        echo [ERROR] Could not read initial version from pubspec.yaml.
        echo Expected example:
        echo version: 1.0.0+1
        echo.
        pause
        exit /b 1
    )

    >"%VERSION_FILE%" echo !FULL_VERSION!
)

REM ------------------------------------------------------------
REM Parse current version: 1.0.0+4
REM ------------------------------------------------------------
set "VERSION_NAME="
set "BUILD_NUMBER="

for /f "tokens=1,2 delims=+" %%A in ("!FULL_VERSION!") do (
    set "VERSION_NAME=%%A"
    set "BUILD_NUMBER=%%B"
)

if not defined VERSION_NAME goto :badversion
if not defined BUILD_NUMBER goto :badversion

set "MAJOR="
set "MINOR="
set "PATCH="

for /f "tokens=1,2,3 delims=." %%A in ("!VERSION_NAME!") do (
    set "MAJOR=%%A"
    set "MINOR=%%B"
    set "PATCH=%%C"
)

if not defined MAJOR goto :badversion
if not defined MINOR goto :badversion
if not defined PATCH goto :badversion

REM ------------------------------------------------------------
REM Version rules:
REM 1.0.0 -> 1.0.1
REM 1.0.9 -> 1.1.0
REM 1.9.9 -> 2.0.0
REM Build number always +1
REM ------------------------------------------------------------
set /a PATCH=PATCH+1

if !PATCH! GEQ 10 (
    set "PATCH=0"
    set /a MINOR=MINOR+1
)

if !MINOR! GEQ 10 (
    set "MINOR=0"
    set /a MAJOR=MAJOR+1
)

set /a NEW_BUILD_NUMBER=BUILD_NUMBER+1

set "NEW_VERSION_NAME=!MAJOR!.!MINOR!.!PATCH!"
set "NEW_FULL_VERSION=!NEW_VERSION_NAME!+!NEW_BUILD_NUMBER!"

echo Current version : !FULL_VERSION!
echo Next version    : !NEW_FULL_VERSION!
echo.

REM ------------------------------------------------------------
REM Build APK.
REM IMPORTANT:
REM --build-name and --build-number set the Android app version.
REM --no-pub prevents flutter pub get.
REM ------------------------------------------------------------
echo Building release APK...
echo.

call flutter build apk --release --no-pub --build-name=!NEW_VERSION_NAME! --build-number=!NEW_BUILD_NUMBER!

if errorlevel 1 (
    echo.
    echo ============================================================
    echo                       BUILD FAILED
    echo ============================================================
    echo Version was NOT advanced.
    echo Current saved version is still:
    echo !FULL_VERSION!
    echo.
    echo Fix the Flutter build error and run this BAT again.
    echo ============================================================
    echo.
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM Find Flutter APK
REM ------------------------------------------------------------
set "OUTPUT_DIR=build\app\outputs\flutter-apk"
set "SOURCE_APK=!OUTPUT_DIR!\app-release.apk"

if not exist "!SOURCE_APK!" (
    echo.
    echo [ERROR] Flutter reported success but app-release.apk was not found.
    echo Expected:
    echo !SOURCE_APK!
    echo.
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM Rename APK.
REM Example:
REM CashBook-v1.0.1-build5.apk
REM ------------------------------------------------------------
set "FINAL_NAME=CashBook-v!NEW_VERSION_NAME!-build!NEW_BUILD_NUMBER!.apk"
set "FINAL_APK=!OUTPUT_DIR!\!FINAL_NAME!"

if exist "!FINAL_APK!" (
    del /Q "!FINAL_APK!" >nul 2>nul
)

move /Y "!SOURCE_APK!" "!FINAL_APK!" >nul

if errorlevel 1 (
    echo.
    echo [ERROR] APK was built but rename failed.
    echo Version was NOT advanced.
    echo.
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM ONLY NOW save the new version.
REM Failed builds never consume a version.
REM ------------------------------------------------------------
>"%VERSION_FILE%" echo !NEW_FULL_VERSION!

echo.
echo ============================================================
echo                     BUILD COMPLETE
echo ============================================================
echo Version      : v!NEW_VERSION_NAME!
echo Build Number : !NEW_BUILD_NUMBER!
echo APK Name     : !FINAL_NAME!
echo Folder       : !OUTPUT_DIR!
echo.
echo Saved version file:
echo %VERSION_FILE% = !NEW_FULL_VERSION!
echo ============================================================
echo.

REM Open Explorer and select the final APK.
start "" explorer.exe /select,"!FINAL_APK!"

exit /b 0

:badversion
echo.
echo [ERROR] Invalid saved version.
echo Current value:
echo !FULL_VERSION!
echo.
echo Required format:
echo 1.0.0+1
echo.
echo To reset the builder, delete:
echo %VERSION_FILE%
echo Then run this BAT again.
echo.
pause
exit /b 1
