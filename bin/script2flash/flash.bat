@echo off
cd /d "%~dp0"
chcp 437 >nul
title KTOS ROM Flasher - lisa

set "FB=fastboot.exe"
if exist "%~dp0bin\windows\fastboot.exe" set "FB=%~dp0bin\windows\fastboot.exe"
if exist "%~dp0fastboot.exe" set "FB=%~dp0fastboot.exe"

:: detect super.img (images\ or super\)
set "SUPERIMG=images\super.img"
if not exist "%SUPERIMG%" set "SUPERIMG=super\super.img"

echo Waiting for device...
set "device="
for /f "tokens=2" %%D in ('"%FB%" getvar product 2^>^&1 ^| findstr /l /b /c:"product:"') do set "device=%%D"
if "!device!"=="" (echo Device not detected. & pause & exit /B 1)
echo Device: !device!
if /i not "!device!"=="lisa" (echo ROM is for lisa. Your device: !device! & pause & exit /B 1)

echo ==========================================
echo   KTOS ROM - lisa (Xiaomi 11 Lite 5G NE)
echo ==========================================
echo ERASE all data and flash ROM.
set /p choice=Continue? [y/N] 
if /i not "!choice!"=="y" (echo Cancelled. & pause & exit /B 0)

echo.
echo [1/4] Firmware (SIM/WiFi/BT)...
for %%f in (modem bluetooth dsp tz xbl xbl_config abl aop hyp cpucp devcfg featenabler imagefv keymaster qupfw shrm uefisecapp) do (
  if exist "images\%%f.img" (
    echo   %%f
    "%FB%" flash %%f_ab "images\%%f.img"
  )
)

echo [2/4] vbmeta (disable verity - QUAN TRONG)...
"%FB%" --disable-verity --disable-verification flash vbmeta images\vbmeta.img
if exist "images\vbmeta_system.img" "%FB%" --disable-verity --disable-verification flash vbmeta_system images\vbmeta_system.img
if exist "images\boot.img" "%FB%" flash boot_a images\boot.img
if exist "images\dtbo.img" "%FB%" flash dtbo images\dtbo.img
if exist "images\vendor_boot.img" "%FB%" flash vendor_boot images\vendor_boot.img
if exist "images\cust.img" "%FB%" flash cust images\cust.img

echo [3/4] super.img (few minutes)...
"%FB%" flash super "!SUPERIMG!"
if errorlevel 1 (echo [ERROR] super failed. & pause & exit /B 1)

echo [4/4] Erasing data...
"%FB%" erase userdata
"%FB%" erase metadata

echo ==========================================
echo   DONE! Rebooting... First boot 5-10 min.
echo ==========================================
"%FB%" reboot
pause
exit /B 0
