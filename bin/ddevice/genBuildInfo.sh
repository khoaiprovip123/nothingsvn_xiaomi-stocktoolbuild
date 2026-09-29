#!/usr/bin/env bash
# genBuildInfo.sh — sinh file BUILD_INFO.txt ghi rõ ROM này được build từ gì.
# Chạy sau khi build xong, trước khi pack zip → file nằm trong ROM zip.
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../functions.sh
source "$work_dir/functions.sh"

OUT="$work_dir/build/baserom/BUILD_INFO.txt"

device_f=$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null || echo "unknown")
device_code=$(cat "$work_dir/bin/ddevice/device_code.txt" 2>/dev/null || echo "unknown")
rom_os=$(cat "$work_dir/bin/ddevice/rom_os.txt" 2>/dev/null || echo "unknown")
base_rom_code=$(cat "$work_dir/bin/ddevice/base_rom_code.txt" 2>/dev/null || echo "unknown")
androidVER=$(cat "$work_dir/bin/ddevice/androidver.txt" 2>/dev/null || echo "unknown")
sdkLevel=$(cat "$work_dir/bin/ddevice/sdkLevel.txt" 2>/dev/null || echo "unknown")
regionTYPE=$(cat "$work_dir/bin/ddevice/device_type.txt" 2>/dev/null || echo "unknown")
romtype=$(cat "$work_dir/bin/ddevice/romtype.txt" 2>/dev/null || echo "unknown")
fstype=$(cat "$work_dir/bin/ddevice/fstype.txt" 2>/dev/null || echo "unknown")
pack_ver=$(cat "$work_dir/Version" 2>/dev/null || echo "unknown")

# Feature flags (đã load từ config.env / env)
toolbox_flag="${install_toolbox:-true}"
mods_flag="${install_mods:-true}"
customapps_flag="${install_custom_apps:-true}"

# Git commit hiện tại
git_commit=$(git -C "$work_dir" rev-parse --short HEAD 2>/dev/null || echo "n/a")
git_branch=$(git -C "$work_dir" branch --show-current 2>/dev/null || echo "n/a")
build_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Liệt kê mod đã cài (dựa vào thư mục modfile)
mods_applied=""
for d in Universal UpdateFile/OS1 UpdateFile/OS2 UpdateFile/ReplaceApps UpdateFile/XiaomiAI \
         UpdateFile/DevicesUpdate CustomApps KaoriOS; do
    if [[ -d "$work_dir/bin/modfile/$d" ]]; then
        mods_applied+="  - $d"$'\n'
    fi
done

cat > "$OUT" <<EOF
================================================================
  BUILD INFO — KTOS Xiaomi ROM
================================================================

  Ngày build (UTC) : $build_time
  Tool version     : $pack_ver
  Git commit       : $git_commit ($git_branch)

----------------------------------------------------------------
  THIẾT BỊ & ROM NGUỒN
----------------------------------------------------------------
  Device codename  : $device_f
  Device code      : $device_code
  Khu vực          : $regionTYPE
  ROM gốc          : $base_rom_code
  Hệ điều hành     : $rom_os
  Android / SDK    : $androidVER / $sdkLevel
  Loại ROM (format): $romtype
  Filesystem       : $fstype

----------------------------------------------------------------
  TÍNH NĂNG ĐÃ BẬT (config.env)
----------------------------------------------------------------
  install_toolbox     : $toolbox_flag
  install_mods        : $mods_flag
  install_custom_apps : $customapps_flag

----------------------------------------------------------------
  MOD ĐÃ CÀI
----------------------------------------------------------------
$mods_applied
----------------------------------------------------------------
  CẢNH BÁO
----------------------------------------------------------------
  * ROM này dành cho thiết bị ĐÃ UNLOCK BOOTLOADER.
  * Tự chịu rủi ro khi flash. Không flash trên máy khác.
  * Nếu không boot: làm theo docs/BOOT_TROUBLESHOOTING.md
    rồi gửi zip log (ramoops + logcat + file này).

================================================================
EOF

info "BUILD_INFO.txt generated → $OUT"
