@echo off
cd /d "%~dp0"
chcp 437 >nul
title KTOS ROM Flasher - lisa

set fastboot=bin\windows\fastboot.exe
if not exist %fastboot% (
  echo %fastboot% not found.
  pause
  exit /B 1
)

echo Waiting for device...
set device=
for /f "tokens=2" %%D in ('%fastboot% getvar product 2^>^&1 ^| findstr /l /b /c:"product:"') do set device=%%D
if "%device%" equ "" (
  echo Your device could not be detected.
  pause
  exit /B 1
)
echo Your device: %device%
if "%device%" neq "lisa" (
  echo Compatible devices: lisa
  pause
  exit /B 1
)

echo ================================
echo   KTOS ROM - Xiaomi 11 Lite 5G NE (lisa)
echo ================================
echo This process will ERASE all data and flash the ROM.
set /p choice=Do you want to continue? [y/N] 
if /i "%choice%" neq "y" (
  exit /B 0
)

echo ##############################################################
echo Please wait. The device will reboot once flashing is complete.
echo ##############################################################

:: --- set active slot a ---
%fastboot% set_active a

:: --- flash firmware (both slots via _ab) ---
for %%f in (abl aop bluetooth cpucp devcfg dsp dtbo featenabler hyp imagefv keymaster modem qupfw shrm tz uefisecapp vbmeta vbmeta_system xbl xbl_config boot vendor_boot) do (
  if exist "images\%%f.img" (
    echo Flashing %%f...
    %fastboot% flash %%f_ab images\%%f.img
  )
)
if exist "images\cust.img" %fastboot% flash cust images\cust.img

:: --- flash super ---
echo Flashing super (few minutes)...
%fastboot% flash super images\super.img

:: --- erase data ---
%fastboot% erase metadata
%fastboot% erase userdata

echo ##############################################################
echo   FLASH COMPLETE! Rebooting...
echo ##############################################################
%fastboot% reboot
pause
exit /B 0
