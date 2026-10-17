# CarrierLock

> 🌍 **Languages:** English | [简体中文 (Simplified Chinese)](./README_zh-CN.md)

CarrierLock is an iOS utility for users who maintain their own carrier configuration. It writes carrier-bundle overlay links for a selected IMSI through Airlift so CommCenter can match a local carrier bundle, reducing repeated configuration lookups and activation prompts in SIM-adapter scenarios.


## Features

- On-device guidance for pairing and the LocalDevVPN loopback connection.
- Log listening to capture IMSI candidates from CommCenter events.
- Multi-IMSI locking for real SIM IMSIs, adapter-reported IMSIs, and dual-SIM lines.
- Carrier-bundle selection, including a custom bundle option.
- IMSI confirmation before writing the overlay link.
- English and Simplified Chinese UI.

## How it works

CarrierLock listens for CommCenter bundle-selection events, helps you identify the IMSI being used, and writes an overlay link such as `<IMSI> -> /System/Library/Carrier Bundles/iPhone/<Bundle>.bundle` through Airlift. Multi-IMSI mode writes several candidate links in one operation. When CommCenter scans carrier bundles again, it matches the local overlay first and loads the selected bundle.

Multi-IMSI locking can cover dual-SIM lines and adapters that temporarily report different IMSIs. It cannot prevent an adapter from switching IMSIs, repair activation state, or change baseband capabilities.

## Requirements

- A physical iPhone or iPad running one of the supported iOS/iPadOS releases:
  - **iOS/iPadOS 18.0 – 27.2 B2**
- Xcode 27 or newer for local builds.
- The provided GitHub Actions workflow builds an unsigned IPA in the cloud.

> CarrierLock relies on non-public system behavior. Compatibility can change between iOS releases. Always confirm that the IMSI belongs to the intended SIM before locking a carrier bundle.

## Disclaimer

CarrierLock is provided for personal learning, research, and maintenance of devices that you own or are authorized to access. Downloading, installing, or using it is voluntary and entirely at your own risk. You are responsible for complying with local laws, carrier terms, and applicable platform agreements.

The software is provided "as is", without any express or implied warranty. The developers are not responsible for device damage, data loss, service interruption, account risk, legal issues, or other consequences arising from its use.

## Build

Open `carrierlock.xcodeproj`, select the `carrierlock` target, set your signing team, and build to a physical device.

For an unsigned IPA, run the `Release unsigned IPA` workflow in GitHub Actions. The artifact is named `carrierlock-v<version>-unsigned.ipa`.

## Credits

- [AirliftSilence](https://github.com/YiHoooong/AirliftSilence) for the silent tone assets and replacement research.
- [airlift](https://github.com/0xjohnnydev/airlift) by 0xjohnny for the AirTraffic and Airlock research retained in the project dependencies.
- [Placard](https://github.com/frs0n/placard) contributors for the original iOS project structure and container-access implementation.

## License

CarrierLock is released under the [GNU General Public License v3.0](LICENSE).
