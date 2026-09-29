# Mod layout — KTOS Xiaomi Stock Toolbuild

```
bin/modfile/
├── Universal/            # always-on (GApps, keyboard, package installer)
│   └── insfile.sh
├── UpdateFile/           # version / feature mods, dispatched by insupdate.sh
│   ├── OS1/              # HyperOS 1 only  (rom_os == OS1)
│   │   └── update.sh
│   ├── OS2/              # HyperOS 2 only  (rom_os == OS2)
│   │   └── update.sh
│   ├── DevicesUpdate/    # per-device mods
│   │   ├── lisa/         # Xiaomi 11 Lite 5G NE
│   │   ├── spes/         # Redmi Note 10 Pro
│   │   └── update.sh
│   └── …                 # Global, Fonts, MultiLang, Settings_*, SystemUI_* …
├── CustomApps/           # user APKs → product/priv-app, overlay, permissions
│   └── inscustom.sh
└── KaoriOS/              # KaoriOS Toolbox (xeutoolbox)
    └── install.sh
```

## Feature flags (`config.env`)

| Flag | Default | Effect |
|---|---|---|
| `install_toolbox` | `true` | Install KaoriOS Toolbox (`system_ext/xbin/xeutoolbox`) |
| `install_mods` | `true` | Master switch for Universal / UpdateFile / CustomApps / KaoriOS / package patches |
| `install_custom_apps` | `true` | Install APKs from `CustomApps/` |
| `target_device` | `lisa` | Documentation / filter hint (device mods self-detect via `device_f.txt`) |
| `target_os` | `OS1,OS2` | Documentation / filter hint (OS mods self-detect via `rom_os.txt`) |

## Supported targets

- **Android 14** builds of **HyperOS 1** (`rom_os=OS1`) and **HyperOS 2** (`rom_os=OS2`)
- Primary device: **lisa** (Xiaomi 11 Lite 5G NE)
- Other devices fall through to Universal + UpdateFile mods

## Adding a new device mod

1. Create `bin/modfile/UpdateFile/DevicesUpdate/<codename>/`
2. Put payload files / `update.sh` in it
3. Add a `[[ "$device_code" == "<codename>" ]]` block in `DevicesUpdate/update.sh`
