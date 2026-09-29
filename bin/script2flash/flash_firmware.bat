@echo off
setlocal enabledelayedexpansion
chcp 437 >nul
title KTOS - Flash FIRMWARE (fix SIM, WiFi, BT)

set "SCRIPT_DIR=%~dp0"
set "IMG_DIR=%SCRIPT_DIR%images"
set "FB=%SCRIPT_DIR%fastboot.exe"
if not exist "%FB%" set "FB=fastboot"

echo.
echo ============================================================
echo   Flash FIRMWARE partitions - fixes SIM / WiFi / Bluetooth
echo ============================================================
echo.
echo  This flashes: modem, bluetooth, dsp, tz, xbl, abl, etc.
echo  WITHOUT touching system. Safe to run on existing ROM.
echo.
set /p "CONFIRM=Continue? (y/N): "
if /i not "!CONFIRM!"=="y" (echo Cancelled. & pause & exit /b 0)

echo.
echo [1/2] Checking device...
"%FB%" devices | findstr /r /c:"fastboot" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No fastboot device. Boot into FASTBOOT first.
    pause
    exit /b 1
)

echo [2/2] Flashing firmware partitions...

:: --- SIM / baseband (quan trong nhat) ---
if exist "%IMG_DIR%\modem.img" (
    echo Flashing modem.img (SIM)...
    "%FB%" flash modem "%IMG_DIR%\modem.img"
)

:: --- Bluetooth ---
if exist "%IMG_DIR%\bluetooth.img" (
    echo Flashing bluetooth.img...
    "%FB%" flash bluetooth "%IMG_DIR%\bluetooth.img"
)

:: --- DSP / audio ---
if exist "%IMG_DIR%\dsp.img" (
    echo Flashing dsp.img...
    "%FB%" flash dsp "%IMG_DIR%\dsp.img"
)

:: --- TrustZone ---
if exist "%IMG_DIR%\tz.img" (
    echo Flashing tz.img...
    "%FB%" flash tz "%IMG_DIR%\tz.img"
)

:: --- Bootloader chain ---
if exist "%IMG_DIR%\xbl.img" "%FB%" flash xbl "%IMG_DIR%\xbl.img"
if exist "%IMG_DIR%\xbl_config.img" "%FB%" flash xbl_config "%IMG_DIR%\xbl_config.img"
if exist "%IMG_DIR%\abl.img" "%FB%" flash abl "%IMG_DIR%\abl.img"
if exist "%IMG_DIR%\aop.img" "%FB%" flash aop "%IMG_DIR%\aop.img"
if exist "%IMG_DIR%\hyp.img" "%FB%" flash hyp "%IMG_DIR%\hyp.img"

:: --- Khac ---
if exist "%IMG_DIR%\cpucp.img" "%FB%" flash cpucp "%IMG_DIR%\cpucp.img"
if exist "%IMG_DIR%\devcfg.img" "%FB%" flash devcfg "%IMG_DIR%\devcfg.img"
if exist "%IMG_DIR%\featenabler.img" "%FB%" flash featenabler "%IMG_DIR%\featenabler.img"
if exist "%IMG_DIR%\imagefv.img" "%FB%" flash imagefv "%IMG_DIR%\imagefv.img"
if exist "%IMG_DIR%\keymaster.img" "%FB%" flash keymaster "%IMG_DIR%\keymaster.img"
if exist "%IMG_DIR%\qupfw.img" "%FB%" flash qupfw "%IMG_DIR%\qupfw.img"
if exist "%IMG_DIR%\shrm.img" "%FB%" flash shrm "%IMG_DIR%\shrm.img"
if exist "%IMG_DIR%\uefisecapp.img" "%FB%" flash uefisecapp "%IMG_DIR%\uefisecapp.img"
if exist "%IMG_DIR%\cust.img" "%FB%" flash cust "%IMG_DIR%\cust.img"

echo.
echo ============================================================
echo   Firmware flash complete! Rebooting...
echo ============================================================
"%FB%" reboot
pause
exit /b 0
