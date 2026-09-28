# XiaomiAI — mở khóa tính năng AI / premium của Xiaomi

Mod này unlock các tính năng AI và premium của HyperOS 1 / HyperOS 2
(Android 14), với trọng tâm là máy **lisa** (Xiaomi 11 Lite 5G NE).

## Những gì được mở khóa

### AI engine (HyperOS)
- `ro.miui.ai.enabled`, `ro.vendor.ai.enabled`, `persist.sys.miui_ai`
- Xiao AI (trợ lý giọng nói)
- HyperOS 2 AI agent (`ro.hyperos.ai.agent`)

### AI apps
- AI Gallery (`ro.miui.gallery.ai`) — tẩy vật thể, chỉnh ảnh AI
- AI Notes (`ro.miui.notes.ai`) — tóm tắt, dịch
- AI Search (`ro.miui.search.ai`)
- AI eraser / translate / summary / subtitles / wallpaper

### Premium / flagship-only
- `ro.miui.premium`, `ro.product.premium`
- Dolby Atmos (`ro.vendor.audio.soundfx.type=dolby`)
- Full-screen AOD, advanced texture, high refresh rate
- Bỏ `low_ram` throttle (lisa vốn bị coi là mid-range)

### Camera AI (lisa / 64MP main)
- `vendor.camera.ai.enable`, `vendor.camera.feature.ai_sr`, `vendor.camera.feature.ai_nr`

### Google AI
- Gemini + CircleToSearchOverlay (mọi region, không chỉ Global)

### Cloud feature override
- `cloud_feature_config.xml` — ép server-side feature flags thành "on"

## Cấu trúc

```
XiaomiAI/
├── update.sh                          # script chính (tự chạy qua insupdate.sh)
├── overlay/                           # APK overlay → product/overlay/
└── config/
    ├── cloud_feature_config.xml       # feature flags override
    └── privapp_whitelist_xiaomi_ai.xml
```

## Tùy chỉnh

- Thêm overlay: bỏ `.apk` vào `XiaomiAI/overlay/`
- Thêm feature flag: sửa `config/cloud_feature_config.xml`
- Thêm prop: sửa `update.sh` (hàm `add_prop`)

## Chạy khi nào

Tự động chạy qua `bin/modfile/UpdateFile/insupdate.sh` khi `install_mods=true`.
Chạy cho **mọi device**, nhưng có thêm block riêng cho `lisa`.
