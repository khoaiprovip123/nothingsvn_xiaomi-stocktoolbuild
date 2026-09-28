#!/usr/bin/env bash
# OS2/update.sh — HyperOS 2 (Android 14/15) specific mods for lisa and friends.
#
# Only runs when rom_os.txt == OS2. Each subfolder with an update.sh is
# executed as a best-effort mod.
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

rom_os=$(cat "$work_dir/bin/ddevice/rom_os.txt" 2>/dev/null || echo "")
androidVER=$(cat "$work_dir/bin/ddevice/androidver.txt" 2>/dev/null || echo "")
device_code=$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null || echo "")

if [[ "$rom_os" != "OS2" ]]; then
    info "OS2 mods: skipped (rom_os=$rom_os)"
    exit 0
fi

mods "Applying HyperOS 2 mods (Android ${androidVER:-?}, device=${device_code:-?})"

# --- HyperOS 2 / Android 14+ adjustments ----------------------------------

# 1. Ensure build.prop advertises the expected HyperOS version props.
IMAGE_ROOT="$work_dir/build/baserom/images"
if [[ -d "$IMAGE_ROOT" ]]; then
    PROP_FILE=$(find "$IMAGE_ROOT" -name build.prop -path '*/system/*' 2>/dev/null | head -n1 || true)
    if [[ -n "$PROP_FILE" && -f "$PROP_FILE" ]]; then
        if ! grep -q '^ro.hyperos.version.name=' "$PROP_FILE"; then
            echo "ro.hyperos.version.name=OS2.0" >> "$PROP_FILE"
            info "OS2: added ro.hyperos.version.name"
        fi
    fi
fi

# 2. Run any per-mod update.sh living in this folder.
OS2_DIR="$work_dir/bin/modfile/UpdateFile/OS2"
if [[ -d "$OS2_DIR" ]]; then
    while IFS= read -r -d '' script; do
        base="$(basename "$script" .sh)"
        [[ "$base" == "update" ]] && continue
        if ! bash "$script"; then
            warn "OS2 mod failed (continuing): $script"
        fi
    done < <(find "$OS2_DIR" -mindepth 2 -type f -name '*.sh' -print0 2>/dev/null || true)
fi

mods "HyperOS 2 mods done"
