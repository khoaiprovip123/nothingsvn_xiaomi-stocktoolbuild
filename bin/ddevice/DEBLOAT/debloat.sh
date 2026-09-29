#!/usr/bin/env bash
# debloat.sh — gỡ app theo APPLIST.txt.
#
# FIX QUAN TRỌNG: PHẢI lọc dòng trống/comment. Dòng trống → debloat_app=""
# → find -name "**" khớp CẢ thư mục gốc → rm -rf xóa SẠCH cả partition
# (system/product/mi_ext) → ROM mất hệ thống, không boot.
set -euo pipefail

WORK_DIR=$(pwd)
source "$WORK_DIR/functions.sh"

APPLIST="$WORK_DIR/bin/ddevice/DEBLOAT/APPLIST.txt"
IMAGE_ROOT="$WORK_DIR/build/baserom/images"

# Dọn file lẻ (không phải app).
rm -rf "$IMAGE_ROOT/product/etc/auto-install"* 2>/dev/null || true
rm -rf "$IMAGE_ROOT/product/app/Updater" 2>/dev/null || true
rm -rf "$IMAGE_ROOT/product/etc/permissions/cn.google.services.xml" 2>/dev/null || true

# Đọc APPLIST — BỎ QUA dòng trống, comment, và entry quá ngắn (nguy hiểm).
debloat_apps=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"                       # bỏ comment
    line="${line//[[:space:]]/}"             # bỏ khoảng trắng
    [[ -z "$line" ]] && continue             # BỎ dòng trống
    [[ ${#line} -lt 3 ]] && continue         # BỎ entry quá ngắn (tránh khớp rộng)
    debloat_apps+=("$line")
done < "$APPLIST"

info "Debloat: ${#debloat_apps[@]} app sẽ gỡ"

for debloat_app in "${debloat_apps[@]}"; do
    for part_dir in "$IMAGE_ROOT/system" "$IMAGE_ROOT/product" "$IMAGE_ROOT/mi_ext"; do
        [[ -d "$part_dir" ]] || continue
        # -print0 an toàn với khoảng trắng; CHỈ xóa thư mục app, KHÔNG bao giờ xóa gốc.
        while IFS= read -r -d '' app_dir; do
            # Chặn xóa thư mục gốc partition (chỉ xóa thư mục CON).
            [[ "$app_dir" == "$part_dir" ]] && continue
            [[ "$app_dir" == "$IMAGE_ROOT" ]] && continue
            if [[ -d "$app_dir" ]]; then
                info "Removing directory: $app_dir"
                rm -rf "$app_dir"
            fi
        done < <(find "$part_dir" -mindepth 1 -type d -name "*${debloat_app}*" -print0 2>/dev/null)
    done
done

info "Debloat Done"
