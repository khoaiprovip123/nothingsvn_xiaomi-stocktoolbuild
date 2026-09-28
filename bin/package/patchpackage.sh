#!/usr/bin/env bash
# patchpackage.sh — run every package-level patcher.
set -euo pipefail

work_dir=$(pwd)
# shellcheck source=../../functions.sh
source "$work_dir/functions.sh"

mods "Add Package..."
target_dir="$work_dir/bin/package"

# Each entry: <path relative to bin/package>/<script>.
# Skip silently-missing optional patchers so one absent tool doesn't kill the build.
# A present-but-failing patcher logs a warning and the build continues.
run_package_script() {
    local script="$1"
    if [[ -f "$script" ]]; then
        if ! bash "$script"; then
            warn "Package script failed (continuing): $script"
        fi
    else
        warn "Package script not found, skipping: $script"
    fi
}

run_package_script "$target_dir/COREPATCH/update.sh"
run_package_script "$target_dir/DISABLE_AVB/DISABLEavb.sh"
run_package_script "$target_dir/KouseiPatcher/update.sh"
run_package_script "$target_dir/NOTIFICATION_FIX/notificationFIX.sh"
run_package_script "$target_dir/RefreshRate/1hz.sh"
run_package_script "$target_dir/ResetProp/update.sh"

mods "Add Package Done"
