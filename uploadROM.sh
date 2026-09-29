#!/usr/bin/env bash
# uploadROM.sh — package the flashable zip and upload it.
# Usage:
#   bash uploadROM.sh setup <GH_TOKEN> <GH_REPO> <RCLONE_TOKEN_PATH>
#   bash uploadROM.sh
set -euo pipefail

work_dir=$(pwd)
export WORK_DIR="$work_dir"

tools_dir="${work_dir}/bin/$(uname)/$(uname -m)"
export PATH="${tools_dir}:${PATH}"
chmod +x "${tools_dir}"/* 2>/dev/null || true

# shellcheck source=functions.sh
source "$work_dir/functions.sh"

RCLONE_CONFIG_1DRIVE="$work_dir/rclone.conf"
ONEDRIVE_REMOTE="ktos-toolbuild"

# Google Drive destination — override via env, never hardcode a secret-ish ID.
: "${GDRIVE_FOLDER_ID:=1Ezo6s99nX70l_wV24WAzr_A4t4WpFdSx}"

os_type=$(cat "$work_dir/bin/ddevice/os_type.txt") || true
base_rom_code=$(cat "$work_dir/bin/ddevice/base_rom_code.txt") || true
androidVER=$(cat "$work_dir/bin/ddevice/androidver.txt") || true
rom_os=$(cat "$work_dir/bin/ddevice/rom_os.txt") || true
regionTYPE=$(cat "$work_dir/bin/ddevice/device_type.txt") || true
device_code=$(cat "$work_dir/bin/ddevice/device_code.txt") || true
baserom_type=$(cat "$work_dir/bin/ddevice/romtype.txt") || true
device_f=$(cat "$work_dir/bin/ddevice/device_f.txt") || true

if [ "${1:-}" == "setup" ]; then
  # Cách 1 (KHUYẾN NGHỊ): giải mã token từ biến GDRIVE_TOKEN_B64 (GitHub Secret).
  # Loại bỏ whitespace/newline trước khi decode — GitHub Secrets hay thêm xuống dòng.
  if [ -n "${GDRIVE_TOKEN_B64:-}" ]; then
    printf '%s' "$GDRIVE_TOKEN_B64" | tr -d '[:space:]' | base64 -d > "$work_dir/token.pickle" 2>/dev/null || true
    # Kiểm tra token hợp lệ bằng Python (tránh pickle rỗng gây EOFError).
    if python3 -c "import pickle; pickle.load(open('$work_dir/token.pickle','rb'))" 2>/dev/null; then
      info "token.pickle restored and validated from GDRIVE_TOKEN_B64 secret."
      exit 0
    fi
    warn "GDRIVE_TOKEN_B64 decode/validate failed — trying fallback."
    rm -f "$work_dir/token.pickle"
  fi

  # Cách 2 (cũ): tải token.pickle từ repo riêng qua GH_TOKEN.
  if [ -z "${2:-}" ] || [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
    warn "Thiếu GDRIVE_TOKEN_B64 hợp lệ / GH_TOKEN — bỏ qua thiết lập upload."
    warn "  (Kiểm tra Secret GDRONE_TOKEN_B64: phải là base64 ĐẦY ĐỦ của token.pickle.)"
    exit 0
  fi
  curl -s -o "$work_dir/rclone.conf" \
        -H "Authorization: token $2" \
        -H "Accept: application/vnd.github.v3.raw" \
        -L "https://api.github.com/repos/$3/contents/$4"

  TOKEN_DIR=$(dirname "$4")
  if [ "$TOKEN_DIR" == "." ]; then
    TOKEN_PATH="token.pickle"
  else
    TOKEN_PATH="$TOKEN_DIR/token.pickle"
  fi

  curl -s -o "$work_dir/token.pickle" \
        -H "Authorization: token $2" \
        -H "Accept: application/vnd.github.v3.raw" \
        -L "https://api.github.com/repos/$3/contents/$TOKEN_PATH"

  exit 0
fi

if [[ "$(git branch --show-current 2>/dev/null || true)" == "beta" ]]; then
    polyxver="$(cat Version)"
    status="Development"
else
    polyxver="$(cat Version)"
    status="Official"
fi

if [[ $rom_os == "MIUI" ]]; then
    os_type="MIUI"
else
    os_type="HyperOS"
fi

repack "Generating flashing script"
out_dir="${work_dir}/out/${os_type}_${device_code}_${base_rom_code}"
if [[ ${baserom_type} == 'payload' ]]; then
    mkdir -p "${out_dir}/images/" "${out_dir}/super/"
    mv -f "$work_dir/build/baserom/images/super.img" "${out_dir}/super/"
    mv -f "$work_dir/build/baserom/images/"*.img "${out_dir}/images/"
elif [[ ${baserom_type} == 'br' ]]; then
    mkdir -p "${out_dir}/images/"
    mv -f "$work_dir/build/baserom/firmware-update/"* "${out_dir}/images/"
    mv -f "$work_dir/build/baserom/images/super.img" "${out_dir}/super/"
fi

cp -f "$work_dir/bin/script2flash/cust.img" "${out_dir}/images/" 2>/dev/null || true
cp -f "$work_dir/bin/script2flash/"*.install "${out_dir}/" 2>/dev/null || true

# Copy file nạp FASTBOOT vào output (user nạp bằng fastboot, không dùng recovery).
for flasher in flash_fastboot.bat flash_fastboot.sh; do
    if [[ -f "$work_dir/bin/script2flash/$flasher" ]]; then
        cp -f "$work_dir/bin/script2flash/$flasher" "${out_dir}/"
        chmod +x "${out_dir}/$flasher" 2>/dev/null || true
        info "Flasher added: $flasher"
    fi
done

# BẮT BUỘC: copy META-INF/ (update-binary + bin + Data) vào zip — thiếu thì
# zip không flash được bằng recovery (không có update-binary).
if [[ -d "$work_dir/bin/script2flash/META-INF" ]]; then
    rm -rf "${out_dir}/META-INF"
    cp -rf "$work_dir/bin/script2flash/META-INF" "${out_dir}/META-INF"
    # Đảm bảo update-binary có quyền thực thi trong zip.
    chmod 755 "${out_dir}/META-INF/com/google/android/update-binary" 2>/dev/null || true
    info "META-INF (recovery flasher) added to ROM"
else
    die "script2flash/META-INF missing — ROM would not be flashable"
fi

# Ghi BUILD_INFO.txt vào ROM zip — để biết build này từ nguồn nào, mod nào.
bash "$work_dir/bin/ddevice/genBuildInfo.sh"
if [[ -f "$work_dir/build/baserom/BUILD_INFO.txt" ]]; then
    cp -f "$work_dir/build/baserom/BUILD_INFO.txt" "${out_dir}/"
    info "BUILD_INFO.txt added to ROM"
fi

find "${out_dir}" | xargs touch
pushd "${out_dir}" >/dev/null || exit 1
zip -r "${os_type}_${device_code}_${base_rom_code}.zip" ./*
mv "${os_type}_${device_code}_${base_rom_code}.zip" ../
popd >/dev/null || exit 1

hash=$(md5sum "out/${os_type}_${device_code}_${base_rom_code}.zip" | head -c 5)
final_zip="out/${os_type}_${polyxver}_${device_code}_${base_rom_code}_${hash}_${status}.zip"
mv "out/${os_type}_${device_code}_${base_rom_code}.zip" "$final_zip"
repack "Build completed"
repack "Output: "
repack "$(pwd)/${final_zip}"
upload "Uploading"
output_file="$final_zip"
printf '%s\n' "$(basename "$final_zip")" > "$work_dir/bin/ddevice/output_zip.txt"

if [[ $rom_os == "MIUI" ]]; then
    uploaddir="MIUI"
else
    uploaddir="HyperOS"
fi

# 1drive (kept for reference — currently unused)
# rclone -v --config="$RCLONE_CONFIG_1DRIVE" copy "$output_file" \
#     "$ONEDRIVE_REMOTE:NTBuild/${uploaddir}/${polyxver}/${device_code}/"

# Google Drive
upload "Uploading to Google Drive..."
python3 "$work_dir/upload_rom_api.py" "$output_file" \
    --folder_id "$GDRIVE_FOLDER_ID" \
    --path "${uploaddir}/${polyxver}/${device_code}/" \
    || upload "Error uploading file to Google Drive"

upload "Clean Workflow.."
upload "Build ${os_type}_${polyxver} for ${device_code} successfull!"