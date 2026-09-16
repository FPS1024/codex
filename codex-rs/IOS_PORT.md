# iOS arm64 port

This branch builds the Rust Codex CLI as a standalone Mach-O executable for
jailbroken arm64 iOS devices. It does not produce an App Store application.

## Pinned SDK

This workspace intentionally uses only:

```text
/Users/malacaihongpi/Codex/SDKs/iPhoneOS15.6.sdk
```

Although the directory is named `iPhoneOS15.6.sdk`, its `SDKSettings.json`
identifies the SDK as iOS 15.5 (`CanonicalName` is `iphoneos15.5`). The build
therefore links with SDK 15.5 and sets the minimum deployment target to 15.5.
This still runs on an iOS 15.6 device. Do not substitute the SDK selected by
`xcrun` or the SDK bundled with Xcode.

The pinned SDK path is enforced by:

- `.cargo/config.toml`
- `scripts/ios-clang`
- `scripts/build-ios.sh`
- `scripts/package-ios.sh`

## Build

```bash
cd codex-rs
./scripts/build-ios.sh
```

The build disables thin LTO for iOS to avoid excessive cross-compilation time.
It keeps release optimization and uses 16 codegen units.

The linked executable is:

```text
target/aarch64-apple-ios/release/codex
```

## Package

```bash
cd codex-rs
./scripts/package-ios.sh
```

`package-ios.sh` copies the release executable to:

```text
dist/codex-ios-arm64
```

It removes debug and local symbols with `strip -S -x`, then adds a jailbreak
signature with `ldid -S`.

`codesign` does not validate an `ldid` signature, so `codesign --verify` can
report that the file is unsigned. The `LC_CODE_SIGNATURE` load command added by
`ldid` is the relevant signature for the jailbroken installation flow.

## Debian package

Create an installable rootless iOS package with:

```bash
cd codex-rs
./scripts/make-deb.sh
```

The package is written to:

```text
dist/codex_<version>_iphoneos-arm64.deb
```

It installs the executable at `/var/jb/usr/bin/codex` and documentation under
`/var/jb/usr/share/doc/codex`. The package `postinst` script reapplies the
`ldid -S` signature after installation.

## Install on iPhone

The destination differs between rootful and rootless jailbreaks. Use the
directory already present in the terminal's `PATH`.

Rootful example:

```sh
scp codex-ios-arm64 root@<iphone>:/usr/local/bin/codex
ssh root@<iphone>
chmod 755 /usr/local/bin/codex
```

Rootless example:

```sh
scp codex-ios-arm64 root@<iphone>:/var/jb/usr/local/bin/codex
ssh root@<iphone>
chmod 755 /var/jb/usr/local/bin/codex
```

If the transfer or package manager removes the signature, run this on the
device:

```sh
ldid -S /path/to/codex
```

## Runtime setup

Use a writable home directory and point Codex at the jailbreak shell and tools:

```sh
export CODEX_HOME=/var/mobile/.codex
export PATH=/var/jb/usr/local/bin:/var/jb/usr/bin:/usr/local/bin:/usr/bin:/bin
export SHELL=/var/jb/usr/bin/zsh
mkdir -p "$CODEX_HOME"
```

Test in this order:

```sh
codex --version
codex login --device-code
codex exec "uname -a"
codex
```

Use the device-code login flow. Browser-based login can fail because a
command-line process on iOS cannot reliably launch a browser.

Use file-backed credential storage in `$CODEX_HOME/config.toml`:

```toml
cli_auth_credentials_store = "file"
mcp_oauth_credentials_store = "file"
```

## iOS limitations

- Codex's macOS Seatbelt and Linux sandbox backends are unavailable on iOS.
  Commands run with the permissions granted by the jailbreak and terminal.
- Native clipboard access is unavailable. Clipboard copy falls back to OSC 52
  when the terminal supports it. Clipboard image paste is disabled.
- Browser launch, desktop notifications, voice/audio integration, and other
  desktop-specific integrations may not work. The core TUI and `codex exec`
  path remain the primary targets.
- Use a trusted workspace. Do not run arbitrary untrusted repositories as
  root merely because the internal sandbox is unavailable.
