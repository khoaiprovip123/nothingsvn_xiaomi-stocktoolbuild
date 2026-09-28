#!/bin/bash
WORK_DIR=$(pwd)

# Shared log helper — always quote the message so spaces/globs survive.
_log() {
    local tag="$1"
    shift
    if [ "$#" -ge 1 ]; then
        printf '[%s] - %s\n' "$tag" "$*"
    else
        printf 'Usage: %s <string>\n' "${FUNCNAME[1]:-log}"
    fi
}

mods()         { _log "MODS"            "$@"; }
info()         { _log "INFO"            "$@"; }
warn()         { _log "WARN"            "$@"; }
yellow()       { _log "WARN"            "$@"; }
error()        { _log "ERROR"           "$@"; }
unpack()       { _log "UNPACK"          "$@"; }
unpack_erofs() { _log "UNPACK - EROFS"  "$@"; }
unpack_ext()   { _log "UNPACK - EXT4"   "$@"; }
repack()       { _log "REPACK"          "$@"; }
upload()       { _log "UPLOADING"       "$@"; }
patch()        { _log "PATCH"           "$@"; }

# Fatal error: print and exit non-zero.
die() {
    error "$*"
    exit 1
}

# Check for required dependencies
exists() {
    command -v "$1" > /dev/null 2>&1
}

# Map of tools that are NOT plain apt package names.
# zipalign / aapt ship with the Android build-tools; extract.erofs / gettype /
# payload-extract / lpmake are the prebuilt binaries under bin/.
_tool_apt_name() {
    case "$1" in
        zipalign|aapt) echo "android-sdk-build-tools" ;;
        *) echo "$1" ;;
    esac
}

abort() {
    local tool="$1"
    local pkg
    pkg=$(_tool_apt_name "$tool")
    yellow "--> Missing $tool ! installing $pkg..."
    if exists apt-get; then
        apt-get install -y "$pkg" || die "Failed to install dependency: $pkg (needed for $tool)"
    else
        die "Missing dependency: $tool (install package '$pkg' manually)"
    fi
    exists "$tool" || die "Dependency still missing after install: $tool"
}

check() {
    local missing=0
    for b in "$@"; do
        if ! exists "$b"; then
            abort "$b"
            missing=1
        fi
    done
    return 0
}

# Check for a prop's existence
is_property_exists () {
    if [ $(grep -c "$1" "$2") -ne 0 ] ; then
        return 0
    else
        return 1
    fi
}

disable_avb_verify() {
    if [[ ! -d "$1" ]]; then
        warn "No such directory: $1"
        return
    fi
    fstab_files=$(find "$1" -type f -name "*fstab*")
    info "Disabling avb_verify in files: $fstab_files"
    if [[ -z "$fstab_files" ]]; then
        warn "No fstab files found in $1"
        return
    fi
    for fstab in $fstab_files; do
        if [[ -f $fstab ]]; then
            info "Processing $fstab"
            # Drop the whole avb / avb_keys / avb=<vbmeta_partition> token in one
            # go. Chaining partial patterns (",avb=vbmeta" then ",avb") leaves
            # the tail of longer flags behind - e.g. avb=vbmeta_system_ext turns
            # into a stray "_system_ext" flag - and fs_mgr then fails to parse
            # the entry, so first_stage_mount aborts and the device boot loops.
            # Both forms below require a neighbouring flag, so the fs_mgr field
            # can never be emptied out completely.
            sed -E -i \
                -e ':a' -e 's/,avb(_keys)?(=[^,[:space:]]*)?(,|[[:space:]]|$)/\3/' -e 'ta' \
                -e ':b' -e 's/([[:space:]])avb(_keys)?(=[^,[:space:]]*)?,/\1/' -e 'tb' \
                "$fstab"
        else
            warn "$fstab not found, please check it manually"
        fi
    done
}

