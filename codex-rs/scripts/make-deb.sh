#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_DIR="$(cd "${WORKSPACE_DIR}/.." && pwd)"
readonly OUTPUT_DIR="${WORKSPACE_DIR}/dist"
readonly TARGET_BINARY="${WORKSPACE_DIR}/target/aarch64-apple-ios/release/codex"
readonly SIGNED_BINARY="${OUTPUT_DIR}/codex-ios-arm64"
readonly DOC_DIR="${WORKSPACE_DIR}/var/jb/usr/share/doc/codex"

if [[ -f "${SIGNED_BINARY}" ]]; then
    readonly INPUT_BINARY="${SIGNED_BINARY}"
else
    readonly INPUT_BINARY="${TARGET_BINARY}"
fi

if [[ ! -f "${INPUT_BINARY}" ]]; then
    echo "iOS codex binary not found: ${INPUT_BINARY}" >&2
    exit 1
fi

if ! command -v ar >/dev/null 2>&1; then
    echo "ar is required to create a .deb package" >&2
    exit 1
fi

if ! command -v gzip >/dev/null 2>&1; then
    echo "gzip is required to create a .deb package" >&2
    exit 1
fi

version="$(
    awk '
        /^\[workspace\.package\]$/ { in_package = 1; next }
        in_package && /^version = "/ {
            gsub(/^version = "|"$/, "", $0)
            print
            exit
        }
    ' "${WORKSPACE_DIR}/Cargo.toml"
)"

if [[ -z "${version}" ]]; then
    echo "could not determine workspace version from codex-rs/Cargo.toml" >&2
    exit 1
fi

readonly PACKAGE_NAME="codex_${version}_iphoneos-arm64.deb"
readonly PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}"
readonly PKG_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-ios-deb.XXXXXX")"
readonly CONTROL_DIR="${PKG_ROOT}/DEBIAN"
readonly INSTALL_DIR="${PKG_ROOT}/var/jb/usr/bin"
readonly INSTALLED_DOC_DIR="${PKG_ROOT}/var/jb/usr/share/doc/codex"

cleanup() {
    rm -rf "${PKG_ROOT}"
}
trap cleanup EXIT

mkdir -p "${CONTROL_DIR}" "${INSTALL_DIR}" "${INSTALLED_DOC_DIR}" "${OUTPUT_DIR}"

install -m 0755 "${INPUT_BINARY}" "${INSTALL_DIR}/codex"
install -m 0644 "${REPO_DIR}/LICENSE" "${INSTALLED_DOC_DIR}/LICENSE"
install -m 0644 "${REPO_DIR}/README.md" "${INSTALLED_DOC_DIR}/README.md"
install -m 0644 "${WORKSPACE_DIR}/IOS_PORT.md" "${INSTALLED_DOC_DIR}/README.iOS.md"

installed_size="$(du -sk "${PKG_ROOT}" | awk '{print $1}')"

cat > "${CONTROL_DIR}/control" <<EOF
Package: codex
Name: Codex
Version: ${version}
Architecture: iphoneos-arm64
Maintainer: FPS1024 <FPS1024@users.noreply.github.com>
Author: OpenAI
Section: Development
Priority: optional
Homepage: https://github.com/openai/codex
Depends: firmware (>= 15.5)
Installed-Size: ${installed_size}
Description: OpenAI Codex CLI for jailbroken arm64 iOS
 Codex is an open-source coding agent from OpenAI.
 .
 This is an unofficial aarch64 iOS build packaged for jailbroken devices.
 It installs the executable at /var/jb/usr/bin/codex.
EOF

cat > "${CONTROL_DIR}/postinst" <<'EOF'
#!/bin/sh
set -eu

CODEX_BIN="/var/jb/usr/bin/codex"
chmod 0755 "${CODEX_BIN}"

if command -v ldid >/dev/null 2>&1; then
    ldid -S "${CODEX_BIN}" >/dev/null 2>&1 || true
fi

exit 0
EOF
chmod 0755 "${CONTROL_DIR}/postinst"

cat > "${INSTALLED_DOC_DIR}/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Codex CLI
Source: https://github.com/openai/codex

Files: *
Copyright: OpenAI
License: Apache-2.0
 This package is based on the OpenAI Codex repository.
 The complete license text is installed as LICENSE.
EOF

rm -f "${PACKAGE_PATH}"

if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb --build --root-owner-group "${PKG_ROOT}" "${PACKAGE_PATH}"
else
    readonly DEB_TMP="$(mktemp -d "${TMPDIR:-/tmp}/codex-ios-deb-archive.XXXXXX")"
    trap 'cleanup; rm -rf "${DEB_TMP}"' EXIT

    printf '2.0\n' > "${DEB_TMP}/debian-binary"
    tar --uid 0 --gid 0 --uname root --gname wheel \
        -czf "${DEB_TMP}/control.tar.gz" -C "${CONTROL_DIR}" .
    tar --uid 0 --gid 0 --uname root --gname wheel \
        --exclude './DEBIAN' \
        -czf "${DEB_TMP}/data.tar.gz" -C "${PKG_ROOT}" .

    (
        cd "${DEB_TMP}"
        ar rc "${PACKAGE_PATH}" debian-binary control.tar.gz data.tar.gz
    )
fi

echo "created: ${PACKAGE_PATH}"
echo "version: ${version}"
echo "architecture: iphoneos-arm64"
echo "installed binary: /var/jb/usr/bin/codex"
echo "documentation: /var/jb/usr/share/doc/codex"
echo "size: $(du -h "${PACKAGE_PATH}" | awk '{print $1}')"

if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb --info "${PACKAGE_PATH}"
    dpkg-deb --contents "${PACKAGE_PATH}"
else
    ar t "${PACKAGE_PATH}"
    tar -tzf "${DEB_TMP}/control.tar.gz"
    tar -tzf "${DEB_TMP}/data.tar.gz"
fi
