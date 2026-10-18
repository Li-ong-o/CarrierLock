# Changelog

All notable changes to **CarrierLock** are documented in this file.

## [Unreleased]

### Added

- Complete Rust source for the vendored Airlift FFI static library, plus an
  in-repository build script.
- Multi-IMSI carrier overlay locking. One operation can write overlay links for
  a real SIM IMSI, adapter-reported IMSIs, both dual-SIM lines, and additional
  candidates.

## [1.0.5] - 2026-10-18

### Added

- AirBeep-style on-device pairing flow and live network status UI.
- Carrier Overlay reset action in the About page.
- Open-source repository link in the About page.

### Changed

- About page wording now explains reasons for activation prompts.
- Airlift FFI is now built from source stored inside this repository.
- Version is now 1.0.5 (build 11).

## [1.0.1] - 2026-10-15

### Added

- Chinese on-device guide for RPPairing and LocalDevVPN setup.
- Manual pairing-file import for devices that cannot complete local pairing.
- CommCenter log listening to capture IMSI candidates and loaded carrier bundles.
- Carrier-bundle picker with search and custom bundle input.
- IMSI confirmation warning before writing the overlay link.
- Stop-listening control for the CommCenter monitor.
- Carrier-bundle locking explanation and clear limits on unsupported behavior.
- Legal and personal-responsibility disclaimer in the app and README.

### Changed

- Supported target range is iOS/iPadOS 18.0 - 27.2 beta 2 (24B5089g).
- Minimum deployment target is iOS 18.0.
- Regional map lookups such as `China_Map` are excluded from carrier-bundle
  match decisions.
- The About page no longer promotes external community channels.

### Removed

- Unstable direct Overlay symlink probing. Verification now relies on
  CommCenter bundle-selection logs.
- Unused image assets and temporary development files.