remove_data_encrypt() {
    local fstab_files
    fstab_files=$(find "$1" -type f -name "*fstab*")
    info "Disabling data enc in files: $fstab_files"
    if [[ -z "$fstab_files" ]]; then
        yellow "No fstab files found in $1"
        return
    fi
    local fstab
    for fstab in $fstab_files; do
        if [[ -f "$fstab" ]]; then
            sed -i \
                -e "s/,fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0//g" \
                -e "s/,fileencryption=aes-256-xts:aes-256-cts:v2+emmc_optimized+wrappedkey_v0//g" \
                -e "s/,fileencryption=aes-256-xts:aes-256-cts:v2//g" \
                -e "s/,metadata_encryption=aes-256-xts:wrappedkey_v0//g" \
                -e "s/,fileencryption=aes-256-xts:wrappedkey_v0//g" \
                -e "s/,metadata_encryption=aes-256-xts//g" \
                -e "s/,fileencryption=aes-256-xts//g" \
                -e "s/fileencryption/encryptable/g" \
                -e "s/,fileencryption=ice//g" \
                "$fstab"
        else
            yellow "$fstab not found, please check it manually"
        fi
    done
}

# Extract a partition image (ext4 or erofs) into $target_dir, then delete the .img.
# Runs without sudo: CI runners already execute as root, and local builds should
# not silently escalate.
#
# Ghi thêm fstype per-partition vào bin/ddevice/fstype.<part>.txt để packROM.sh
# pack đúng kiểu cho từng partition (ROM trộn EXT+EROFS sẽ sai nếu dùng 1 type chung).
extract_partition() {
    local part_img="$1"
    local target_dir="$2"
    local part_name pack_type img_type

    [[ -f "$part_img" ]] || return 0

    part_name=$(basename "$part_img" .img)
    img_type=$("${WORK_DIR}/bin/Linux/x86_64/gettype" -i "$part_img")

    case "$img_type" in
        ext)
            pack_type="EXT"
            printf '%s\n' "$pack_type" > "${WORK_DIR}/bin/ddevice/fstype.txt"
            printf '%s\n' "$pack_type" > "${WORK_DIR}/bin/ddevice/fstype.${part_name}.txt"
            python3 "${WORK_DIR}/bin/imgextractor/imgextractor.py" "$part_img" "$target_dir" >/dev/null 2>&1 \
                || die "Extracting ${part_name} failed."
            unpack "File ${part_name} extracted."
            rm -f "$part_img"
            ;;
        erofs)
            pack_type="EROFS"
            printf '%s\n' "$pack_type" > "${WORK_DIR}/bin/ddevice/fstype.txt"
            printf '%s\n' "$pack_type" > "${WORK_DIR}/bin/ddevice/fstype.${part_name}.txt"
            extract.erofs -x -i "$part_img" -o "$target_dir" >/dev/null 2>&1 \
                || die "Extracting ${part_name} failed."
            unpack "File ${part_name} extracted."
            rm -f "$part_img"
            ;;
        *)
            die "Unable to handle img (${part_name}, type='${img_type}'), exit."
            ;;
    esac
}

# Đọc kiểu FS của một partition cụ thể; fallback về fstype.txt nếu không có.
pack_type_for() {
    local part_name="$1"
    local per_part="${WORK_DIR}/bin/ddevice/fstype.${part_name}.txt"
    if [[ -f "$per_part" ]]; then
        cat "$per_part"
    elif [[ -f "${WORK_DIR}/bin/ddevice/fstype.txt" ]]; then
        cat "${WORK_DIR}/bin/ddevice/fstype.txt"
    else
        echo "EROFS"
    fi
}

setprop_rc() {
    local target_section="$1"    # e.g., "on boot"
    local insert_value="$2"      # e.g., "setprop com.exx.c true"
    local file="$3"              # e.g., "a.rc"

    if [[ ! -f "$file" ]]; then
        echo "Error: file '$file' not found"
        return 1
    fi

    local temp_file="${file}.tmp"
    local matched=0

    > "$temp_file"

    while IFS= read -r line; do
        echo "$line" >> "$temp_file"

        if [[ "$matched" -eq 0 && "$line" == "$target_section" ]]; then
            matched=1
            while IFS= read -r next_line; do
                if [[ "$next_line" =~ ^[[:space:]] ]]; then
                    echo "$next_line" >> "$temp_file"
                else
                    # Insert your new value and break
                    while IFS= read -r value_line; do
                        [[ -n "$value_line" ]] && echo "    $value_line" >> "$temp_file"
                    done <<< "$insert_value"
                    echo "$next_line" >> "$temp_file"
                    break
                fi
            done
        fi
    done < "$file"

    mv "$temp_file" "$file"
}

