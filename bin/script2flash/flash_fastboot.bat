@echo off
setlocal enabledelayedexpansion
chcp 437 >nul
title KTOS ROM Flasher - FULL

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

if "%FB%"=="fastboot" (where fastboot >nul 2>&1 & if errorlevel 1 (echo [ERROR] fastboot not found. & pause & exit /b 1))
echo       Using: %FB%

echo [1/5] Checking fastboot connection...
"%FB%" devices | findstr /r /c:"fastboot" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No fastboot device. Boot into FASTBOOT + connect USB.
    pause
    exit /b 1
)
for /f "tokens=1" %%d in ('"%FB%" devices') do set "SERIAL=%%d"
echo       Device: %SERIAL%

echo [2/5] Checking ROM files...
set "MISSING=0"
if exist "%SUPER_DIR%\super.img" (echo       [OK] super.img) else (echo       [MISSING] super.img & set "MISSING=1")
if exist "%IMG_DIR%\boot.img" (echo       [OK] boot.img) else (echo       [MISSING] boot.img & set "MISSING=1")
if exist "%IMG_DIR%\vbmeta.img" (echo       [OK] vbmeta.img) else (echo       [MISSING] vbmeta.img & set "MISSING=1")
if "!MISSING!"=="1" (echo [ERROR] Missing critical files. & pause & exit /b 1)

:: --- DATA OPTION ---
echo.
echo  ============================================================
echo   CHON CHE DO DU LIEU / DATA MODE:
echo  ============================================================
echo    1. FORMAT DATA - Xoa het du lieu (sach, khuyen nghi)
echo       - Xoa cache, app, du lieu cu - hanh on dinh nhat
echo    2. GIU NGUYEN DATA - Giu app + du lieu nguoi dung
echo       - Co the loi app neu khop chu ky - nhanh hon
echo  ============================================================
echo.
set /p "DATAMODE=Chon (1 hoac 2): "

if "!DATAMODE!"=="1" (
    echo.
    echo  -> Se FORMAT DATA (xoa het du lieu).
    set /p "CONFIRM1=Chac chan FORMAT? (y/N): "
    if /i not "!CONFIRM1!"=="y" (echo Huy. & pause & exit /b 0)
    set "DOFORMAT=1"
) else (
    echo.
    echo  -> Se GIU NGUYEN DATA.
    set /p "CONFIRM2=Chac chan flash giu data? (y/N): "
    if /i not "!CONFIRM2!"=="y" (echo Huy. & pause & exit /b 0)
    set "DOFORMAT=0"
)

:: --- FLASH FIRMWARE ---
echo.
echo [3/5] Flashing FIRMWARE (modem/bluetooth/dsp/tz/xbl)...
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

:: --- FLASH SYSTEM ---
echo.
echo [4/5] Flashing SYSTEM (boot/dtbo/super)...
if exist "%IMG_DIR%\boot.img" "%FB%" flash boot "%IMG_DIR%\boot.img"
if exist "%IMG_DIR%\dtbo.img" "%FB%" flash dtbo "%IMG_DIR%\dtbo.img"
if exist "%IMG_DIR%\vendor_boot.img" "%FB%" flash vendor_boot "%IMG_DIR%\vendor_boot.img"
if exist "%IMG_DIR%\init_boot.img" "%FB%" flash init_boot "%IMG_DIR%\init_boot.img"
echo       Flashing super.img (vai phut)...
"%FB%" flash super "%SUPER_DIR%\super.img"
if errorlevel 1 (
    echo [WARNING] super failed. Try: fastboot reboot fastboot, then flash super.
    pause
    exit /b 1
)

:: --- FORMAT DATA / KEEP DATA ---
echo.
if "!DOFORMAT!"=="1" (
    echo [5/5] FORMATTING DATA (xoa het du lieu)...
    "%FB%" erase userdata
    "%FB%" erase metadata
    "%FB%" erase cache
    echo       Da xoa data. May se khoi dong sach.
) else (
    echo [5/5] GIU NGUYEN DATA (khong xoa du lieu)...
)

echo.
echo ============================================================
echo   Flash complete! Rebooting...
if "!DOFORMAT!"=="1" (echo   Data: DA FORMAT - may khoi dong sach.)
if "!DOFORMAT!"=="0" (echo   Data: GIU NGUYEN - app + du lieu giu lai.)
echo   Neu bootloop: vao recovery format data.
echo ============================================================
"%FB%" reboot
pause
exit /b 0
