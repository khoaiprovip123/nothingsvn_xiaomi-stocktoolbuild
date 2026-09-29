#!/usr/bin/env bash
# MultiLang/update.sh — cài bản app hệ thống ĐA NGÔN NGỮ (có tiếng Việt).
#
# Các file trong updatesource/ là bản mod của app hệ thống Xiaomi (Settings,
# SecurityCenter, SystemUI, Contacts...) đã thêm ngôn ngữ (Việt, Anh, ...).
# Thay app gốc (chỉ có Trung/Anh) bằng bản này để dùng tiếng Việt + Hyper AI.
#
# Trước đây script copy vào product/overlay/ (SAI — APK không phải overlay),
# giờ cài vào priv-app/app đúng chỗ, thay app gốc.
set -euo pipefail

work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images"
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

SRC="$work_dir/bin/modfile/UpdateFile/MultiLang/updatesource"
PRIVAPP="$MAIN_FOLDER/product/priv-app"
SYSAPP="$MAIN_FOLDER/product/app"

[[ -d "$MAIN_FOLDER" ]] || { warn "No image root — MultiLang skipped"; exit 0; }
[[ -d "$SRC" ]] || { warn "MultiLang updatesource missing"; exit 0; }

mods "Installing multilingual system apps (adds Vietnamese + more)..."

installed=0
# Cài từng APK vào product/priv-app (thay app gốc cùng tên).
# File tên KTOS.<AppName>.apk → cài thành <AppName>/.
for apk in "$SRC"/KTOS.*.apk; do
    [[ -e "$apk" ]] || continue
    base="$(basename "$apk" .apk)"
    # Bỏ tiền tố KTOS. để ra tên app gốc (vd: KTOS.Settings → Settings)
    app="${base#KTOS.}"
    [[ -z "$app" ]] && continue

    # Xoá bản gốc ở các vị trí phổ biến
    for old in "$PRIVAPP/$app" "$SYSAPP/$app" \
               "$MAIN_FOLDER/system/system/app/$app" \
               "$MAIN_FOLDER/system/system/priv-app/$app"; do
        [[ -d "$old" ]] && { info "Replacing stock: $app"; rm -rf "$old"; }
    done

    mkdir -p "$PRIVAPP/$app"
    cp -f "$apk" "$PRIVAPP/$app/$app.apk"
    chmod 644 "$PRIVAPP/$app/$app.apk"
    info "Multilingual app: $app"
    installed=$((installed + 1))
done

mods "MultiLang done — $installed multilingual apps installed (incl. Vietnamese)"
