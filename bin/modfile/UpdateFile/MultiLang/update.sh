#!/usr/bin/env bash
# MultiLang/update.sh — cài app đa ngôn ngữ + framework resources (tiếng Việt).
#
# framework_res.apk = nguồn NGÔN NGỮ hệ thống (Vietnamese, English...).
# Phải cài vào system/framework/ (KHÔNG phải priv-app).
set -euo pipefail

work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images"
source "$work_dir/functions.sh"

SRC="$work_dir/bin/modfile/UpdateFile/MultiLang/updatesource"
SKIP_FILE="$work_dir/bin/modfile/UpdateFile/MultiLang/skip_apps.txt"
PRIVAPP="$MAIN_FOLDER/product/priv-app"
FRAMEWORK_DIR=""
# Tìm thư mục framework trong ROM
for d in "$MAIN_FOLDER/system/system/framework" "$MAIN_FOLDER/system/framework" "$MAIN_FOLDER/system_ext/framework"; do
    [[ -d "$d" ]] && FRAMEWORK_DIR="$d" && break
done

[[ -d "$MAIN_FOLDER" ]] || { warn "No image root - MultiLang skipped"; exit 0; }
[[ -d "$SRC" ]] || { warn "MultiLang updatesource missing"; exit 0; }

mods "Installing multilingual resources + apps (Vietnamese)..."

# --- 1. Framework resources (NGÔN NGỮ) — cài vào system/framework/ ---
# CHU Y: Thay framework-res.apk co the gay BOOTLOOP neu khong khop phien ban HyperOS.
# Mac dinh TAT. Bat bang: export INSTALL_FRAMEWORK_RES=true
INSTALL_FRAMEWORK_RES="${INSTALL_FRAMEWORK_RES:-false}"
if [[ "$INSTALL_FRAMEWORK_RES" == "true" && -n "$FRAMEWORK_DIR" ]]; then
    if [[ -f "$SRC/KTOS.framework_res.apk" ]]; then
        cp -f "$SRC/KTOS.framework_res.apk" "$FRAMEWORK_DIR/framework-res.apk"
        info "Installed framework-res.apk (adds Vietnamese language)"
    fi
    if [[ -f "$SRC/KTOS.framework.ext.res.apk" ]]; then
        cp -f "$SRC/KTOS.framework.ext.res.apk" "$FRAMEWORK_DIR/framework-ext-res.apk"
        info "Installed framework-ext-res.apk (extended languages)"
    fi
else
    warn "framework dir not found - language pack skipped"
fi

# --- 2. App đa ngôn ngữ (bỏ qua app quan trọng) ---
SKIP=" "
if [[ -f "$SKIP_FILE" ]]; then
    SKIP=" $(tr -d "\r\n" < "$SKIP_FILE" | tr "," " ") "
fi

installed=0
skipped=0
for apk in "$SRC"/KTOS.*.apk; do
    [[ -e "$apk" ]] || continue
    base="$(basename "$apk" .apk)"
    app="${base#KTOS.}"
    [[ -z "$app" ]] && continue

    # Bỏ qua framework resources (đã cài ở trên)
    case "$app" in framework_res|framework.ext.res) continue ;; esac

    # Bỏ qua app quan trọng
    if [[ "$SKIP" == *" $app "* ]]; then
        info "SKIP (critical): $app"
        skipped=$((skipped + 1))
        continue
    fi

    sz=$(stat -c%s "$apk" 2>/dev/null || echo 0)
    if [[ "$sz" -lt 10240 ]]; then
        warn "SKIP (corrupt): $app"
        continue
    fi

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

mods "MultiLang done: language pack + $installed apps, $skipped critical kept"
