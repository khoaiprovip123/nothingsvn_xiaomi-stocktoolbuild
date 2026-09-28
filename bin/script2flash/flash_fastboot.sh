#!/usr/bin/env bash
# flash_fastboot.sh — nạp ROM NothingsVN qua FASTBOOT (Linux/Mac).
# Dùng cho máy đã unlock bootloader, KHÔNG dùng recovery.
#
# Cách dùng:
#   1. Cài platform-tools (adb + fastboot)
#   2. Đưa máy vào chế độ FASTBOOT (tắt nguồn → giữ Giảm âm + Nguồn)
#   3. Chạy:  bash flash_fastboot.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMG_DIR="$SCRIPT_DIR/images"
SUPER_DIR="$SCRIPT_DIR/super"

echo ""
echo "============================================================"
echo "  NothingsVN ROM Flasher — FASTBOOT mode"
echo "============================================================"
echo ""

# 1. Kiểm tra fastboot
command -v fastboot >/dev/null 2>&1 || { echo "[LỖI] Không tìm thấy 'fastboot' trong PATH."; exit 1; }

# 2. Kiểm tra thiết bị
echo "[1/6] Kiểm tra kết nối fastboot..."
if ! fastboot devices | grep -q "fastboot"; then
    echo "[LỖI] Không thấy thiết bị fastboot."
    exit 1
fi
SERIAL=$(fastboot devices | head -n1 | awk '{print $1}')
echo "      Thiết bị: $SERIAL"

# 3. Kiểm tra file ROM
echo "[2/6] Kiểm tra file ROM..."
missing=0
for f in vbmeta boot dtbo; do
    if [[ -f "$IMG_DIR/$f.img" ]]; then
        echo "      [OK] images/$f.img"
    else
        echo "      [THIẾU] images/$f.img"; missing=1
    fi
done
if [[ -f "$SUPER_DIR/super.img" ]]; then
    echo "      [OK] super/super.img"
else
    echo "      [THIẾU] super/super.img"; missing=1
fi
[[ $missing -eq 0 ]] || { echo "[LỖI] Thiếu file ROM."; exit 1; }

# 4. Xác nhận
echo ""
echo "  CHÚ Ý:"
echo "    - Máy PHẢI đã unlock bootloader."
echo "    - Flash ROM sai máy có thể gây BRICK."
echo ""
read -r -p "Bạn có chắc muốn flash? (y/N): " CONFIRM
[[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || { echo "Đã hủy."; exit 0; }

# 5. Flash vbmeta (tắt xác minh)
echo ""
echo "[3/6] Flash vbmeta (disable verity + verification)..."
fastboot --disable-verity --disable-verification flash vbmeta "$IMG_DIR/vbmeta.img"
[[ -f "$IMG_DIR/vbmeta_system.img" ]] && \
    fastboot --disable-verity --disable-verification flash vbmeta_system "$IMG_DIR/vbmeta_system.img"

# 6. Flash firmware
echo "[4/6] Flash firmware..."
[[ -f "$IMG_DIR/boot.img" ]]         && fastboot flash boot "$IMG_DIR/boot.img"
[[ -f "$IMG_DIR/dtbo.img" ]]         && fastboot flash dtbo "$IMG_DIR/dtbo.img"
[[ -f "$IMG_DIR/vendor_boot.img" ]]  && fastboot flash vendor_boot "$IMG_DIR/vendor_boot.img"
[[ -f "$IMG_DIR/init_boot.img" ]]    && fastboot flash init_boot "$IMG_DIR/init_boot.img"

# 7. Flash super
echo "[5/6] Flash super (hệ thống)..."
if ! fastboot flash super "$SUPER_DIR/super.img"; then
    echo "[CẢNH BÁO] Flash super lỗi. Thử từ fastbootd:"
    echo "    fastboot reboot fastboot"
    echo "    fastboot flash super \"$SUPER_DIR/super.img\""
    echo "    fastboot reboot"
    exit 1
fi

# 8. Hoàn tất
echo "[6/6] Hoàn tất! Khởi động lại..."
fastboot reboot
echo ""
echo "============================================================"
echo "  Flash xong! Nếu bootloop: xem docs/BOOT_TROUBLESHOOTING.md"
echo "============================================================"
