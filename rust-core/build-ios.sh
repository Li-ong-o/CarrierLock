#!/bin/bash
# build-ios.sh
# Builds the Rust FFI static library for iOS and packages AirliftFFI.xcframework.
# Run this script from rust-core/ any time the FFI source changes.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-18.0}"

# Make ~/.cargo visible to non-login shells (Xcode build phases, CI)
# shellcheck disable=SC1090
if [ -d "$HOME/.cargo/bin" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"

# Remap $HOME so absolute source paths don't appear in the binary's log output
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=${HOME}=/build"
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=${HOME}=/build"
export TARGET_CFLAGS="${TARGET_CFLAGS:-} -ffile-prefix-map=${HOME}=/build"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> Installing iOS targets (if needed)"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim 2>/dev/null || true

echo "==> Building Rust static libs (release)"
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

echo "==> Repackaging AirliftFFI.xcframework"
rm -rf "$ROOT/AirliftFFI.xcframework"
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libairlift_ffi.a \
  -headers include \
  -library target/aarch64-apple-ios-sim/release/libairlift_ffi.a \
  -headers include \
  -output "$ROOT/AirliftFFI.xcframework"

echo "==> Done."
echo "    scripts/build-airlift-xcframework.sh copies this xcframework into Vendor/."
