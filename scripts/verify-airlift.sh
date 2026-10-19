#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
(
  cd Vendor/CarrierLock
  shasum -a 256 -c SHA256SUMS
)

# Symbol names in a Mach-O static archive are stored as plain null-terminated
# byte strings in the object string tables, regardless of which LLVM version
# produced the objects.  The Xcode-supplied nm cannot parse the
# compiler_builtins objects emitted by newer Rust (LLVM 22) and crashes with an
# "Unknown attribute kind" error, which would make these symbols look missing.
# So the authoritative check is a raw byte scan of each archive with grep -a
# (which never depends on nm's LLVM version).  When a compatible llvm-nm is
# available we prefer it for richer diagnostics, but it is never load-bearing.
find_nm() {
  # rustup llvm-tools-preview places llvm-nm inside the active toolchain.
  if command -v rustc >/dev/null 2>&1; then
    local sysroot host nm_bin
    sysroot="$(rustc --print sysroot)"
    host="$(rustc -vV | sed -n 's/^host: //p')"
    nm_bin="$sysroot/lib/rustlib/$host/bin/llvm-nm"
    if [ -x "$nm_bin" ]; then
      printf '%s' "$nm_bin"
      return
    fi
  fi
  if command -v llvm-nm >/dev/null 2>&1; then
    printf '%s' "$(command -v llvm-nm)"
    return
  fi
  if command -v rust-nm >/dev/null 2>&1; then
    printf '%s' "$(command -v rust-nm)"
    return
  fi
  if command -v nm >/dev/null 2>&1; then
    printf '%s' "$(command -v nm)"
  fi
}
NM="$(find_nm || true)"

for library in \
  Vendor/CarrierLock/AirliftFFI.xcframework/ios-arm64/libairlift_ffi.a \
  Vendor/CarrierLock/AirliftFFI.xcframework/ios-arm64-simulator/libairlift_ffi.a
do
  if [ ! -f "$library" ]; then
    echo "Airlift library not found: $library" >&2
    exit 1
  fi
  for symbol in \
    al_exploit_write_dir \
    al_exploit_read_dir \
    al_exploit_restore_dir \
    al_exploit_delete_carrier_dir \
    al_string_free \
    al_syslog_stream_start \
    al_device_respring
  do
    if grep -aq "_${symbol}" "$library"; then
      continue
    fi
    # Fallback for archives that relocate the symbol string table.
    if [ -n "${NM:-}" ] && "$NM" -gU "$library" 2>/dev/null | grep -q "_${symbol}"; then
      continue
    fi
    echo "Airlift library is missing $symbol: $library (nm=$NM)" >&2
    echo "Available _al_ symbols via raw scan:" >&2
    grep -ao "_al_[A-Za-z_][A-Za-z0-9_]*" "$library" | sort -u | head -n 40 || true
    echo "Available _al_ symbols via NM:" >&2
    if [ -n "${NM:-}" ]; then
      "$NM" -gU "$library" 2>&1 | grep "_al_" | head -n 40 || true
    fi
    exit 1
  done
done

if [[ $# -eq 0 ]]; then
  exit 0
fi

app_path="$1"
expected_version="$2"
# Rust resolves this symbol with dlsym, so a successful link alone is insufficient.
exports=$(xcrun dyld_info -exports "$app_path/CarrierLock")
for symbol in \
  _ALGetGrappaToken \
  _al_exploit_write_dir \
  _al_exploit_read_dir \
  _al_exploit_restore_dir \
  _al_exploit_delete_carrier_dir \
  _al_syslog_stream_start \
  _al_device_respring
do
  if ! grep -q "${symbol}$" <<< "$exports"; then
    echo "Archive is missing exported symbol $symbol" >&2
    exit 1
  fi
done
python3 - "$app_path/Info.plist" "$expected_version" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'rb') as file:
    info = plistlib.load(file)
assert info['CFBundleShortVersionString'] == sys.argv[2], 'Archive version mismatch'
assert '_remotepairing-pairable-host._tcp' in info['NSBonjourServices']
assert '_carrierlockprobe._tcp' in info['NSBonjourServices']
assert info['NSLocalNetworkUsageDescription']
assert 'audio' in info['UIBackgroundModes']
print('Archive version, Grappa export and Airlift permissions verified')
PY
