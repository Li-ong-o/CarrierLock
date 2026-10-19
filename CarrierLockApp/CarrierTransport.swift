import AirliftFFI
import Foundation

nonisolated enum CarrierSIMAction: String, Sendable {
    case status
    case apply
    case restore
    case recover
}

nonisolated struct CarrierDeviceInfo: Sendable, Equatable {
    let identityHash: String
    let name: String
    let model: String
    let hardware: String
    let ios: String
    let build: String
    let activated: Bool

    var summary: String {
        "\(name) · \(model) · iOS \(ios) (\(build))"
    }

    init?(json: [String: Any]) {
        guard let identityHash = json["identity_hash"] as? String,
              let name = json["name"] as? String,
              let model = json["model"] as? String,
              let hardware = json["hardware"] as? String,
              let ios = json["ios"] as? String,
              let build = json["build"] as? String else {
            return nil
        }
        self.identityHash = identityHash
        self.name = name
        self.model = model
        self.hardware = hardware
        self.ios = ios
        self.build = build
        self.activated = (json["activated"] as? Bool) ?? false
    }
}

nonisolated struct CarrierSIMInfo: Sendable, Identifiable, Equatable {
    let slot: String
    let mcc: String
    let mnc: String
    let imsi: String
    let carrier: String
    let version: String

    var id: String { slot }

    var displaySlot: String {
        switch slot {
        case "kOne": "SIM 1"
        case "kTwo": "SIM 2"
        default: slot
        }
    }

    var plmn: String {
        mcc + mnc
    }

    var displayCarrier: String {
        guard !carrier.isEmpty else { return "" }
        return carrier
            .replacingOccurrences(of: "com.apple.", with: "")
    }

    var maskedIMSI: String {
        let characters = Array(imsi)
        guard characters.count >= 10 else { return imsi }
        return String(characters.prefix(5)) + String(repeating: "*", count: 6) + String(characters.suffix(4))
    }

    init?(json: [String: Any]) {
        guard let slot = json["slot"] as? String else { return nil }
        self.slot = slot
        self.mcc = (json["mcc"] as? String) ?? ""
        self.mnc = (json["mnc"] as? String) ?? ""
        self.imsi = (json["imsi"] as? String) ?? ""
        self.carrier = (json["carrier"] as? String) ?? ""
        self.version = (json["version"] as? String) ?? ""
    }
}

nonisolated struct CarrierProfileResult: Sendable, Equatable {
    let slot: String
    let plmn: String
    let expected: String
    let selected: String?
    let verified: Bool

    init?(json: [String: Any]) {
        guard let slot = json["slot"] as? String,
              let plmn = json["plmn"] as? String,
              let expected = json["expected"] as? String else {
            return nil
        }
        self.slot = slot
        self.plmn = plmn
        self.expected = expected
        self.selected = json["selected"] as? String
        self.verified = (json["verified"] as? Bool) ?? false
    }
}

nonisolated struct CarrierSIMResult: Sendable, Equatable {
    let returnCode: Int32
    let rawJSON: String
    let rawError: String?
    let action: String
    let device: CarrierDeviceInfo?
    let sims: [CarrierSIMInfo]
    let profiles: [CarrierProfileResult]
    let imsiLinks: [CarrierIMSILink]
    let catalogVerified: Bool
    let commcenterVerified: Bool
    let needsRecovery: Bool
    let canApply: Bool
    let reason: String?
    let warning: String?
    let message: String?
    let error: Bool
    let rolledBack: Bool
    let ipccInstallationCompleted: Bool?
    let logError: String?

    var isFailure: Bool {
        returnCode == 1 || error
    }

    var isFullyVerified: Bool {
        returnCode == 0 && catalogVerified && commcenterVerified
    }

    init(returnCode: Int32, rawJSON: String, rawError: String?) throws {
        self.returnCode = returnCode
        self.rawJSON = rawJSON
        self.rawError = rawError

        guard !rawJSON.isEmpty,
              let data = rawJSON.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CarrierSIMTransportError.invalidResult(rawError)
        }

        self.action = (object["action"] as? String) ?? ""
        self.device = (object["device"] as? [String: Any]).flatMap(CarrierDeviceInfo.init(json:))
        self.sims = ((object["sims"] as? [[String: Any]]) ?? []).compactMap(CarrierSIMInfo.init(json:))
        self.profiles = ((object["profiles"] as? [[String: Any]]) ?? []).compactMap(CarrierProfileResult.init(json:))
        self.imsiLinks = ((object["imsi_links"] as? [[String: Any]]) ?? []).compactMap(CarrierIMSILink.init(json:))
        self.catalogVerified = Self.boolValue(object["catalog_verified"])
        self.commcenterVerified = Self.boolValue(object["commcenter_verified"])
        self.needsRecovery = Self.boolValue(object["needs_recovery"])
        self.canApply = Self.boolValue(object["can_apply"])
        self.reason = Self.stringValue(object["reason"])
        self.warning = Self.stringValue(object["warning"])
        self.message = Self.stringValue(object["message"])
        self.error = Self.boolValue(object["error"])
        self.rolledBack = Self.boolValue(object["rolled_back"])
        self.ipccInstallationCompleted = object["ipcc_installation_completed"] as? Bool
        self.logError = Self.stringValue(object["log_error"])
    }

    private static func boolValue(_ value: Any?) -> Bool {
        guard let value else { return false }
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return false
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let value = value as? String, !value.isEmpty { return value }
        return nil
    }
}

