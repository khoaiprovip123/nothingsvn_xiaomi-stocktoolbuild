# Hướng dẫn xử lý khi ROM không boot (cho máy lisa / Xiaomi)

Tài liệu này dành cho **khi build ROM xong mà máy không khởi động được**.
Làm đúng thứ tự bên dưới → lấy đủ log → gửi cho người build để chẩn đoán **chính xác**, thay vì đoán.

---

## 0. Trước khi flash — CHUẨN BỊ (làm 1 lần)

| Việc | Cách |
|---|---|
| **Tải sẵn ROM stock (fastboot) của lisa** | Xiaomi official / MiFlash — để khi bootloop flash lại trong 5 phút |
| **Unlock bootloader** | Bắt buộc với ROM mod |
| **Có recovery tùy chỉnh** (TWRP/OrangeFox) nếu được | Để backup/restore partition |
| **Bật USB Debugging + OEM Unlock** | Trong Developer options |
| **Cài adb + fastboot** trên máy tính | Platform-tools của Google |

> ⚠️ Flash ROM mod = rủi ro brick. **Không** flash trên máy duy nhất nếu chưa có ROM stock.

---

## 1. Máy rơi vào trạng thái nào?

Chọn đúng triệu chứng → làm theo nhánh đó:

```
Flash ROM xong
   │
   ├─► Treo logo Xiaomi / HyperOS, không vào được
   │        → Xem mục 2 (thu log từ recovery / pstore)
   │
   ├─► Vào thẳng TWRP / recovery, không boot system
   │        → Xem mục 2 + mục 4 (backup log từ recovery)
   │
   ├─► Vào thẳng fastboot / bootloader
   │        → Xem mục 3 (fastboot getvar)
   │
   ├─► Boot được nhưng crash / treo sau vài giây
   │        → Xem mục 5 (adb logcat)
   │
   └─► Boot bình thường, chỉ lỗi tính năng
            → Xem mục 5 (adb logcat theo tính năng)
```

---

## 2. Treo logo / bootloop → lấy `console-ramoops` (quan trọng nhất)

File này chứa **log kernel lần boot trước** — là dữ liệu chẩn đoán giá trị nhất.

### Cách A: Vào recovery (TWRP) rồi lấy

```bash
# Kết nối máy với PC, vào TWRP, bật ADB
adb shell ls /sys/fs/pstore/
# Nếu thấy console-ramoops-0 → kéo về PC:
adb pull /sys/fs/pstore/console-ramoops-0 ramoops.txt
adb pull /sys/fs/pstore/console-ramoops-0.dmesg dmesg.txt   # nếu có
```

### Cách B: Dùng `fastboot boot` recovery tạm (nếu không vào được TWRP)

```bash
fastboot boot twrp.img
# rồi làm như Cách A
```

### Cách C: Qua OrangeFox / PitchBlack — mục File Manager → copy file ra OTG/USB

---

## 3. Vào thẳng fastboot → lấy thông tin bootloader

```bash
fastboot getvar all > fastboot_info.txt 2>&1
fastboot oem device-info > device_info.txt 2>&1   # nếu hỗ trợ
```

Ghi thêm bằng tay: **đè nút nguồn bao lâu, hiện gì trên màn hình**.

---

## 4. Backup partition từ recovery (trước khi thử lại)

```bash
# Trên TWRP: Backup → chọn Boot, Vbmeta, Super → kéo về PC
adb pull /sdcard/TWRP/BACKUPS/ ./rom_backup/
```

---

## 5. Boot được nhưng crash / lỗi → `adb logcat`

```bash
# Toàn bộ log
adb logcat -b all -d > logcat_full.txt

# Chỉ kernel (hay nhất cho lỗi boot/panic)
adb shell dmesg > dmesg_current.txt

# Log lúc crash (nếu crash rồi tự reset)
adb logcat -b crash -d > logcat_crash.txt

# Theo dõi realtime khi tái hiện lỗi
adb logcat > logcat_live.txt
```

---

## 6. Ghi rõ thông tin kèm theo (BẮT BUỘC)

Khi gửi log, đính kèm các thông tin này:

```
- Tên file ROM đã flash:  ____________________
- Nguồn ROM gốc:          ____________________
- Máy:                    lisa (Xiaomi 11 Lite 5G NE)
- Android / HyperOS:      ________
- Đã unlock bootloader?   Có / Không
- Flash bằng gì?          TWRP / fastboot / MiFlash / khác
- Triệu chứng:           [treo logo / vào recovery / vào fastboot / crash sau X giây]
- Lần đầu hay đã thử lại? ____________________
```

---

## 7. Gói log gửi đi

Nén thành 1 file zip gồm:

```
logs_lisa_<ngay>/
├── ramoops.txt            (mục 2)
├── dmesg_current.txt      (mục 5)
├── logcat_full.txt        (mục 5)
├── logcat_crash.txt       (mục 5)
├── fastboot_info.txt      (mục 3)
├── BUILD_INFO.txt         (có sẵn trong ROM zip)
└── notes.txt              (mục 6)
```

```bash
zip -r logs_lisa_$(date +%Y%m%d).zip logs_lisa_*/
```

---

## 8. Cách khôi phục khi brick (cứu máy)

| Tình trạng | Cách cứu |
|---|---|
| Treo logo, vào được fastboot | `fastboot flash` lại ROM stock (boot, vbmeta, super) |
| Vào được TWRP | Restore backup (mục 4), hoặc flash ROM stock qua sideload |
| Không vào được gì (hard brick hiếm) | Chế độ EDL (9008) + MiFlash — cần auth, mang ra hàng |
| Vào recovery nhưng không thấy partition | Kiểm tra super.img có tràn không (log sẽ báo `PARTITION OVERFLOW`) |

---

## Lưu ý an toàn

- **Không** relock bootloader khi đang dùng ROM mod.
- **Không** flash ROM của máy khác (sai `super_size` → brick).
- Giữ **≥2GB trống** trước khi flash (super giải nén cần chỗ).
- Nếu log báo `PARTITION OVERFLOW` → ROM quá đầy, cần giảm APK mod.
