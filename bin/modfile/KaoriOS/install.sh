#!/usr/bin/env bash
# KaoriOS/install.sh — install the KaoriOS Toolbox (xeutoolbox) into system_ext.
#
# Gated by config.env: install_toolbox=true|false
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

# Feature flags come from build.sh (which sources config.env and exports them).
# Environment variables always win; config.env only supplies defaults.
: "${install_toolbox:=true}"

if [[ "$install_toolbox" != "true" ]]; then
    info "install_toolbox=false — skipping KaoriOS Toolbox"
    exit 0
fi

SRC="$work_dir/bin/modfile/KaoriOS"
IMAGE_ROOT="$work_dir/build/baserom/images"
TOOLBOX_SRC="$work_dir/bin/package/ResetProp/system_ext/xbin/xeutoolbox"
TARGET_XBIN="$IMAGE_ROOT/system_ext/xbin"
TARGET_ETC="$IMAGE_ROOT/system_ext/etc"

mods "Installing KaoriOS Toolbox..."

# 1. KaoriosToolbox.apk → product/priv-app/KaoriosToolbox/ (không root).
KAORIOS_APK="$SRC/KaoriosToolbox.apk"
if [[ -f "$KAORIOS_APK" ]]; then
    TARGET_PRIV="$IMAGE_ROOT/product/priv-app/KaoriosToolbox"
    mkdir -p "$TARGET_PRIV"
    cp -f "$KAORIOS_APK" "$TARGET_PRIV/KaoriosToolbox.apk"
    chmod 644 "$TARGET_PRIV/KaoriosToolbox.apk"
    info "Installed KaoriosToolbox.apk → product/priv-app/"
else
    warn "KaoriosToolbox.apk not found in $SRC"
fi

# 2. Drop the legacy toolbox binary into system_ext/xbin (optional, for scripts).
if [[ -f "$TOOLBOX_SRC" ]]; then
    mkdir -p "$TARGET_XBIN"
    cp -f "$TOOLBOX_SRC" "$TARGET_XBIN/xeutoolbox"
    chmod 755 "$TARGET_XBIN/xeutoolbox"
    info "Installed xeutoolbox → system_ext/xbin/"
elif [[ -f "$SRC/xeutoolbox" ]]; then
    mkdir -p "$TARGET_XBIN"
    cp -f "$SRC/xeutoolbox" "$TARGET_XBIN/xeutoolbox"
    chmod 755 "$TARGET_XBIN/xeutoolbox"
    info "Installed xeutoolbox from KaoriOS folder"
fi

# 3. Whitelist + sysconfig XML → product/etc/permissions/.
PERMS="$IMAGE_ROOT/product/etc/permissions"
mkdir -p "$PERMS"
for xml in "$SRC/privapp_whitelist_com.kousei.kaorios.xml" "$SRC/com.kousei.kaorios.xml"; do
    if [[ -f "$xml" ]]; then
        cp -f "$xml" "$PERMS/"
        info "Permission: $(basename "$xml")"
    fi
done

# 4. SELinux policy additions (from ResetProp, which owns the type definitions).
if [[ -d "$work_dir/bin/package/ResetProp/system_ext" ]]; then
    if [[ -d "$work_dir/bin/package/ResetProp/system_ext/etc/selinux" ]]; then
        mkdir -p "$TARGET_ETC/selinux"
        cp -rf "$work_dir/bin/package/ResetProp/system_ext/etc/selinux/." "$TARGET_ETC/selinux/" 2>/dev/null || true
        info "Installed toolbox SELinux bits"
    fi
fi

# 5. Any extra files shipped in KaoriOS/ (system_ext overlay, .cil).
if [[ -d "$SRC/system_ext" ]]; then
    cp -rf "$SRC/system_ext/." "$IMAGE_ROOT/system_ext/" 2>/dev/null || true
    info "Installed KaoriOS system_ext overlay"
fi

CIL="$SRC/xeutoolbox.cil"
if [[ -f "$CIL" ]]; then
    TARGET_CIL="$IMAGE_ROOT/system_ext/etc/selinux/system_ext_sepolicy.cil"
    mkdir -p "$(dirname "$TARGET_CIL")"
    cat "$CIL" >> "$TARGET_CIL"
    info "Appended xeutoolbox.cil to system_ext_sepolicy.cil"
fi

mods "KaoriOS Toolbox installed"
