#!/usr/bin/env bash
# Download Godot 4.3-stable (linux x86_64), verify SHA256, and link it as `godot`.
# Idempotent. Set GODOT_BIN to an existing executable to skip the download.
set -euo pipefail

VERSION="4.3-stable"
ZIP_NAME="Godot_v4.3-stable_linux.x86_64.zip"
BIN_NAME="Godot_v4.3-stable_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}/${ZIP_NAME}"
# sha256sum of the official 4.3-stable linux x86_64 editor zip.
EXPECTED_SHA256="7de56444b130b10af84d19c7e0cf63cf9e9937ee4ba94364c3b7dd114253ca21"

PREFIX="${GODOT_PREFIX:-${HOME}/.local}"
BIN_DIR="${PREFIX}/bin"
SHARE_DIR="${PREFIX}/share/godot/${VERSION}"
TARGET="${BIN_DIR}/godot"
INSTALLED="${SHARE_DIR}/${BIN_NAME}"

mkdir -p "${BIN_DIR}" "${SHARE_DIR}"

link_and_report() {
	local src="$1"
	ln -sfn "${src}" "${TARGET}"
	echo "godot -> ${TARGET}"
	echo "PATH hint: export PATH=\"${BIN_DIR}:\$PATH\""
	"${TARGET}" --version
}

if [[ -n "${GODOT_BIN:-}" ]]; then
	if [[ ! -x "${GODOT_BIN}" ]]; then
		echo "GODOT_BIN is not an executable file: ${GODOT_BIN}" >&2
		exit 1
	fi
	link_and_report "$(readlink -f "${GODOT_BIN}")"
	exit 0
fi

if [[ -x "${INSTALLED}" ]]; then
	link_and_report "${INSTALLED}"
	exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
echo "downloading ${URL}"
curl -fL --retry 3 --retry-delay 2 -o "${TMP}/${ZIP_NAME}" "${URL}"
echo "${EXPECTED_SHA256}  ${TMP}/${ZIP_NAME}" | sha256sum -c -
unzip -q -o "${TMP}/${ZIP_NAME}" -d "${SHARE_DIR}"
chmod +x "${INSTALLED}"
if [[ ! -x "${INSTALLED}" ]]; then
	echo "unzip did not produce ${INSTALLED}" >&2
	exit 1
fi
link_and_report "${INSTALLED}"
