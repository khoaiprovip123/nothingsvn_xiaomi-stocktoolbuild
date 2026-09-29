@echo off
setlocal enabledelayedexpansion
chcp 437 >nul
title KTOS ROM Flasher

set "ROOT=%~dp0"
set "FW=%ROOT%firmware-update"
set "SUPER=%ROOT%super"
set "FB=%ROOT%bin\fastboot.exe"
set "LOG=%ROOT%flash.log"

:: --- log helper ---
call :log "========== KTOS ROM Flasher =========="

echo.
echo ==========================================
echo   KTOS ROM Flasher
echo ==========================================
echo.

:: --- 1. check fastboot ---
if not exist "%FB%" (
  call :log "ERROR: bin\fastboot.exe not found"
  echo [ERROR] bin\fastboot.exe not found.
  pause & exit /b 1
)
call :log "Using fastboot: %FB%"

:: --- 2. check device ---
echo [1/5] Checking device...
"%FB%" devices | findstr /r /c:"fastboot" >nul 2>&1
if errorlevel 1 (
  call :log "ERROR: no fastboot device"
  echo [ERROR] No fastboot device. Boot to FASTBOOT + connect USB.
  pause & exit /b 1
)
for /f "tokens=1" %%d in ('"%FB%" devices') do set "SERIAL=%%d"
echo       Device: %SERIAL%
call :log "Device: %SERIAL%"

:: --- 3. check files ---
echo [2/5] Checking ROM files...
if not exist "%SUPER%\super.img" (echo [ERROR] super\super.img missing. & call :log "ERROR: super.img missing" & pause & exit /b 1)
if not exist "%FW%\vbmeta.img" (echo [ERROR] firmware-update\vbmeta.img missing. & pause & exit /b 1)
if not exist "%FW%\boot.img" (echo [ERROR] firmware-update\boot.img missing. & pause & exit /b 1)
echo       OK: firmware-update\ + super\
call :log "ROM files OK"

:: --- 4. data mode ---
echo.
echo   DATA MODE / CHE DO DU LIEU:
echo     1. FORMAT DATA  (xoa het - sach, khuyen nghi)
echo     2. KEEP DATA    (giu app + du lieu)
echo.
set /p "MODE=Chon (1/2): "
if "!MODE!"=="1" (set "DOFORMAT=1") else (set "DOFORMAT=0")
if "!DOFORMAT!"=="1" (call :log "Data mode: FORMAT") else (call :log "Data mode: KEEP")

set /p "OK=Proceed / Tiep tuc? (y/N): "
if /i not "!OK!"=="y" (call :log "Cancelled by user" & echo Cancelled. & pause & exit /b 0)

:: --- 5. flash firmware ---
echo.
echo [3/5] Flashing firmware (modem/bluetooth/dsp/tz/xbl...)...
call :log "--- Flashing firmware ---"
for %%f in (modem bluetooth dsp tz xbl xbl_config abl aop hyp cpucp devcfg featenabler imagefv keymaster qupfw shrm uefisecapp cust) do (
  if exist "%FW%\%%f.img" (
    echo       %%f.img
    call :log "flash %%f"
    "%FB%" flash %%f "%FW%\%%f.img" >> "%LOG%" 2>&1
  )
)

:: --- 6. flash vbmeta (disable verity) ---
echo       vbmeta (disable verity)
call :log "flash vbmeta (disable verity)"
"%FB%" --disable-verity --disable-verification flash vbmeta "%FW%\vbmeta.img" >> "%LOG%" 2>&1
if exist "%FW%\vbmeta_system.img" "%FB%" --disable-verity --disable-verification flash vbmeta_system "%FW%\vbmeta_system.img" >> "%LOG%" 2>&1

:: --- 7. flash system ---
echo.
echo [4/5] Flashing system (boot/dtbo/super)...
call :log "--- Flashing system ---"
if exist "%FW%\boot.img" "%FB%" flash boot "%FW%\boot.img" >> "%LOG%" 2>&1
if exist "%FW%\dtbo.img" "%FB%" flash dtbo "%FW%\dtbo.img" >> "%LOG%" 2>&1
if exist "%FW%\vendor_boot.img" "%FB%" flash vendor_boot "%FW%\vendor_boot.img" >> "%LOG%" 2>&1
if exist "%FW%\init_boot.img" "%FB%" flash init_boot "%FW%\init_boot.img" >> "%LOG%" 2>&1
echo       super.img (vai phut)...
call :log "flash super (takes minutes)"
"%FB%" flash super "%SUPER%\super.img" >> "%LOG%" 2>&1
if errorlevel 1 (
  call :log "ERROR: flash super failed"
  echo [ERROR] Flash super failed. Try: fastboot reboot fastboot
  pause & exit /b 1
)

:: --- 8. format / keep data ---
echo.
echo [5/5] Data...
if "!DOFORMAT!"=="1" (
  echo       Formatting data...
  call :log "erase userdata/metadata/cache"
  "%FB%" erase userdata >> "%LOG%" 2>&1
  "%FB%" erase metadata >> "%LOG%" 2>&1
  "%FB%" erase cache >> "%LOG%" 2>&1
) else (
  echo       Keeping data.
  call :log "keeping data"
)

:: --- 9. done ---
call :log "========== FLASH COMPLETE =========="
echo.
echo ==========================================
echo   FLASH COMPLETE!
if "!DOFORMAT!"=="1" (echo   Data: FORMATTED)
if "!DOFORMAT!"=="0" (echo   Data: KEPT)
echo   Log: flash.log
echo ==========================================
"%FB%" reboot
call :log "rebooting"
pause
exit /b 0

:log
echo %date% %time% %~1 >> "%LOG%"
goto :eof
