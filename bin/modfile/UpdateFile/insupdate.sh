#!/usr/bin/env bash
# insupdate.sh — run every update.sh under bin/modfile/UpdateFile/.
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

mods "Starting Update File..."
TARGET_DIR="$work_dir/bin/modfile/UpdateFile"

# Scripts listed here are orchestrators, not mods — never execute them as mods.
noexecute=("insupdate")

is_skipped() {
    local base="$1"
    local ex
    for ex in "${noexecute[@]}"; do
        [[ "$base" == "$ex" ]] && return 0
    done
    return 1
}

# -print0/-read -d '' keeps paths with spaces intact.
# Each mod is best-effort: a failing optional mod logs a warning and the
# build continues, so one missing file doesn't kill the whole ROM.
while IFS= read -r -d '' script; do
    base="$(basename "$script" .sh)"
    if is_skipped "$base"; then
        continue
    fi
    if ! bash "$script"; then
        warn "Mod script failed (continuing): $script"
    fi
done < <(find "$TARGET_DIR" -type f -name '*.sh' -print0)
