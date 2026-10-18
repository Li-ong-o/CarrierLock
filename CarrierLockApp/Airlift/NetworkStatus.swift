import Darwin
import Foundation

/// Reads local network state from the interface table. LocalDevVPN changes the
/// default route, so this is more reliable than NWPathMonitor for setup gates.
enum NetworkStatus {
    struct Interface {
        let name: String
        let ipv4: String
        let isUp: Bool
        let isRunning: Bool
    }

    static func interfaces() -> [Interface] {
        var result: [Interface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            guard let ipv4 = numericHost(addr) else { continue }
            let flags = current.pointee.ifa_flags
            result.append(
                Interface(
                    name: String(cString: current.pointee.ifa_name),
                    ipv4: ipv4,
                    isUp: flags & UInt32(IFF_UP) != 0,
                    isRunning: flags & UInt32(IFF_RUNNING) != 0
                )
            )
        }
        return result
    }

    private static func numericHost(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard getnameinfo(addr, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
            return nil
        }
        return String(cString: host)
    }

    static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    static var wifiActive: Bool {
        interfaces().contains { $0.name == "en0" && $0.isUp && $0.isRunning }
    }

    static var tunnelInterfaceAddress: String? {
        interfaces().first { isTunnelInterface($0.name) && $0.isUp && $0.isRunning }?.ipv4
    }
}
