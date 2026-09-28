#!/usr/bin/env bash
# build.sh — download / unpack / modify a Xiaomi stock ROM.
# Usage: bash build.sh <URL_OR_PATH_TO_ROM.zip> [repo_name] [prefix_id] [builder_name] [builder_id]
set -euo pipefail

baserom="${1:?Usage: bash build.sh <URL_OR_PATH_TO_ROM.zip> [repo_name] [prefix_id] [builder_name] [builder_id]}"
repo_name="${2:-}"
prefix_id="${3:-}"
export builder_name="${4:-}"
builder_id="${5:-}"

work_dir=$(pwd)
export WORK_DIR="$work_dir"

# Prebuilt tools live under bin/$(uname)/$(uname -m)/ (Linux/x86_64 on CI).
tools_dir="${work_dir}/bin/$(uname)/$(uname -m)"
export PATH="${tools_dir}:${PATH}"

# Only need execute bits — never chmod 777.
chmod +x "${tools_dir}"/* 2>/dev/null || true
chmod +x "${work_dir}/bin"/* 2>/dev/null || true

# shellcheck source=functions.sh
source "${work_dir}/functions.sh"

if [[ "$(git branch --show-current 2>/dev/null || true)" == "beta" ]]; then
    polyxver="$(cat Version)"
    status="Development"
else
    polyxver="$(cat Version)"
    status="Official"
fi

check unzip aria2c 7z zip java zipalign python3 zstd bc xmlstarlet aapt

rm -rf "$work_dir/out" "$work_dir/build"

python3 "$work_dir/notify.py" download "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"
# shellcheck source=bin/ddevice/getROM.sh
source "$work_dir/bin/ddevice/getROM.sh" "$baserom"

python3 "$work_dir/notify.py" unpack "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"
# Detect ROM format from the zip listing.
baserom_type=""
is_base_rom_eu=false
if unzip -l "${baserom}" | grep -q "payload.bin"; then
    baserom_type="payload"
    printf '%s\n' "$baserom_type" > "$work_dir/bin/ddevice/romtype.txt"
    unpack "Found payload.bin file"
    super_list="vendor mi_ext odm odm_dlkm system system_dlkm vendor_dlkm product product_dlkm system_ext mi_product"
    unpack "ROM validation passed."
elif unzip -l "${baserom}" | grep -q "br$"; then
    baserom_type="br"
    printf '%s\n' "$baserom_type" > "$work_dir/bin/ddevice/romtype.txt"
    super_list="system vendor product odm system_ext mi_ext"
    unpack "Found broli file"
    unpack "ROM validation passed."
elif unzip -l "${baserom}" | grep -q "images/super.img*"; then
    unpack "Found super.img.* files"
    is_base_rom_eu=true
    unpack "ROM validation passed."
else
    die "Unpack failed"
fi

rm -rf app tmp config build/baserom/
# -print0 + xargs -0 -r: safe with spaces and a no-op when nothing matches.
find . -type d -name 'miui_*' -print0 | xargs -0 -r rm -rf

unpack "Files cleaned up."
mkdir -p build/baserom/images/

# Extract partitions
if [[ ${baserom_type} == 'payload' ]]; then
    unpack "Extracting files payload.bin..."
    unzip "${baserom}" payload.bin -d build/baserom >/dev/null 2>&1 || die "Extracting payload.bin error"
    unpack "File payload.bin extracted."
elif [[ ${baserom_type} == 'br' ]]; then
    unpack "Extracting files *.new.dat.br"
    unzip "${baserom}" -d build/baserom >/dev/null 2>&1 || die "Extracting new.dat.br error"
    unpack "File new.dat.br extracted."
elif [[ ${is_base_rom_eu} == true ]]; then
    unpack "Extracting files from BASEROM [super.img]"
    unzip "${baserom}" 'images/*' -d build/baserom >/dev/null 2>&1 || die "Extracting [super.img] error"
    unpack "Merging super.img.* into super.img"
    simg2img build/baserom/images/super.img.* build/baserom/images/super.img
    rm -f build/baserom/images/super.img.*
    mv build/baserom/images/super.img build/baserom/super.img
    unpack "[super.img] extracted."
    if [[ -f build/baserom/images/cust.img.0 ]]; then
        simg2img build/baserom/images/cust.img.* build/baserom/images/cust.img
        rm -f build/baserom/images/cust.img.*
    fi
fi

if [[ ${baserom_type} == 'payload' ]]; then
    unpack "Unpacking payload.bin"
    payload-extract extract -o build/baserom/images/ build/baserom/payload.bin >/dev/null 2>&1 || die "Unpacking payload.bin failed"
elif [[ ${baserom_type} == 'br' ]]; then
    super_list=$(grep "add " build/baserom/dynamic_partitions_op_list | awk '{ print $2 }')
    unpack "Unpacking new.dat.br"
    for brotlipart in ${super_list}; do
        brotli -d "build/baserom/${brotlipart}.new.dat.br" >/dev/null 2>&1
        python3 "${work_dir}/bin/Linux/x86_64/sdat2img.py" \
            "build/baserom/${brotlipart}.transfer.list" \
            "build/baserom/${brotlipart}.new.dat" \
            "build/baserom/images/${brotlipart}.img" >/dev/null 2>&1
        rm -f "build/baserom/${brotlipart}.new.dat"* "build/baserom/${brotlipart}.transfer.list" "build/baserom/${brotlipart}.patch."*
    done
elif [[ ${is_base_rom_eu} == true ]]; then
    unpack "Unpacking BASEROM [super.img]"
    super_list=$(python3 bin/lpunpack.py --info build/baserom/super.img | grep "super:" | awk '{ print $5 }')
    for i in ${super_list}; do
        if [[ $i == *_a ]]; then
            i=${i%_a}
            python3 bin/lpunpack.py -p "${i}_a" build/baserom/super.img build/baserom/images >/dev/null 2>&1
            mv "build/baserom/images/${i}_a.img" "build/baserom/images/${i}.img"
        else
            python3 bin/lpunpack.py -p "${i}" build/baserom/super.img build/baserom/images >/dev/null 2>&1
        fi
    done
    super_list=${super_list//_a/}
fi

for part in ${super_list}; do
    extract_partition "${work_dir}/build/baserom/images/${part}.img" "${work_dir}/build/baserom/images"
    PACK_TYPE=$(cat "${work_dir}/bin/ddevice/fstype.txt")
done
printf '%s\n' "${device_f:-}" > "$work_dir/bin/ddevice/device_f.txt"

# Ghi metadata cho recovery flasher (update-binary đọc từ META-INF/Data/).
# Trước đây ghi META-INF/CNAME trong khi update-binary đọc META-INF/Data/CNAME → sai đường dẫn.
META_DATA="$work_dir/bin/script2flash/META-INF/Data"
mkdir -p "$META_DATA"
printf '%s\n' "${device_f:-}" > "$META_DATA/CNAME"

# A = cấu trúc partition: VAB (virtual A/B) hay A-only.
structure="A-only"
if [[ -f "$work_dir/build/baserom/images/vendor/build.prop" ]] \
    && grep -q "ro.build.ab_update=true" "$work_dir/build/baserom/images/vendor/build.prop" 2>/dev/null; then
    structure="VAB"
fi
printf '%s\n' "$structure" > "$META_DATA/A"

# Chip = chipset (update-binary chỉ cho phép Qualcomm/Snapdragon).
chip_hint="qcom"
if [[ -f "$work_dir/build/baserom/images/vendor/build.prop" ]]; then
    board=$(grep -E '^ro\.board\.platform=' "$work_dir/build/baserom/images/vendor/build.prop" 2>/dev/null | head -n1 | cut -d= -f2)
    hw=$(grep -E '^ro\.hardware=' "$work_dir/build/baserom/images/vendor/build.prop" 2>/dev/null | head -n1 | cut -d= -f2)
    chip_hint="${board:-qcom} ${hw:-}"
fi
printf '%s\n' "$chip_hint" > "$META_DATA/Chip"

getvar=$(cat "$work_dir/bin/ddevice/device_f.txt")

rm -rf config

# Drop a leftover local zip with the same basename as the source ROM, if any.
if [ -f "${work_dir}/${baserom}.zip" ]; then
    rm -f "${baserom}.zip"
fi

rm -f build/baserom/payload.bin build/baserom/images/super.img

mods "Gathering Devices Infomations"

bash "$work_dir/bin/ddevice/fetchINFO.sh"

# Gửi thông báo đang Build với đầy đủ Codename và Version
python3 "$work_dir/notify.py" build "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"

bash "$work_dir/bin/ddevice/DEBLOAT/debloat.sh"
info "Done"

# --- Feature flags from config.env ----------------------------------------
# Pre-set environment variables always win; config.env only supplies defaults
# for flags that are not already exported.
load_config_defaults() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    local key value
    while IFS='=' read -r key value; do
        # Strip comments and whitespace
        key="${key%%#*}"; key="${key//[[:space:]]/}"
        value="${value%%#*}"; value="${value//[[:space:]]/}"
        [[ -z "$key" || -z "$value" ]] && continue
        # Skip if already set in the environment
        if [[ -z "${!key+x}" ]]; then
            export "$key=$value"
        fi
    done < "$file"
}
load_config_defaults "$work_dir/config.env"

: "${install_toolbox:=true}"
: "${install_mods:=true}"
: "${install_custom_apps:=true}"
export install_toolbox install_mods install_custom_apps
info "Config: install_toolbox=$install_toolbox install_mods=$install_mods install_custom_apps=$install_custom_apps target_device=${target_device:-all} target_os=${target_os:-auto}"

# --- Mods -----------------------------------------------------------------
# install_mods=false turns off the whole mod pipeline except debloat.
if [[ "${install_mods:-true}" == "true" ]]; then
    bash "$work_dir/bin/modfile/Universal/insfile.sh"
    bash "$work_dir/bin/modfile/UpdateFile/insupdate.sh"     # includes OS1/OS2 + DevicesUpdate
    bash "$work_dir/bin/modfile/CustomApps/inscustom.sh"
    bash "$work_dir/bin/modfile/KaoriOS/install.sh"          # gated by install_toolbox
    bash "$work_dir/bin/package/patchpackage.sh"
else
    info "install_mods=false — skipping Universal / UpdateFile / CustomApps / KaoriOS / package patches"
fi

find "$work_dir/build/baserom/images/" -exec touch -t 200901010000.00 {} + 2>/dev/null || true

