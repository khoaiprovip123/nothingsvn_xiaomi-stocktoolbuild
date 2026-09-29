@echo off
setlocal enabledelayedexpansion
chcp 437 >nul
title KTOS ROM Flasher - FULL (all partitions)

:: ============================================================
::  flash_fastboot.bat - Flash FULL ROM (ALL partitions)
::  Includes firmware (modem, bluetooth, dsp, tz...) so SIM/WiFi/BT work.
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "IMG_DIR=%SCRIPT_DIR%images"
set "SUPER_DIR=%SCRIPT_DIR%super"
set "FB=%SCRIPT_DIR%fastboot.exe"
if not exist "%FB%" set "FB=fastboot"

echo.
echo ============================================================
echo   KTOS ROM Flasher - FULL (firmware + system)
echo ============================================================
echo.

:: --- 1. Check fastboot ---
where %FB% >nul 2>&1
if errorlevel 1 if "%FB%"=="fastboot" (
    echo [ERROR] fastboot not found.
    pause
    exit /b 1
)
echo       Using: %FB%

:: --- 2. Check device ---
echo [1/4] Checking fastboot connection...
"%FB%" devices | findstr /r /c:"fastboot" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No fastboot device. Boot into FASTBOOT + connect USB.
    pause
    exit /b 1
)
for /f "tokens=1" %%d in ('"%FB%" devices') do set "SERIAL=%%d"
echo       Device: %SERIAL%

:: --- 3. Check ROM ---
echo [2/4] Checking ROM files...
set "MISSING=0"
if exist "%SUPER_DIR%\super.img" (echo       [OK] super\super.img) else (echo       [MISSING] super.img & set "MISSING=1")
if exist "%IMG_DIR%\boot.img" (echo       [OK] boot.img) else (echo       [MISSING] boot.img & set "MISSING=1")
if exist "%IMG_DIR%\vbmeta.img" (echo       [OK] vbmeta.img) else (echo       [MISSING] vbmeta.img & set "MISSING=1")
if exist "%IMG_DIR%\modem.img" (echo       [OK] modem.img) else (echo       [!!] modem.img - SIM se khong hoat dong)
if "!MISSING!"=="1" (echo [ERROR] Missing critical files. & pause & exit /b 1)

echo.
echo  WARNING: Flash ALL partitions (firmware + system).
echo  Device MUST have unlocked bootloader.
echo.
set /p "CONFIRM=Flash full ROM? (y/N): "
if /i not "!CONFIRM!"=="y" (echo Cancelled. & pause & exit /b 0)

:: --- 4. FLASH EVERYTHING ---
echo.
echo [3/4] Flashing FIRMWARE (modem/bluetooth/dsp/tz/xbl...)...
for %%f in (modem bluetooth dsp tz xbl xbl_config abl aop hyp cpucp devcfg featenabler imagefv keymaster qupfw shrm uefisecapp cust) do (
    if exist "%IMG_DIR%\%%f.img" (
        echo       %%f.img
        "%FB%" flash %%f "%IMG_DIR%\%%f.img"
    )
)

echo.
echo       Flashing vbmeta (disable verity)...
"%FB%" --disable-verity --disable-verification flash vbmeta "%IMG_DIR%\vbmeta.img"
if exist "%IMG_DIR%\vbmeta_system.img" "%FB%" --disable-verity --disable-verification flash vbmeta_system "%IMG_DIR%\vbmeta_system.img"

echo.
echo [4/4] Flashing SYSTEM (boot/dtbo/vendor_boot/super)...
if exist "%IMG_DIR%\boot.img" "%FB%" flash boot "%IMG_DIR%\boot.img"
if exist "%IMG_DIR%\dtbo.img" "%FB%" flash dtbo "%IMG_DIR%\dtbo.img"
if exist "%IMG_DIR%\vendor_boot.img" "%FB%" flash vendor_boot "%IMG_DIR%\vendor_boot.img"
if exist "%IMG_DIR%\init_boot.img" "%FB%" flash init_boot "%IMG_DIR%\init_boot.img"
echo       Flashing super.img (this takes a few minutes)...
"%FB%" flash super "%SUPER_DIR%\super.img"
if errorlevel 1 (
    echo [WARNING] super failed. Try: fastboot reboot fastboot, then flash super.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   FULL flash complete! Rebooting... SIM/WiFi/BT should work.
echo ============================================================
"%FB%" reboot
pause
exit /b 0
