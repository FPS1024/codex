#!/usr/bin/env bash
set -euo pipefail

readonly SDK_PATH="/Users/malacaihongpi/Codex/SDKs/iPhoneOS15.6.sdk"

if [[ ! -d "${SDK_PATH}" ]]; then
    echo "required iPhoneOS 15.6 SDK not found: ${SDK_PATH}" >&2
    exit 1
fi

if [[ ! -f "${SDK_PATH}/SDKSettings.json" ]]; then
    echo "required iPhoneOS 15.6 SDK metadata not found: ${SDK_PATH}/SDKSettings.json" >&2
    exit 1
fi

cd "$(dirname "$0")/.."

# Link-time optimization is prohibitively slow for this large cross-compiled
# workspace. Keep optimized codegen while disabling LTO for iOS builds only.
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
export CARGO_PROFILE_RELEASE_DEBUG=false

exec cargo build \
    --release \
    -p codex-cli \
    --bin codex \
    --target aarch64-apple-ios