nonisolated struct CarrierIMSILink: Sendable, Identifiable, Equatable {
    let imsi: String
    let bundle: String

    var id: String { imsi }

    init?(json: [String: Any]) {
        guard let imsi = json["imsi"] as? String else { return nil }
        self.imsi = imsi
        self.bundle = (json["bundle"] as? String) ?? ""
    }
}

nonisolated enum CarrierSIMTransportError: LocalizedError {
    case missingPairingFile
    case missingAssets
    case invalidResult(String?)
    case operationFailed(code: Int32, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingPairingFile:
            "缺少配对文件。请先完成连接引导。"
        case .missingAssets:
            "缺少 CarrierSIM 内置资源 assets.zip。"
        case let .invalidResult(message):
            message ?? "CarrierSIM 返回了无法解析的结果。"
        case let .operationFailed(code, message):
            message ?? "CarrierSIM 操作失败（代码 \(code)）。"
        }
    }
}

final class CarrierSIMTransport: @unchecked Sendable {
    static let shared = CarrierSIMTransport()

    private let queue = DispatchQueue(label: "com.carrier.lock.carriersim.ffi", qos: .userInitiated)

    private init() {}

    func execute(
        action: CarrierSIMAction,
        slots: [String],
        bundle: String,
        assignments: [String: String] = [:]
    ) async throws -> CarrierSIMResult {
        let pairingPath = PairingController.pairingFilePath()
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try Self.executeBlocking(
                        action: action,
                        slots: slots,
                        bundle: bundle,
                        assignments: assignments,
                        pairingPath: pairingPath
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func executeBlocking(
        action: CarrierSIMAction,
        slots: [String],
        bundle: String,
        assignments: [String: String],
        pairingPath: String
    ) throws -> CarrierSIMResult {
        let pairingSize = (try? FileManager.default.attributesOfItem(atPath: pairingPath)[.size] as? Int) ?? 0
        guard pairingSize > 0 else {
            throw CarrierSIMTransportError.missingPairingFile
        }

        guard let assetsURL = Bundle.main.url(forResource: "assets", withExtension: "zip"),
              FileManager.default.fileExists(atPath: assetsURL.path) else {
            throw CarrierSIMTransportError.missingAssets
        }

        let workRoot = try prepareWorkDirectory()
        let requestJSON = try makeRequestJSON(
            action: action,
            slots: slots,
            bundle: bundle,
            assignments: assignments
        )

        var resultPointer: UnsafeMutablePointer<CChar>?
        var errorPointer: UnsafeMutablePointer<CChar>?

        let code = pairingPath.withCString { pairingCString in
            workRoot.path.withCString { workCString in
                assetsURL.path.withCString { assetsCString in
                    requestJSON.withCString { requestCString in
                        cs_execute(
                            pairingCString,
                            workCString,
                            assetsCString,
                            requestCString,
                            CarrierLockLog.ffiCallback,
                            nil,
                            &resultPointer,
                            &errorPointer
                        )
                    }
                }
            }
        }

        let resultText = resultPointer.map { String(cString: $0) } ?? ""
        let errorText = errorPointer.map { String(cString: $0) }
        if let resultPointer { al_string_free(resultPointer) }
        if let errorPointer { al_string_free(errorPointer) }

        return try CarrierSIMResult(
            returnCode: code,
            rawJSON: resultText,
            rawError: errorText
        )
    }

    private nonisolated static func makeRequestJSON(
        action: CarrierSIMAction,
        slots: [String],
        bundle: String,
        assignments: [String: String]
    ) throws -> String {
        var object: [String: Any] = [
            "action": action.rawValue,
            "bundle": bundle,
            "slots": slots,
        ]
        if action == .apply, !assignments.isEmpty {
            object["assignments"] = assignments
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw CarrierSIMTransportError.invalidResult(nil)
        }
        return text
    }

    private nonisolated static func prepareWorkDirectory() throws -> URL {
        let fileManager = FileManager.default
        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let rootURL = supportURL
            .appendingPathComponent("CarrierLock", isDirectory: true)
            .appendingPathComponent("CarrierSIM", isDirectory: true)

        try fileManager.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excludedURL = rootURL
        try? excludedURL.setResourceValues(values)
        return rootURL
    }
}
