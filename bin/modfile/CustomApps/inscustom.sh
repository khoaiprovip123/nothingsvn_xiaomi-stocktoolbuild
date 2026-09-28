#!/usr/bin/env bash
# inscustom.sh — install user-supplied APKs from bin/modfile/CustomApps/.
#
# Drop APKs (and optionally a folder with lib/ + privapp whitelist XML) into
# bin/modfile/CustomApps/ and they are copied into the ROM on the next build.
#
# Layout conventions:
#   CustomApps/*.apk                          → product/priv-app/<Name>/<Name>.apk
#   CustomApps/<AppName>/                     → product/priv-app/<AppName>/
#   CustomApps/privapp_whitelist_*.xml        → product/etc/permissions/
#   CustomApps/overlay/*.apk                  → product/overlay/
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

SRC="$work_dir/bin/modfile/CustomApps"
IMAGE_ROOT="$work_dir/build/baserom/images"
PRIVAPP="$IMAGE_ROOT/product/priv-app"
OVERLAY="$IMAGE_ROOT/product/overlay"
PERMS="$IMAGE_ROOT/product/etc/permissions"

[[ -d "$SRC" ]] || { warn "CustomApps folder missing: $SRC"; exit 0; }

# Feature flags come from build.sh (which sources config.env and exports them).
# Environment variables always win; config.env only supplies defaults.
: "${install_custom_apps:=true}"

if [[ "$install_custom_apps" != "true" ]]; then
    info "install_custom_apps=false — skipping CustomApps"
    exit 0
fi

mods "Installing CustomApps..."
installed=0

# 1. Standalone .apk files → product/priv-app/<Name>/<Name>.apk
for apk in "$SRC"/*.apk; do
    [[ -e "$apk" ]] || continue
    name="$(basename "$apk" .apk)"
    mkdir -p "$PRIVAPP/$name"
    cp -f "$apk" "$PRIVAPP/$name/$name.apk"
    info "CustomApp (priv-app): $name"
    installed=$((installed + 1))
done

# 2. App folders (may contain lib/, other jars, etc.) → product/priv-app/<AppName>/
for appdir in "$SRC"/*/; do
    [[ -d "$appdir" ]] || continue
    base="$(basename "$appdir")"
    case "$base" in
        overlay|KaoriOS|OS1|OS2|OS3|Universal|UpdateFile) continue ;;
    esac
    # Skip if it's just an overlay/permissions holder
    if [[ -d "$appdir/lib" || -f "$appdir"/*.apk ]] 2>/dev/null; then
        mkdir -p "$PRIVAPP/$base"
        cp -rf "$appdir". "$PRIVAPP/$base/"
        info "CustomApp (folder): $base"
        installed=$((installed + 1))
    fi
done

# 3. Overlay APKs → product/overlay/
if [[ -d "$SRC/overlay" ]]; then
    for apk in "$SRC/overlay"/*.apk; do
        [[ -e "$apk" ]] || continue
        cp -f "$apk" "$OVERLAY/"
        info "CustomApp (overlay): $(basename "$apk")"
        installed=$((installed + 1))
    done
fi

# 4. privapp whitelist XMLs → product/etc/permissions/
for xml in "$SRC"/privapp_whitelist_*.xml; do
    [[ -e "$xml" ]] || continue
    cp -f "$xml" "$PERMS/"
    info "CustomApp (permission): $(basename "$xml")"
    installed=$((installed + 1))
done

if [[ $installed -eq 0 ]]; then
    info "CustomApps: nothing to install (folder empty)"
else
    mods "CustomApps: installed $installed item(s)"
fi
