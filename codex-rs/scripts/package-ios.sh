#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly INPUT="${WORKSPACE_DIR}/target/aarch64-apple-ios/release/codex"
readonly OUTPUT_DIR="${WORKSPACE_DIR}/dist"
readonly OUTPUT="${OUTPUT_DIR}/codex-ios-arm64"

if [[ ! -f "${INPUT}" ]]; then
    echo "iOS codex binary not found: ${INPUT}" >&2
    exit 1
fi

if ! command -v ldid >/dev/null 2>&1; then
    echo "ldid is required to sign the jailbroken iOS binary" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
cp -f "${INPUT}" "${OUTPUT}"

# Keep exported symbols, but remove the debug/local-symbol bulk.
/usr/bin/strip -S -x "${OUTPUT}"
ldid -S "${OUTPUT}"

file "${OUTPUT}"
otool -l "${OUTPUT}" | sed -n '/LC_BUILD_VERSION/,/}/p'
shasum -a 256 "${OUTPUT}"
