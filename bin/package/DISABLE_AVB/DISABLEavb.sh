#!/usr/bin/env bash
# DISABLEavb.sh — tắt Android Verified Boot cho ROM đã sửa.
#
# Tại sao phải làm đủ 3 bước:
#   1. Patch vbmeta*.img  → set flags=3 (disable-verity + disable-verification)
#   2. Strip cờ avb khỏi fstab (vendor + ramdisk vendor_boot)
#   3. Cập nhật cmdline vbmeta.digest trong vendor_boot
# Thiếu bất kỳ bước nào → bootloader vẫn verify hash của partition đã sửa → KHÔNG BOOT.
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

device_code=$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null || echo "")
IMG="$work_dir/build/baserom/images"
AVB_LIST="$work_dir/bin/package/DISABLE_AVB/avb_list.txt"

# Luôn luôn patch vbmeta (cả device trong list lẫn ngoài list) — đây là bước bắt buộc.
patch_all_vbmeta() {
    local img
    for img in "$IMG"/vbmeta*.img; do
        [[ -f "$img" ]] || continue
        python3 "$work_dir/bin/patch-vbmeta.py" "$img" >/dev/null 2>&1 \
            && info "Patched vbmeta: $(basename "$img")" \
            || warn "Could not patch vbmeta: $(basename "$img")"
    done
}

if grep -qw "$device_code" "$AVB_LIST"; then
    mods "Disabling AVB (device '$device_code' in avb_list)"

    # 1. Strip cờ avb khỏi fstab trong vendor.
    disable_avb_verify "$IMG/vendor" >/dev/null 2>&1

    # 2. Patch vbmeta*.img — LUÔN chạy, không phụ thuộc cấu trúc ramdisk.
    patch_all_vbmeta

    # 3. Patch vendor_boot: fstab trong ramdisk + cmdline digest.
    if [ -f "$IMG/vendor_boot.img" ]; then
        mkdir -p "$work_dir/build/baserom/boot"
        python3 "$work_dir/bin/vbpatcher.py" unpack -i "$IMG/vendor_boot.img" -o "$work_dir/build/baserom/boot"

        # Cập nhật cmdline vbmeta.digest nếu đã patch vbmeta ở trên.
        if [ -f "$IMG/vbmeta.img" ]; then
            vbmeta_digest=$(sha256sum "$IMG/vbmeta.img" | cut -d ' ' -f1)
            vbmeta_size=$(stat -c%s "$IMG/vbmeta.img")
            if [ -f "$work_dir/build/baserom/boot/config.json" ]; then
                jq ".cmdline = \"androidboot.vbmeta.digest=$vbmeta_digest androidboot.vbmeta.avb_version=1.3 androidboot.vbmeta.size=$vbmeta_size androidboot.vbmeta.hash_alg=sha256 \" + .cmdline" \
                    "$work_dir/build/baserom/boot/config.json" \
                    > "$work_dir/build/baserom/boot/config.bak" \
                    && mv -f "$work_dir/build/baserom/boot/config.bak" "$work_dir/build/baserom/boot/config.json" \
                    && info "Updated vendor_boot cmdline vbmeta.digest"
            fi
        fi

        # Strip cờ avb trong fstab của ramdisk (dùng hàm đã fix, KHÔNG dùng sed cắt một phần).
        disable_avb_verify "$work_dir/build/baserom/boot" >/dev/null 2>&1

        # Repack vendor_boot.
        if python3 "$work_dir/bin/vbpatcher.py" repack -c "$work_dir/build/baserom/boot/config.json" -o "$IMG/vendor_boot.img" >/dev/null 2>&1; then
            rm -rf "$work_dir/build/baserom/boot"
            info "Patched vendor_boot.img"
        else
            error "Cannot repack vendor_boot.img"
        fi
    else
        warn "vendor_boot.img not found — skipping ramdisk fstab/cmdline patch"
    fi
else
    # Device ngoài list: vẫn patch vbmeta + strip fstab vendor để chắc ăn.
    mods "Disabling AVB (device '$device_code' NOT in avb_list — minimal path)"
    patch_all_vbmeta
    disable_avb_verify "$IMG/vendor" >/dev/null 2>&1
fi

mods "AVB disable done"
