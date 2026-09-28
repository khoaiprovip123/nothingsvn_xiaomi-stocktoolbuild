#!/usr/bin/env bash
# setup.sh — install the host dependencies needed to run the build pipeline.
# Targets Debian/Ubuntu (the GitHub Actions runner image). Run with sudo if
# your user cannot install packages.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

APT_PACKAGES=(
    unzip
    aria2
    p7zip-full          # 7z
    zip
    openjdk-17-jre-headless
    python3
    python3-pip
    zstd
    bc
    libxml2-utils       # xmlstarlet is in libxml2-utils on some releases
    xmlstarlet
    erofs-utils
    android-sdk-libsparse-utils   # simg2img / img2simg
    lz4
    xz-utils
    wget
    curl
    jq
    git
)

PIP_PACKAGES=(
    requests
    ConfigObj
    google-auth
    google-auth-oauthlib
    google-auth-httplib2
    google-api-python-client
)

echo "[setup] Updating apt index..."
$SUDO apt-get update -y

echo "[setup] Installing apt packages..."
$SUDO apt-get install -y "${APT_PACKAGES[@]}"

# zipalign + aapt come from the Android SDK build-tools, not always packaged.
if ! command -v zipalign >/dev/null 2>&1 || ! command -v aapt >/dev/null 2>&1; then
    echo "[setup] Installing android-sdk build-tools (zipalign, aapt)..."
    $SUDO apt-get install -y android-sdk-build-tools \
        || $SUDO apt-get install -y aapt zipalign \
        || echo "[setup] WARN: could not install zipalign/aapt — install Android build-tools manually."
fi

echo "[setup] Installing Python packages..."
python3 -m pip install --upgrade "${PIP_PACKAGES[@]}"

# Make the bundled prebuilt tools executable.
tools_dir="$(pwd)/bin/$(uname)/$(uname -m)"
if [[ -d "$tools_dir" ]]; then
    chmod +x "${tools_dir}"/* 2>/dev/null || true
fi
chmod +x ./*.sh 2>/dev/null || true

echo "[setup] Done. Verify with:"
echo "  bash build.sh <URL_OR_PATH_TO_ROM.zip>"
