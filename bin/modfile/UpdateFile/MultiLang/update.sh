#!/usr/bin/env bash
# MultiLang/update.sh — cài app đa ngôn ngữ, BỎ QUA app quan trọng.
#
# CẢNH BÁO: Thay app hệ thống sai sẽ làm app BIẾN MẤT (Camera, Settings...).
# Chỉ thay app an toàn; app quan trọng giữ nguyên bản gốc.
set -euo pipefail

work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images"
source "$work_dir/functions.sh"

SRC="$work_dir/bin/modfile/UpdateFile/MultiLang/updatesource"
SKIP_FILE="$work_dir/bin/modfile/UpdateFile/MultiLang/skip_apps.txt"
PRIVAPP="$MAIN_FOLDER/product/priv-app"

[[ -d "$MAIN_FOLDER" ]] || { warn "No image root - MultiLang skipped"; exit 0; }
[[ -d "$SRC" ]] || { warn "MultiLang updatesource missing"; exit 0; }

# Đọc skip list (app quan trọng KHÔNG được thay)
SKIP=" "
if [[ -f "$SKIP_FILE" ]]; then
    SKIP=" $(tr -d "\r\n" < "$SKIP_FILE" | tr "," " ") "
fi

mods "Installing safe multilingual apps (skipping critical system apps)..."

installed=0
skipped=0
for apk in "$SRC"/KTOS.*.apk; do
    [[ -e "$apk" ]] || continue
    base="$(basename "$apk" .apk)"
    app="${base#KTOS.}"
    [[ -z "$app" ]] && continue

    # Bỏ qua app quan trọng (Camera, Settings, SystemUI...)
    if [[ "$SKIP" == *" $app "* ]]; then
        info "SKIP (critical): $app"
        skipped=$((skipped + 1))
        continue
    fi

    # Chỉ cài NẾU APK có kích thước hợp lệ (> 10KB, tránh file hỏng)
    sz=$(stat -c%s "$apk" 2>/dev/null || echo 0)
    if [[ "$sz" -lt 10240 ]]; then
        warn "SKIP (too small/corrupt): $app ($sz bytes)"
        continue
    fi

    # Thay app gốc
    for old in "$PRIVAPP/$app" "$MAIN_FOLDER/product/app/$app" \
               "$MAIN_FOLDER/system/system/app/$app" "$MAIN_FOLDER/system/system/priv-app/$app"; do
        [[ -d "$old" ]] && rm -rf "$old"
    done
    mkdir -p "$PRIVAPP/$app"
    cp -f "$apk" "$PRIVAPP/$app/$app.apk"
    chmod 644 "$PRIVAPP/$app/$app.apk"
    info "Multilingual: $app"
    installed=$((installed + 1))
done

mods "MultiLang done: $installed installed, $skipped critical apps kept (Camera, Settings safe)"
