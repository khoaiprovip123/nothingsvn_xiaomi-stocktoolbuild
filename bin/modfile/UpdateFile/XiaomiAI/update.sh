#!/usr/bin/env bash
# XiaomiAI/update.sh — unlock Xiaomi premium & AI features (HyperOS 1/2, Android 14).
#
# Unlocks:
#   • HyperOS AI engine (Xiao AI, AI Gallery, AI Notes, AI Search)
#   • Premium / flagship-only feature flags
#   • Cloud feature config overrides
#   • Device capability props for lisa (Xiaomi 11 Lite 5G NE)
#
# Works for both rom_os=OS1 and OS2. All steps are best-effort.
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

IMAGE_ROOT="$work_dir/build/baserom/images"
MOD_DIR="$work_dir/bin/modfile/UpdateFile/XiaomiAI"

device_code=$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null || echo "")
rom_os=$(cat "$work_dir/bin/ddevice/rom_os.txt" 2>/dev/null || echo "")
androidVER=$(cat "$work_dir/bin/ddevice/androidver.txt" 2>/dev/null || echo "")
regionTYPE=$(cat "$work_dir/bin/ddevice/device_type.txt" 2>/dev/null || echo "")

mods "Unlocking Xiaomi AI / Premium features (device=$device_code, $rom_os, Android $androidVER, region=$regionTYPE)"

[[ -d "$IMAGE_ROOT" ]] || { warn "No image root — XiaomiAI skipped"; exit 0; }

# ---------- helpers -------------------------------------------------------

# Ghi prop vào build.prop của MỘT nhóm partition cụ thể (system/product/system_ext).
# Không đụng vendor — vendor HAL đọc build.prop riêng, ghi đè sẽ phá audio/camera.
add_sys_prop() {
    local key="$1" value="$2"
    local f
    while IFS= read -r -d '' f; do
        if grep -q "^${key}=" "$f" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${value}|" "$f"
        else
            echo "${key}=${value}" >> "$f"
        fi
    done < <(find "$IMAGE_ROOT" -type f -name build.prop \
                 \( -path '*/system/*' -o -path '*/product/*' -o -path '*/system_ext/*' \) \
                 -print0 2>/dev/null || true)
}

# Ghi prop vào vendor build.prop (chỉ cho prop thực sự thuộc vendor HAL).
add_vendor_prop() {
    local key="$1" value="$2"
    local f
    while IFS= read -r -d '' f; do
        if grep -q "^${key}=" "$f" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${value}|" "$f"
        else
            echo "${key}=${value}" >> "$f"
        fi
    done < <(find "$IMAGE_ROOT" -type f -name build.prop \
                 -path '*/vendor/*' -print0 2>/dev/null || true)
}

# ---------- 1. HyperOS AI engine flags (system/product) --------------------
add_sys_prop "ro.miui.ai.enabled"                 "1"
add_sys_prop "persist.sys.miui_ai"                "1"
add_sys_prop "ro.mi.feature.ai"                   "true"
add_sys_prop "ro.xiaomi.ai.support"               "1"

# AI Gallery / AI Notes / AI Search (HyperOS 1 & 2).
add_sys_prop "ro.miui.gallery.ai"                 "1"
add_sys_prop "ro.miui.notes.ai"                   "1"
add_sys_prop "ro.miui.search.ai"                  "1"
add_sys_prop "persist.sys.ai_gallery"             "1"
add_sys_prop "persist.sys.ai_notes"               "1"

# HyperOS 2 AI agent (only meaningful on OS2, harmless on OS1).
add_sys_prop "ro.hyperos.ai.agent"                "1"
add_sys_prop "persist.sys.hyperos_ai"             "1"

# ---------- 2. Premium / flagship feature unlock (system/product) ----------
add_sys_prop "ro.miui.premium"                    "1"
add_sys_prop "ro.product.premium"                 "1"
add_sys_prop "persist.sys.highend"                "1"
add_sys_prop "ro.config.low_ram"                  "false"
add_sys_prop "ro.config.low_ram_default"          "false"
add_sys_prop "ro.lmk.low_ram"                     "false"

