# Airlift FFI Rust Source

This directory contains the complete source for the `libairlift_ffi.a`
static library shipped in `Vendor/CarrierLock/AirliftFFI.xcframework`.

Build it from the repository root with:

```bash
scripts/build-airlift-xcframework.sh
```

The build produces the iOS and iOS-simulator static libraries, packages them as
`AirliftFFI.xcframework`, and updates the vendored framework and SHA-256
manifest used by the iOS app.

The Airlift FFI code is derived from
[AirCard-iOS](https://github.com/mak5er/AirCard-iOS) and is MIT licensed. The
vendored `idevice` and `idevice-ffi` crates retain their upstream source and
license files.