change_prop() {
    local key="$1"
    local new_value="$2"
    local base_dir="$work_dir/build/baserom/images"

    if [[ -z "$key" || -z "$new_value" ]]; then
        echo "[INFO] - Usage: change_prop <property_key> <new_value>" >&2
        return 1
    fi

    if [[ ! -d "$base_dir" ]]; then
        echo "[ERROR] -  Directory '$base_dir' not found!" >&2
        return 1
    fi

    new_value=$(echo "$new_value" | tr -d '\r\n')
    local escaped_value
    escaped_value=$(printf '%s\n' "$new_value" | sed 's/[\/&#]/\\&/g')

    local found_file=""
    while IFS= read -r -d '' file; do
        if grep -q -E "^$key=" "$file"; then
            sed -i -E "s#^($key)=.*#\1=$escaped_value#" "$file"
            echo "[SYSTEM] - Updated '$key'"
            return 0
        fi
    done < <(find "$base_dir" -type f -name "build.prop" -print0)

    # If key not found in any file, append to the first build.prop
    local first_file
    first_file=$(find "$base_dir" -type f -name "build.prop" | head -n1)

    if [[ -n "$first_file" ]]; then
        echo "$key=$new_value" >> "$first_file"
        echo "[INFO] - Appended '$key=$new_value' to $first_file"
        return 0
    else
        echo "[INFO] - No build.prop files found to update or append." >&2
        return 1
    fi
}


mvsml() {
    local file_name="$1"
    local target_folder="$2"
    local framework_dir="$3"

    file_path=$(find "$framework_dir" -type f -name "$file_name")

    if [ -z "$file_path" ]; then
        echo "File $file_name not found in any dex folder within $framework_dir."
        return 1
    fi

    parent_dex_folder=$(dirname "$file_path" | sed "s|$framework_dir/||" | cut -d/ -f1)
    relative_path=$(echo "$file_path" | sed "s|$framework_dir/$parent_dex_folder/||")

    target_path="$target_folder/$relative_path"

    mkdir -p "$(dirname "$target_path")"

    mv "$file_path" "$target_path"

    echo "Moved $file_name to $target_path"
}

mvdir() {
    local folder_name="$1"
    local target_folder="$2"
    local framework_dir="$3"

    folder_path=$(find "$framework_dir" -type d -name "$folder_name")

    if [ -z "$folder_path" ]; then
        echo "Folder $folder_name not found in any dex folder within $framework_dir."
        return 1
    fi

    find "$folder_path" -type f -name "*.smali" | while read -r file_path; do
        parent_dex_folder=$(dirname "$file_path" | sed "s|$framework_dir/||" | cut -d/ -f1)
        relative_path=$(echo "$file_path" | sed "s|$framework_dir/$parent_dex_folder/||")

        target_path="$target_folder/$relative_path"

        mkdir -p "$(dirname "$target_path")"

        mv "$file_path" "$target_path"
    done

    echo "Moved all .smali files from $folder_name to $target_folder"
}

patch_file_context() {
    local partition="$1"
    local file_path="$2"
    local context="$3"
    local images_dir="$WORK_DIR/build/baserom/images"
    local config_dir="$images_dir/config"
    
    local config_fc="$config_dir/${partition}_file_contexts"
    if [ -f "$config_fc" ]; then
        if ! grep -q "$file_path" "$config_fc"; then
            echo "$file_path $context" >> "$config_fc"
        fi
    fi

    local image_fc="$images_dir/$partition/etc/selinux/${partition}_file_contexts"
    if [ -f "$image_fc" ]; then
        if ! grep -q "$file_path" "$image_fc"; then
            echo "$file_path $context" >> "$image_fc"
        fi
    fi
}

patch_sepolicy() {
    local partition="$1"
    local rule="$2"
    local images_dir="$WORK_DIR/build/baserom/images"
    
    local cil_file="$images_dir/$partition/etc/selinux/${partition}_sepolicy.cil"
    if [ -f "$cil_file" ]; then
        if ! grep -q -F "$rule" "$cil_file"; then
            echo "$rule" >> "$cil_file"
        fi
    fi
}