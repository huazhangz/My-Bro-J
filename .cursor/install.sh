#!/usr/bin/env bash
# Cloud Agent install step for the SunBro Desktop Pet (Godot 4.7.2) project.
# Installs the pinned Godot editor/runtime binary and warms the import cache.
# Idempotent: safe to run repeatedly and against a cached/snapshotted VM.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_BIN="/usr/local/bin/godot"
ZIP_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${ZIP_NAME}.zip"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_godot() {
	local tmp
	tmp="$(mktemp -d)"
	echo "Downloading Godot ${GODOT_VERSION}..."
	curl -fL --retry 4 --retry-delay 4 -o "${tmp}/godot.zip" "${DOWNLOAD_URL}"
	unzip -o -q "${tmp}/godot.zip" -d "${tmp}"
	sudo install -m 0755 "${tmp}/${ZIP_NAME}" "${GODOT_BIN}"
	rm -rf "${tmp}"
}

# Only (re)install when the pinned version is not already present.
if [ -x "${GODOT_BIN}" ] && godot --version 2>/dev/null | grep -q "^4.7.2.stable"; then
	echo "Godot ${GODOT_VERSION} already installed: $(godot --version)"
else
	install_godot
	echo "Installed: $(godot --version)"
fi

# Warm the Godot import cache so the project is ready to run. This also
# validates that all scenes/scripts/resources import without errors.
echo "Importing Godot project resources..."
godot --headless --path "${PROJECT_DIR}" --import

echo "SunBro Desktop Pet environment is ready."
