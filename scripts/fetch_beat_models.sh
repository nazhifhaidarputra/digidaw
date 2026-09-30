#!/usr/bin/env bash
# Downloads the Beat This! ONNX models used for tempo detection into assets/models/.
#
# The models come from https://github.com/danigb/beat-this-rs (MIT), a Rust port of
# "Beat This!" by the Institute of Computational Perception, JKU Linz. The small mel front
# end is committed; the 10 MB small beat model is fetched here and git-ignored. Both are
# checked against pinned SHA-256 hashes, and files that already match are kept. The 83 MB
# FP32 model is no longer used.
set -euo pipefail

REPO="danigb/beat-this-rs"
MEL_COMMIT="089b509247e6fdcec666511c0dcf0d5f39c21e73"
MEL_URL="https://raw.githubusercontent.com/${REPO}/${MEL_COMMIT}/models/mel_spectrogram.onnx"
MEL_SHA256="fdd59e65c515331308e4c8841edf99972deca646bdf6197744c2a5b7755e3de9"
SMALL_URL="https://raw.githubusercontent.com/${REPO}/${MEL_COMMIT}/models/beat_this_small.onnx"
SMALL_SHA256="a5f8d39d989f31859454ba27afe61c5317ca95e4d9373e6853e5361b8937172f"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${ROOT}/assets/models"
mkdir -p "${DEST}"

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

fetch() {
    local url="$1" file="$2" expected="$3"
    local target="${DEST}/${file}"
    if [ -f "${target}" ] && [ "$(sha256_of "${target}")" = "${expected}" ]; then
        echo "==> ${file} is up to date"
        return
    fi
    echo "==> Downloading ${file}..."
    local partial="${target}.part"
    curl -fL --retry 3 -o "${partial}" "${url}"
    local actual
    actual="$(sha256_of "${partial}")"
    if [ "${actual}" != "${expected}" ]; then
        rm -f "${partial}"
        echo "ERROR: ${file} checksum mismatch (expected ${expected}, got ${actual})" >&2
        exit 1
    fi
    mv "${partial}" "${target}"
}

fetch "${MEL_URL}" "mel_spectrogram.onnx" "${MEL_SHA256}"
fetch "${SMALL_URL}" "beat_this_small.onnx" "${SMALL_SHA256}"