# Display / motion (Xiaomi 11 Lite 5G NE has a 90 Hz panel) — surface_flinger đọc system prop.
add_sys_prop "ro.surface_flinger.supports_background_blur" "1"
add_sys_prop "ro.surface_flinger.has_wide_color_display"   "1"
add_sys_prop "ro.surface_flinger.has_HDR_display"          "1"

# ---------- 2b. Vendor HAL props (CHỈ vào vendor build.prop) ---------------
add_vendor_prop "ro.vendor.ai.enabled"            "1"
add_vendor_prop "ro.vendor.audio.soundfx.type"    "dolby"
add_vendor_prop "ro.vendor.audio.feature.ahal"    "1"

# ---------- 3. Cloud feature config ---------------------------------------
# Xiaomi gates features server-side via cloud_feature_config. The override
# file forces the AI/premium features to "on" regardless of region.
CLOUD_DIR="$IMAGE_ROOT/product/etc/device_features"
if [[ ! -d "$CLOUD_DIR" ]]; then
    CLOUD_DIR="$IMAGE_ROOT/system/etc/device_features"
fi
mkdir -p "$CLOUD_DIR"
if [[ -f "$MOD_DIR/config/cloud_feature_config.xml" ]]; then
    cp -f "$MOD_DIR/config/cloud_feature_config.xml" "$CLOUD_DIR/"
    info "Installed cloud_feature_config.xml override"
fi

# Feature XML used by MIUIFeature / SystemUI plugin.
FEAT_DIR="$IMAGE_ROOT/product/etc/permissions"
mkdir -p "$FEAT_DIR"
if [[ -f "$MOD_DIR/config/privapp_whitelist_xiaomi_ai.xml" ]]; then
    cp -f "$MOD_DIR/config/privapp_whitelist_xiaomi_ai.xml" "$FEAT_DIR/"
    info "Installed privapp_whitelist_xiaomi_ai.xml"
fi

# ---------- 4. Overlays ---------------------------------------------------
if [[ -d "$MOD_DIR/overlay" ]]; then
    for oapk in "$MOD_DIR/overlay"/*.apk; do
        [[ -e "$oapk" ]] || continue
        mkdir -p "$IMAGE_ROOT/product/overlay"
        cp -f "$oapk" "$IMAGE_ROOT/product/overlay/"
        info "XiaomiAI overlay: $(basename "$oapk")"
    done
fi

# ---------- 5. Google AI (Gemini / Circle to Search) -----------------------
# The Global/China mods already ship these per-region; also install them here
# so lisa gets Google AI regardless of the detected region.
GLOBAL_DIR="$work_dir/bin/modfile/UpdateFile/Global"
if [[ -d "$GLOBAL_DIR/Gemini" ]]; then
    mkdir -p "$IMAGE_ROOT/product/priv-app"
    cp -rf "$GLOBAL_DIR/Gemini" "$IMAGE_ROOT/product/priv-app/" 2>/dev/null || true
    info "XiaomiAI: installed Gemini"
fi
if [[ -f "$GLOBAL_DIR/CircleToSearchOverlay.apk" ]]; then
    mkdir -p "$IMAGE_ROOT/product/overlay"
    cp -f "$GLOBAL_DIR/CircleToSearchOverlay.apk" "$IMAGE_ROOT/product/overlay/" 2>/dev/null || true
    info "XiaomiAI: installed CircleToSearchOverlay"
fi

# ---------- 6. lisa-specific premium tweaks -------------------------------
if [[ "$device_code" == "lisa" ]]; then
    mods "XiaomiAI: lisa-specific premium tweaks"
    # 11 Lite 5G NE has its 64MP main sensor — enable the AI camera HAL features (vendor props).
    add_vendor_prop "vendor.camera.ai.enable"        "1"
    add_vendor_prop "persist.vendor.camera.ai"       "1"
    # Enable Super Resolution / AI denoise typically reserved for flagships.
    add_vendor_prop "vendor.camera.feature.ai_sr"    "1"
    add_vendor_prop "vendor.camera.feature.ai_nr"    "1"
fi

mods "Xiaomi AI / Premium unlock done"
