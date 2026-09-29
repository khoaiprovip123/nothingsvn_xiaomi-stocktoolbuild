@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title KTOS — Fastboot Flasher (Xiaomi)

:: ============================================================
::  flash_fastboot.bat — nạp ROM KTOS qua FASTBOOT
::  (không dùng recovery — dành cho máy đã unlock bootloader)
::
::  Cách dùng:
::    1. Cài Android platform-tools (adb + fastboot) vào PATH
::    2. Đưa máy vào chế độ FASTBOOT (tắt nguồn → giữ Giảm âm + Nguồn)
::    3. Copy file .bat này + thư mục images/ + super/ vào cùng chỗ
::    4. Chạy:  flash_fastboot.bat
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "IMG_DIR=%SCRIPT_DIR%images"
set "SUPER_DIR=%SCRIPT_DIR%super"

echo.
echo ============================================================
echo   KTOS ROM Flasher — FASTBOOT mode
echo ============================================================
echo.

:: --- 1. Kiểm tra fastboot ---
where fastboot >nul 2>&1
if errorlevel 1 (
    echo [LOI] Khong tim thay 'fastboot' trong PATH.
    echo       Cai Android platform-tools: https://developer.android.com/tools/releases/platform-tools
    pause
    exit /b 1
)

:: --- 2. Kiểm tra thiết bị ---
echo [1/6] Kiem tra ket noi fastboot...
fastboot devices | findstr /r /c:"fastboot" >nul 2>&1
if errorlevel 1 (
    echo [LOI] Khong thay thiet bi fastboot.
    echo       Hay dua may vao che do FASTBOOT roi ket noi USB.
    pause
    exit /b 1
)
for /f "tokens=1" %%d in ('fastboot devices') do set "SERIAL=%%d"
echo       Thiet bi: %SERIAL%

:: --- 3. Kiểm tra file ROM ---
echo [2/6] Kiem tra file ROM...
set "MISSING=0"
for %%f in (vbmeta boot dtbo) do (
    if exist "%IMG_DIR%\%%f.img" (
        echo       [OK] images\%%f.img
    ) else (
        echo       [THIEU] images\%%f.img
        set "MISSING=1"
    )
)
if exist "%SUPER_DIR%\super.img" (
    echo       [OK] super\super.img
) else (
    echo       [THIEU] super\super.img
    set "MISSING=1"
)
if "!MISSING!"=="1" (
    echo [LOI] Thieu file ROM. Hay kiem tra lai thu muc images\ va super\.
    pause
    exit /b 1
)

:: --- 4. Xác nhận ---
echo.
echo  CHU Y:
echo    - May PHAI da unlock bootloader.
echo    - Flash ROM sai may co the gay BRICK.
echo    - Se flash: vbmeta, boot, dtbo, vendor_boot (neu co), super.
echo.
set /p "CONFIRM=Ban co chac chan flash? (y/N): "
if /i not "!CONFIRM!"=="y" (
    echo Da huy.
    pause
    exit /b 0
)

:: --- 5. Flash vbmeta (TAT xac minh — bat buoc cho ROM da sua) ---
echo.
echo [3/6] Flash vbmeta (disable verity + verification)...
fastboot --disable-verity --disable-verification flash vbmeta "%IMG_DIR%\vbmeta.img"
if errorlevel 1 (
    echo [LOI] Flash vbmeta that bai.
    pause
    exit /b 1
)
if exist "%IMG_DIR%\vbmeta_system.img" (
    fastboot --disable-verity --disable-verification flash vbmeta_system "%IMG_DIR%\vbmeta_system.img"
    echo       Da flash vbmeta_system.
)

:: --- 6. Flash firmware ---
echo [4/6] Flash firmware...
if exist "%IMG_DIR%\boot.img" (
    fastboot flash boot "%IMG_DIR%\boot.img"
)
if exist "%IMG_DIR%\dtbo.img" (
    fastboot flash dtbo "%IMG_DIR%\dtbo.img"
)
if exist "%IMG_DIR%\vendor_boot.img" (
    fastboot flash vendor_boot "%IMG_DIR%\vendor_boot.img"
)
if exist "%IMG_DIR%\init_boot.img" (
    fastboot flash init_boot "%IMG_DIR%\init_boot.img"
)

:: --- 7. Flash super ---
echo [5/6] Flash super (he thong)...
echo       *(Neu loi, thu chay: fastboot reboot fastboot  roi chay lai file nay)*
fastboot flash super "%SUPER_DIR%\super.img"
if errorlevel 1 (
    echo.
    echo [CANH BAO] Flash super loi. Thu flash super tu fastbootd:
    echo       fastboot reboot fastboot
    echo       fastboot flash super "%SUPER_DIR%\super.img"
    echo       fastboot reboot
    pause
    exit /b 1
)

:: --- 8. Hoan tat ---
echo [6/6] Hoan tat! Khoi dong lai may...
fastboot reboot
echo.
echo ============================================================
echo   Flash xong! May se khoi dong lai.
echo   * Neu bootloop: format data trong recovery, hoac xem
echo     docs\BOOT_TROUBLESHOOTING.md
echo ============================================================
echo.
pause
exit /b 0
