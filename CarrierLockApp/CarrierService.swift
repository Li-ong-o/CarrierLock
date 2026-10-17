import Combine
import Foundation
import UIKit

enum CarrierError: LocalizedError {
    case unsupported
    case pairingRequired
    case invalidIMSI(String)
    case invalidBundle(String)
    case symlinkFailed(String)
    case transportFailed(String)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            String(localized: "This device or system version is not supported.")
        case .pairingRequired:
            String(localized: "Pair this iPhone and connect LocalDevVPN before locking the carrier profile.")
        case .invalidIMSI(let value):
            String(format: String(localized: "Invalid IMSI: %@"), value)
        case .invalidBundle(let name):
            String(format: String(localized: "Invalid bundle name: %@"), name)
        case .symlinkFailed(let reason):
            String(format: String(localized: "Could not build carrier bundle link: %@"), reason)
        case .transportFailed(let reason):
            String(format: String(localized: "AirLift write failed: %@"), reason)
        case .connectionFailed(let reason):
            String(format: String(localized: "Cannot reach the AirLift tunnel. Make sure Wi-Fi is connected and LocalDevVPN is active, then retry.\n\nTechnical details: %@"), reason)
        }
    }
}

@MainActor
final class CarrierService: ObservableObject {
    enum LockMode: Equatable {
        case idle
        case locking
        case locked(links: [String: String])
        case failed(String)
    }

    @Published private(set) var mode: LockMode = .idle
    @Published private(set) var bundleName: String = "CMCC_cn"
    @Published var customBundlesByIMSI: [String: String] = [:]
    @Published private(set) var detectedIMSIs: [String] = []
    @Published private(set) var busyMessage: String?
    @Published private(set) var needsAirliftSetup = false
    @Published private(set) var detection: CarrierDetection?
    @Published private(set) var verifiedLinks: [String: String] = [:]
    @Published private(set) var verifyMessage: String?

    static let shared = CarrierService()
    private init() {
        // Carrier detection is informational only. IMSI and bundle are
        // intentionally left for the user to choose; MEP devices often
        // expose the wrong IMSI through the public APIs.
        detectCarrier()
    }

    func detectCarrier() {
        detection = CarrierDetectionService.detect()
    }

    var monitoredBundleName: String {
        if case .locked(let links) = mode {
            return links.values.sorted().first ?? bundleName
        }
        return bundleName
    }

    var selectedIMSIs: [String] {
        detectedIMSIs
    }

    func bundle(forIMSI imsi: String) -> String {
        if let custom = customBundlesByIMSI[imsi]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }

        if let prefix = CarrierDetectionService.prefixCandidate(for: imsi),
           let automatic = CarrierDetectionService.bundle(for: prefix) {
            return automatic
        }

