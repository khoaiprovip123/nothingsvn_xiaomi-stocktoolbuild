#!/usr/bin/env bash
# ReplaceApps/update.sh — thay app stock của Xiaomi bằng APK mod đã tải sẵn.
#
# Cài thẳng vào image ROM (product/priv-app / product/overlay / product/etc),
# KHÔNG dùng root/Magisk — sau khi flash ROM là app hệ thống, chạy không cần root.
#
# Nguồn APK:  bin/modfile/UpdateFile/ReplaceApps/apks/
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

IMAGE_ROOT="$work_dir/build/baserom/images"
SRC="$work_dir/bin/modfile/UpdateFile/ReplaceApps/apks"
PRIVAPP="$IMAGE_ROOT/product/priv-app"
OVERLAY="$IMAGE_ROOT/product/overlay"
PERMS="$IMAGE_ROOT/product/etc/permissions"
SYSAPP="$IMAGE_ROOT/product/app"

[[ -d "$IMAGE_ROOT" ]] || { warn "No image root — ReplaceApps skipped"; exit 0; }
[[ -d "$SRC" ]] || { warn "ReplaceApps apks folder missing"; exit 0; }

mods "ReplaceApps: installing mod APKs (no root, baked into product/)"

# install_apk <source.apk> <AppName> [dest=priv-app]
# Removes any stock app with the same name first, then installs the new APK.
install_apk() {
    local apk="$1" name="$2" dest="${3:-priv-app}"
    [[ -f "$apk" ]] || { warn "APK missing: $apk"; return 0; }

    local target_root="$PRIVAPP"
    [[ "$dest" == "app" ]] && target_root="$SYSAPP"
    [[ "$dest" == "overlay" ]] && target_root="$OVERLAY"

    if [[ "$dest" == "overlay" ]]; then
        mkdir -p "$target_root"
        cp -f "$apk" "$target_root/$name"
        info "Overlay: $name"
        return 0
    fi

    # Xoá bản stock ở các vị trí phổ biến trước khi cài bản mod.
    local old
    for old in "$PRIVAPP/$name" "$SYSAPP/$name" "$IMAGE_ROOT/system/system/app/$name" "$IMAGE_ROOT/system/system/priv-app/$name"; do
        if [[ -d "$old" ]]; then
            info "Removing stock: $old"
            rm -rf "$old"
        fi
    done

    mkdir -p "$target_root/$name"
    cp -f "$apk" "$target_root/$name/$name.apk"
    chmod 644 "$target_root/$name/$name.apk"
    info "Installed: $dest/$name/$name.apk ($(du -h "$apk" | cut -f1))"
}

# ---------- Keyboard / overlay --------------------------------------------
install_apk "$SRC/GestureLineOverlay.apk"     "GestureLineOverlay.apk"      overlay

# ---------- Package installer ---------------------------------------------
install_apk "$SRC/GooglePackageInstaller.apk" "GooglePackageInstaller"
install_apk "$SRC/MiuiPackageInstaller.apk"   "MiuiPackageInstaller"

# ---------- Launcher / Theme / Vault / Security ---------------------------
install_apk "$SRC/MiuiHome.apk"               "MiuiHome"
install_apk "$SRC/MIUIThemeManager.apk"       "MIUIThemeManager"
install_apk "$SRC/AppVault.apk"               "AppVault"
install_apk "$SRC/SecurityMod_v13.5.3_PeaceModss.apk" "SecurityCenter"

# ---------- Keyboard extras ----------------------------------------------
install_apk "$SRC/MIUIFrequentPhrase.apk"     "MIUIFrequentPhrase"
install_apk "$SRC/LatinImeGoogle.apk"         "LatinImeGoogle"

# ---------- Joyose / HolyBear --------------------------------------------
install_apk "$SRC/JoyoseMod_v2.5.20_PeaceModss.apk" "Joyose"
install_apk "$SRC/HolyBear_5.0.230706.0_release.apk" "HolyBear"

# ---------- Quyền priv-app -------------------------------------------------
# Whitelist để app mod được cấp quyền privileged (vẫn không cần root).
for xml in "$work_dir/bin/modfile/KaoriOS/privapp_whitelist_com.kousei.kaorios.xml" \
           "$work_dir/bin/modfile/KaoriOS/com.kousei.kaorios.xml"; do
    if [[ -f "$xml" ]]; then
        mkdir -p "$PERMS"
        cp -f "$xml" "$PERMS/"
        info "Permission: $(basename "$xml")"
    fi
done

mods "ReplaceApps done"
