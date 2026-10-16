# Changelog

All notable changes to **CarrierLock** are documented in this file.

## [Unreleased]

### Added

- Pre-write bundle validation: lock targets are checked against the
  on-device `CarrierBundleList.allBundles` before writing, so a typo or a
  stale bundle name can no longer create a dead symlink.

### Fixed

- Corrected the PLMN-to-bundle map: China Unicom is `Unicom_cn` (not
  `China_Unicom`) and China Telecom is `ChinaTelecom_USIM_cn` (not
  `CTC_china`) on modern iOS; added missing PLMNs 46010 (Unicom) and 46012
  (Telecom). The guide doc table was updated to match.
- The "Restore" action now explains the actual limitation (Airlift has no
  delete primitive) and the real remediation paths, instead of pointing to a
  `CarrierSIM` tool that is not shipped.
- Removed the stale `scripts/test-tendies-import.py`, which referenced
  wallpaper-injection helpers deleted from the app.

### Changed

- Renamed the leftover `TendiesEngine` to `AirliftEngine` (class, file, and
  call sites); it only does pairing/VPN connectivity checks.

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
