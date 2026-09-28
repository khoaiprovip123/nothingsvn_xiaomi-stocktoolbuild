#!/usr/bin/env bash
# packROM.sh — rebuild partition images and pack them into super.img.
# Run after build.sh has finished modifying build/baserom/images/.
set -euo pipefail

work_dir=$(pwd)
export WORK_DIR="$work_dir"

tools_dir="${work_dir}/bin/$(uname)/$(uname -m)"
export PATH="${tools_dir}:${PATH}"
chmod +x "${tools_dir}"/* 2>/dev/null || true

# shellcheck source=functions.sh
source "$work_dir/functions.sh"

# Phải khớp với super_list trong build.sh (payload path) — thiếu partition ở đây
# nghĩa là partition được extract nhưng KHÔNG được pack lại vào super.img → boot fail.
super_list="vendor mi_ext odm odm_dlkm system system_dlkm vendor_dlkm product product_dlkm system_ext mi_product"
os_type=$(cat "$work_dir/bin/ddevice/os_type.txt")
base_rom_code=$(cat "$work_dir/bin/ddevice/base_rom_code.txt")
androidVER=$(cat "$work_dir/bin/ddevice/androidver.txt")
rom_os=$(cat "$work_dir/bin/ddevice/rom_os.txt")
regionTYPE=$(cat "$work_dir/bin/ddevice/device_type.txt")
device_code=$(cat "$work_dir/bin/ddevice/device_f.txt")
getvar=$(cat "$work_dir/bin/ddevice/device_f.txt")
PACK_TYPE=$(cat "$work_dir/bin/ddevice/fstype.txt")

if [[ "$(git branch --show-current 2>/dev/null || true)" == "beta" ]]; then
    polyxver="$(cat Version)"
    status="Development"
else
    polyxver="$(cat Version)"
    status="Official"
fi

if [[ $rom_os == "MIUI" ]]; then
    os_type="MIUI"
else
    os_type="HyperOS"
fi

#Generate Super.img
superSize=$(bash "$work_dir/bin/getSuperSize.sh" "$getvar")
repack "Super image size: ${superSize}"
repack "Packing super.img"
for pname in ${super_list}; do
    if [ -d "$work_dir/build/baserom/images/$pname" ]; then
        thisSize=$(du -sb "$work_dir/build/baserom/images/${pname}" | awk '{print $1}')
        if [[ $androidVER == "12" ]]; then
           case $pname in
             odm) addSize=104217728 ;;
             system) addSize=114217728 ;;
             vendor) addSize=104217728 ;;
             system_ext) addSize=104217728 ;;
             product) addSize=104217728 ;;
             *) addSize=8054432 ;;
           esac
        else
           case $pname in
             mi_ext) addSize=100000000 ;;
             odm) addSize=100000000 ;;
             system) addSize=100000000 ;;
             vendor) addSize=100000000 ;;
             system_ext) addSize=100000000 ;;
             product) addSize=100000000 ;;
             *) addSize=8054432 ;;
           esac
        fi

        thisSize=$(echo "$thisSize + $addSize" | bc)
        # Đọc type theo TỪNG partition — ROM trộn EXT+EROFS sẽ sai nếu dùng 1 type chung.
        this_pack_type=$(pack_type_for "$pname")
        if [[ "$this_pack_type" == "EXT" ]]; then
            python3 "$work_dir/bin/fix_selinux.py" \
                "$work_dir/build/baserom/images/${pname}" \
                "$work_dir/build/baserom/images/config/${pname}_fs_config" \
                "$work_dir/build/baserom/images/config/${pname}_file_contexts" >/dev/null 2>&1
            make_ext4fs -J -T "$(date +%s)" \
                -S "$work_dir/build/baserom/images/config/${pname}_file_contexts" \
                -l "$thisSize" \
                -C "$work_dir/build/baserom/images/config/${pname}_fs_config" \
                -L "${pname}" -a "${pname}" \
                "$work_dir/build/baserom/images/${pname}.img" \
                "$work_dir/build/baserom/images/${pname}" >/dev/null 2>&1
            if [ -f "$work_dir/build/baserom/images/${pname}.img" ]; then
                repack "Packing [${pname}.img] success"
            else
                die "Packing [${pname}] failed!"
            fi
        elif [[ "$this_pack_type" == "EROFS" ]]; then
            python3 "$work_dir/bin/fix_selinux.py" \
                "$work_dir/build/baserom/images/${pname}" \
                "$work_dir/build/baserom/images/config/${pname}_fs_config" \
                "$work_dir/build/baserom/images/config/${pname}_file_contexts" >/dev/null 2>&1
            mkfs.erofs --quiet -zlz4hc,9 \
                --mount-point "${pname}" \
                --fs-config-file="$work_dir/build/baserom/images/config/${pname}_fs_config" \
                --file-contexts="$work_dir/build/baserom/images/config/${pname}_file_contexts" \
                "$work_dir/build/baserom/images/${pname}.img" \
                "$work_dir/build/baserom/images/${pname}" >/dev/null 2>&1
            if [ -f "$work_dir/build/baserom/images/${pname}.img" ]; then
                repack "Packing [${pname}.img] success"
            else
                die "Packing [${pname}] failed!"
            fi
        else
            die "Unable to handle img (${pname}, type='${this_pack_type}'), exit."
        fi
    fi
done

is_ab_device=false
if grep -q "ro.build.ab_update=true" build/baserom/images/vendor/build.prop 2>/dev/null; then
    is_ab_device=true
fi

# Pack super.img — lpargs is a bash array so arguments never word-split wrongly.
lpargs=()
if [[ "$is_ab_device" == false ]]; then
    repack "Packing super.img for A-only device"
    GROUP_SIZE=$((superSize - 268435456))
    lpargs=(-F --output build/baserom/images/super.img
             --metadata-size 65536 --super-name super --metadata-slots 2
             --block-size 4096 --device "super:$superSize"
             --group "qti_dynamic_partitions:$GROUP_SIZE")

    for pname in ${super_list}; do
        if [ -f "build/baserom/images/${pname}.img" ]; then
            if [[ "${OSTYPE:-}" == darwin* ]]; then
                subsize=$(stat -f%z "build/baserom/images/${pname}.img")
            else
                subsize=$(du -sb "build/baserom/images/${pname}.img" | awk '{print $1}')
            fi
            repack "Super sub-partition [$pname] size: [$subsize]"
            lpargs+=(--partition "${pname}:readonly:${subsize}:qti_dynamic_partitions"
                     --image "${pname}=build/baserom/images/${pname}.img")
        fi
    done

else
    repack "Packing super.img for V-AB device"

    GROUP_SIZE=$((superSize - 268435456))   # 256MB margin - Fix for error -22

    lpargs=(-F --sparse --virtual-ab
             --output "$work_dir/build/baserom/images/super.img"
             --metadata-size 65536 --super-name super --metadata-slots 3
             --block-size 4096 --device "super:$superSize"
             --group "qti_dynamic_partitions_a:$GROUP_SIZE"
             --group "qti_dynamic_partitions_b:$GROUP_SIZE")

    for pname in ${super_list}; do
        if [ -f "build/baserom/images/${pname}.img" ]; then
            subsize=$(du -sb "build/baserom/images/${pname}.img" | awk '{print $1}')
            repack "Super sub-partition [$pname] size: [$subsize]"
            lpargs+=(--partition "${pname}_a:readonly:${subsize}:qti_dynamic_partitions_a"
                     --image "${pname}_a=build/baserom/images/${pname}.img"
                     --partition "${pname}_b:readonly:0:qti_dynamic_partitions_b")
        fi
    done
fi

# Run lpmake
partition_count=0
for arg in "${lpargs[@]}"; do
    [[ "$arg" == "--partition" ]] && partition_count=$((partition_count + 1))
done
if [[ $partition_count -eq 0 ]]; then
    die "No partitions to pack into super.img (Partition table must have at least one entry)."
fi

# Kiểm tra tràn super TRƯỚC khi lpmake — fail sớm thay vì ra ROM flash là bootloop.
# Tổng kích thước các partition con phải <= GROUP_SIZE (super - margin).
total_parts=0
for pname in ${super_list}; do
    if [[ -f "$work_dir/build/baserom/images/${pname}.img" ]]; then
        psz=$(du -sb "$work_dir/build/baserom/images/${pname}.img" | awk '{print $1}')
        total_parts=$((total_parts + psz))
    fi
done
repack "Total partition images: $total_parts bytes / GROUP_SIZE: $GROUP_SIZE bytes"
if [[ $total_parts -gt $GROUP_SIZE ]]; then
    over=$((total_parts - GROUP_SIZE))
    die "PARTITION OVERFLOW: total $total_parts > super group $GROUP_SIZE (vượt $over bytes). Giảm APK/dữ liệu trong product hoặc ROM nguồn quá đầy."
fi

lpmake "${lpargs[@]}"

if [ -f "$work_dir/build/baserom/images/super.img" ]; then
    repack "Successfully packed super.img."
else
    die "Unable to pack super.img."
fi

for pname in ${super_list}; do
    rm -f "$work_dir/build/baserom/images/${pname}.img"
done

find "$work_dir/build" -exec touch -t 200901010000.00 {} + 2>/dev/null || true