# Changelog

All notable changes to **CarrierLock** are documented in this file.

## [Unreleased]

### Added

- Multi-bundle and multi-IMSI monitoring support (`monitoredBundleNames: Set<String>`), preventing false `.mismatch` status on dual-SIM devices.
- Pre-write bundle validation: lock targets are checked against `CarrierBundleCatalog.allSet` with case-insensitive canonical fallback (`CarrierBundleCatalog.canonicalName`).
- Added China Broadcasting Network (CBN / 中国广电, PLMN 46015 `CBN_cn`) and aligned all 13 international PLMN bundle mappings.
- Respring state persistence via `UserDefaults` to restore locked IMSIs and status seamlessly after SpringBoard restarts.
- Strict pairing file validation (`hasValidPairingFile()` / `isValidPairingData()`), preventing corrupt or 0-byte pairing files and validating Plist structure on import.
- Active session UUID token isolation in `PairingController` to eliminate background C thread races on re-pairing and cancellation.

### Fixed

- Corrected all PLMN-to-bundle and preferred bundle entries against on-device `CarrierBundleList.allBundles` (e.g. `Unicom_cn`, `ChinaTelecom_USIM_cn`, `ATT_US`, `TMobile_US`, `Verizon_LTE_US`, `Vodafone_uk`, `Orange_France`).
- Fixed sheet dismiss bug in `CarrierView`: removed unintentional automatic `service.lock()` execution when dismissing `AirliftSetupView`.
- Fixed `CarrierMonitor` `.listening` state transition, eliminating infinite "Connecting to syslog..." spinner and warnings.
- Fixed `CarrierBundlePickerSheet` duplicate item IDs and removed forced uppercase input autocapitalization.
- Fixed `KeepAlive.startAudio()` guard error branches incorrectly locking `audioRunning = true`.
- Improved `isLikelyRealIMSI` heuristic to avoid false positives on legitimate SIM cards with adjacent double or sequential digits.
- Corrected `statusCard` to display locked IMSI mapping details (`imsiDetail`).
- Corrected LocalNetwork usage description in project configurations from old call recording disclosure tone text.
- Cleaned up obsolete recording tone and Telegram localization strings.

### Changed

- Renamed the leftover `TendiesEngine` to `AirliftEngine` (class, file, and call sites).
- Unified project-level deployment target to iOS 18.0 and corrected product name to `CarrierLock`.

### Removed

- Removed unused `CarrierTransport.readFile` / `readFileSync` dead code and deleted `scripts/airlift-read-file.patch`.
- Removed stale `scripts/test-tendies-import.py`.
- Removed unused `sendRespringSignal` from `AirliftEngine`.
- Removed leftover call recording sound icon asset.

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
