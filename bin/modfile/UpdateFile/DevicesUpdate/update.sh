#!/usr/bin/env bash
# DevicesUpdate/update.sh — per-device mods.
# Runs for every build; each block is gated on the detected codename.
set -euo pipefail

work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images"
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

device_code=$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null || echo "")
regionTYPE=$(cat "$work_dir/bin/ddevice/device_type.txt" 2>/dev/null || echo "")
rom_os=$(cat "$work_dir/bin/ddevice/rom_os.txt" 2>/dev/null || echo "")
androidVER=$(cat "$work_dir/bin/ddevice/androidver.txt" 2>/dev/null || echo "")

mods "Device-specific mods for: ${device_code:-unknown} (rom_os=$rom_os, android=$androidVER)"

# --- spes (Redmi Note 10 Pro) ---------------------------------------------
if [[ "$device_code" == "spes" ]]; then
    mods "Add Dolby and Speaker Balance for SPES"
    SPES_DIR="$work_dir/bin/modfile/UpdateFile/DevicesUpdate/spes"
    if [[ -d "$SPES_DIR/sound" ]]; then
        [[ -f "$SPES_DIR/sound/mixer_paths.xml" ]] && \
            cp -f "$SPES_DIR/sound/mixer_paths.xml" "$MAIN_FOLDER/vendor/etc/mixer_paths.xml"
        [[ -d "$SPES_DIR/sound/dolby/system/app/Atmos" ]] && \
            cp -rf "$SPES_DIR/sound/dolby/system/app/Atmos" "$MAIN_FOLDER/system/system/app/"
        [[ -d "$SPES_DIR/sound/dolby/system/etc" ]] && \
            cp -rf "$SPES_DIR/sound/dolby/system/etc/." "$MAIN_FOLDER/system/system/etc/"
        [[ -d "$SPES_DIR/sound/dolby/system/vendor/etc" ]] && \
            cp -rf "$SPES_DIR/sound/dolby/system/vendor/etc/." "$MAIN_FOLDER/vendor/etc/"
        [[ -d "$SPES_DIR/sound/dolby/system/vendor/lib" ]] && \
            cp -rf "$SPES_DIR/sound/dolby/system/vendor/lib/." "$MAIN_FOLDER/vendor/lib/"
    fi
fi

# --- lisa (Xiaomi 11 Lite 5G NE) -----------------------------------------
if [[ "$device_code" == "lisa" ]]; then
    mods "Applying lisa device mods"
    LISA_DIR="$work_dir/bin/modfile/UpdateFile/DevicesUpdate/lisa"

    # 1. Region / feature unlock (if provided).
    if [[ -f "$LISA_DIR/mixer_paths.xml" && -d "$MAIN_FOLDER/vendor/etc" ]]; then
        cp -f "$LISA_DIR/mixer_paths.xml" "$MAIN_FOLDER/vendor/etc/mixer_paths.xml"
        info "lisa: updated mixer_paths.xml"
    fi

    # 2. Device-specific overlays → product/overlay/.
    if [[ -d "$LISA_DIR/overlay" && -d "$MAIN_FOLDER/product/overlay" ]]; then
        for oapk in "$LISA_DIR/overlay"/*.apk; do
            [[ -e "$oapk" ]] || continue
            cp -f "$oapk" "$MAIN_FOLDER/product/overlay/"
            info "lisa overlay: $(basename "$oapk")"
        done
    fi

    # 3. Device-specific prop tweaks.
    if [[ -d "$MAIN_FOLDER" ]]; then
        PROP_FILE=$(find "$MAIN_FOLDER" -name build.prop -path '*/system/*' 2>/dev/null | head -n1 || true)
        if [[ -n "$PROP_FILE" && -f "$PROP_FILE" ]]; then
            # Xiaomi 11 Lite 5G NE: enable AOD and disable low-end throttling.
            if ! grep -q '^ro.lisa.optimized=' "$PROP_FILE"; then
                {
                    echo "ro.lisa.optimized=true"
                    echo "ro.vendor.audio.soundfx.type=dolby"
                } >> "$PROP_FILE"
                info "lisa: added device props"
            fi
        fi
    fi

    # 4. Run any extra per-mod update.sh inside the lisa folder.
    if [[ -d "$LISA_DIR" ]]; then
        while IFS= read -r -d '' script; do
            base="$(basename "$script" .sh)"
            [[ "$base" == "update" ]] && continue
            if ! bash "$script"; then
                warn "lisa mod failed (continuing): $script"
            fi
        done < <(find "$LISA_DIR" -type f -name '*.sh' ! -name update.sh -print0 2>/dev/null || true)
    fi

    mods "lisa device mods done"
fi

mods "Device-specific mods done"