        return bundleName
    }

    func lock() async {
        guard mode != .locking else { return }
        CarrierLockLog.shared.append("[锁定] 开始锁定运营商配置")
        do {
            try await run()
            CarrierLockLog.shared.append("[锁定] 成功：\(modeSummary)")
        } catch {
            let normalizedError = Self.normalizeTransportError(error)
            CarrierLockLog.shared.append("[锁定] 失败：\(normalizedError.localizedDescription)")
            CarrierLockLog.shared.append("[锁定] 原始错误：\(error.localizedDescription)")
            mode = .failed(normalizedError.localizedDescription)
            needsAirliftSetup = shouldOfferAirliftSetup(for: normalizedError)
        }
    }

    func restore() async {
        guard mode != .locking else { return }
        CarrierLockLog.shared.append("[恢复] 开始移除 IMSI 锁定链接")
        do {
            let pairingPath = PairingController.pairingFilePath()
            let size = (try? FileManager.default.attributesOfItem(atPath: pairingPath)[.size] as? Int) ?? 0
            guard size > 0 else { throw CarrierError.pairingRequired }

            busyMessage = String(localized: "正在移除 IMSI 锁定链接…")
            mode = .locking
            defer { busyMessage = nil }

            guard let json = try await CarrierTransport.shared.restoreDefault(pairingPath: pairingPath),
                  let data = json.data(using: .utf8),
                  let result = try? JSONDecoder().decode(RestoreResult.self, from: data),
                  result.ok else {
                throw CarrierError.transportFailed("AirLift restore returned no result.")
            }

            let links = try await readLockLinks(pairingPath: pairingPath)
            guard links.isEmpty else {
                throw CarrierError.transportFailed("Restore verification found \(links.count) IMSI link(s).")
            }

            verifiedLinks = [:]
            verifyMessage = result.changed
                ? String(format: String(localized: "已移除 %d 个 IMSI 链接，并完成二次校验。"), result.removed)
                : String(localized: "当前已经是默认配置，未发现 IMSI 链接。")
            CarrierLockLog.shared.append("[恢复] 成功：\(verifyMessage ?? "")")
            mode = .idle
        } catch {
            let normalizedError = Self.normalizeTransportError(error)
            CarrierLockLog.shared.append("[恢复] 失败：\(normalizedError.localizedDescription)")
            CarrierLockLog.shared.append("[恢复] 原始错误：\(error.localizedDescription)")
            mode = .failed(normalizedError.localizedDescription)
            needsAirliftSetup = shouldOfferAirliftSetup(for: normalizedError)
        }
    }

    func lockWithFallback() async {
        guard mode != .locking else { return }
        mode = .failed(
            String(localized: "iOS App 端写入受限，请使用电脑 CarrierSIM 完成锁定。\n\n命令：CarrierSIM --bundle CMCC_cn --sims 1")
        )
    }

    func checkLockStatus() async {
        guard mode != .locking else { return }
        CarrierLockLog.shared.append("[检查] 开始读取运营商配置目录")
        verifyMessage = nil
        verifiedLinks = [:]

        let pairingPath = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: pairingPath)[.size] as? Int) ?? 0
        guard size > 0 else {
            verifyMessage = String(localized: "缺少配对文件，无法检查锁定状态。")
            CarrierLockLog.shared.append("[检查] 失败：缺少配对文件")
            return
        }

        busyMessage = String(localized: "正在读取运营商配置目录…")
        defer { busyMessage = nil }

        do {
            let links = try await readLockLinks(pairingPath: pairingPath)
            verifiedLinks = links
            verifyMessage = links.isEmpty
                ? String(localized: "未检测到 IMSI 锁定链接。")
                : String(format: String(localized: "检测到 %d 个 IMSI 已锁定。"), links.count)
            CarrierLockLog.shared.append("[检查] 成功：\(verifyMessage ?? "")")
            for imsi in links.keys.sorted() {
                CarrierLockLog.shared.append("[检查] \(imsi) -> \(links[imsi] ?? "未知目标")")
            }
        } catch {
            let normalizedError = Self.normalizeTransportError(error)
            verifyMessage = String(format: String(localized: "检查失败：%@"), normalizedError.localizedDescription)
            CarrierLockLog.shared.append("[检查] 失败：\(normalizedError.localizedDescription)")
            CarrierLockLog.shared.append("[检查] 原始错误：\(error.localizedDescription)")
        }
    }

    struct RestoreResult: Codable {
        let ok: Bool
        let changed: Bool
        let removed: Int
        let before: Int
        let after: Int
    }

    private func readLockLinks(pairingPath: String) async throws -> [String: String] {
        guard let json = try await CarrierTransport.shared.readDir(
            path: CarrierTransport.targetDirectory,
            pairingPath: pairingPath
        ) else {
            throw CarrierError.transportFailed("AirLift read dir returned no JSON.")
        }
        return try Self.parseIMSILinks(from: json)
    }

    nonisolated static func normalizeTransportError(_ error: Error) -> CarrierError {
        guard let carrierError = error as? CarrierError else {
            return .transportFailed(error.localizedDescription)
        }

        if case .transportFailed(let reason) = carrierError,
           reason.localizedCaseInsensitiveContains("RemoteXPC timed out")
            || reason.localizedCaseInsensitiveContains("loopback VPN") {
            return .connectionFailed(reason)
        }

        return carrierError
    }

    /// Parses the JSON tree from al_exploit_read_dir and returns IMSI symlinks
    /// (15-digit numeric names) mapped to their resolved bundle names.
    nonisolated static func parseIMSILinks(from json: String) throws -> [String: String] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONDecoder().decode(DirNode.self, from: data) else {
            throw CarrierError.transportFailed("Could not parse directory JSON.")
        }
        var result: [String: String] = [:]
        collectIMSILinks(node: root, into: &result)
        return result
    }

    nonisolated private static func collectIMSILinks(node: DirNode, into result: inout [String: String]) {
        let name = URL(fileURLWithPath: "/" + node.path).lastPathComponent
        if node.type == "symlink",
           name.count == 15,
           name.allSatisfy(\.isNumber) {
            result[name] = bundleName(fromTarget: node.target ?? "")
        }
        if let children = node.children {
            for child in children {
                collectIMSILinks(node: child, into: &result)
            }
        }
    }

    nonisolated private static func bundleName(fromTarget target: String) -> String {
        guard let last = target.split(separator: "/").last else { return "未知目标" }
        return last.hasSuffix(".bundle") ? String(last.dropLast(".bundle".count)) : String(last)
    }

    nonisolated private struct DirNode: Codable {
        let path: String
        let type: String
        let size: Int?
        let target: String?
        let children: [DirNode]?
    }

    func dismissFailure() {
        if case .failed = mode {
            mode = .idle
        }
    }

    func toggleDetectedIMSI(_ value: String) {
        guard let index = detectedIMSIs.firstIndex(of: value) else { return }
        detectedIMSIs.remove(at: index)
    }

    func selectDetectedIMSI(_ value: String) {
        guard value.count == 15, value.allSatisfy(\.isNumber),
              !detectedIMSIs.contains(value) else { return }
        detectedIMSIs.append(value)
        detectedIMSIs.sort()
    }

    private func run() async throws {
        guard SystemCompatibility.isSupported else {
            throw CarrierError.unsupported
        }

        let pairingPath = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: pairingPath)[.size] as? Int) ?? 0
        guard size > 0 else {
            throw CarrierError.pairingRequired
        }

        let imsis = selectedIMSIs
        guard !imsis.isEmpty else {
            throw CarrierError.invalidIMSI("(empty)")
        }

        let invalidIMSIs = imsis.filter { $0.count != 15 || !$0.allSatisfy(\.isNumber) }
        guard invalidIMSIs.isEmpty else {
            throw CarrierError.invalidIMSI(invalidIMSIs.joined(separator: ", "))
        }

        let links = Dictionary(uniqueKeysWithValues: imsis.map { imsi in
            (imsi, bundle(forIMSI: imsi))
        })
        let invalidBundles = links.values.filter {
            $0.isEmpty || !$0.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
        }
        guard invalidBundles.isEmpty else {
            throw CarrierError.invalidBundle(invalidBundles.first ?? "(empty)")
        }

        busyMessage = String(localized: "Preparing carrier bundle link…")
        mode = .locking
        defer { busyMessage = nil }

        for (index, link) in links.sorted(by: { $0.key < $1.key }).enumerated() {
            let payload = try buildSymlinkPayload(
                name: link.key,
                target: "/System/Library/Carrier Bundles/iPhone/\(link.value).bundle"
            )
            busyMessage = String(
                format: String(localized: "正在写入 IMSI 链接 %d/%d：%@ -> %@…"),
                index + 1,
                links.count,
                link.key,
                link.value
            )
            // AirliftProbe's verified path stages exactly one IMSI symlink per
            // AirTraffic transaction. Keep that shape even for multi-SIM locks.
            try await CarrierTransport.shared.write(files: [payload], pairingPath: pairingPath)
        }

        let verified = try await readLockLinks(pairingPath: pairingPath)
        let missing = links.filter { verified[$0.key] != $0.value }
        guard missing.isEmpty else {
            throw CarrierError.symlinkFailed("written links not found in readback: \(missing.keys.sorted().joined(separator: ", "))")
        }

        verifiedLinks = verified
        verifyMessage = String(format: String(localized: "写入完成，%d 个 IMSI 链接已通过目录枚举验证。"), verified.count)
        mode = .locked(links: links)
    }

    /// Builds a symlink payload; the transport stages the real link so
    /// AirTraffic's recursive copy preserves it in the Overlay.
    private func buildSymlinkPayload(name: String, target: String) throws -> CarrierTransport.Payload {
        CarrierTransport.Payload(name: name, linkTarget: target)
    }

    private func shouldOfferAirliftSetup(for error: Error) -> Bool {
        guard let error = error as? CarrierError else { return false }
        switch error {
        case .pairingRequired, .transportFailed, .connectionFailed:
            return true
        case .unsupported, .invalidIMSI, .invalidBundle, .symlinkFailed:
            return false
        }
    }

    private var modeSummary: String {
        switch mode {
        case .locked(let links):
            links.sorted(by: { $0.key < $1.key })
                .map { "\($0.key) -> \($0.value)" }
                .joined(separator: ", ")
        default:
            "完成"
        }
    }
}
