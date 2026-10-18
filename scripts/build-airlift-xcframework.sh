#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUST_CORE="$ROOT/rust-core"

# Keep the build independent of the developer's default Xcode selection.
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"

"$RUST_CORE/build-ios.sh"

rm -rf "$ROOT/Vendor/CarrierLock/AirliftFFI.xcframework"
cp -R "$RUST_CORE/AirliftFFI.xcframework" "$ROOT/Vendor/CarrierLock/AirliftFFI.xcframework"

cd "$ROOT"
{
  find Vendor/CarrierLock/AirliftFFI.xcframework -type f -print
  printf '%s\n' CarrierLockApp/Airlift/GrappaHelper.h CarrierLockApp/Airlift/GrappaHelper.m
} | LC_ALL=C sort | xargs shasum -a 256 > Vendor/CarrierLock/SHA256SUMS

echo "Built AirliftFFI from repository rust-core source"
