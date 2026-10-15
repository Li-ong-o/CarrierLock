import Foundation

/// Supported system range follows the on-device Airlift/LocalDevVPN path:
/// iOS/iPadOS 18.0 through 27.2 beta 2 (24B5089g). iOS 18.1 and below may
/// need a pairing file generated on a computer and imported manually.
enum SystemCompatibility {
    static var isSupported: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        guard version.majorVersion >= 18 else { return false }
        if version.majorVersion > 27 { return false }
        if version.majorVersion == 27 {
            if version.minorVersion > 2 { return false }
            if version.minorVersion == 2, version.patchVersion > 0 { return false }
        }
        return true
    }

    static var supportedRangeDescription: String {
        String(localized: "iOS 18.0 - 27.2 beta 2 (24B5089g)")
    }
}
