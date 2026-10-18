import AirliftFFI
import Foundation

/// Serializes the blocking AirLift calls and moves carrier-bundle payloads
/// across the FFI boundary. Reuses the AirTraffic sandbox escape wired into
/// the vendored AirliftFFI, but targets the Carrier Bundles Overlay.
actor CarrierTransport {
    static let shared = CarrierTransport()

    /// AirTraffic can temporarily stop producing AssetManifest after a failed
    /// transaction. A short global cooldown prevents immediate retries from
    /// compounding that state.
    private static let failureCooldown: TimeInterval = 5
    private static let cooldownLock = NSLock()
    private static var cooldownUntil: Date?

    /// Carrier bundle directory CommCenter scans before falling back to the
    /// read-only system store.
    static let targetDirectory = "/var/mobile/Library/Carrier Bundles/iPhone"

    /// CarrierSIM installs an unrelated official IPCC first so CommCenter
    /// recreates/refreshes the user carrier-bundle overlay on clean devices.
    private static let carrierTriggerResource = Bundle.main.url(
        forResource: "Swisscom_ch",
        withExtension: "ipcc"
    )

    struct Payload: Sendable {
        let name: String
        /// When non-nil the staged entry is a symlink with this destination
        /// instead of a regular file. AirTraffic preserves symlinks when the
        /// host staging tree contains them.
        var linkTarget: String?
    }

    struct DirEntry: Sendable {
        let path: String
        let type: String
        let size: Int
        let target: String?
        let children: [DirEntry]?
    }

    func readFile(path: String, pairingPath: String) async throws -> Data? {
        try Self.ensureCooldownPassed()
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.readFileSync(path: path, pairingPath: pairingPath)
                    Self.clearCooldown()
                    continuation.resume(returning: result)
                } catch {
                    Self.recordAirTrafficFailure(error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func write(files: [Payload], pairingPath: String) async throws {
        try Self.ensureCooldownPassed()
        try await installCarrierTrigger(pairingPath: pairingPath)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Self.writeSync(files: files, pairingPath: pairingPath)
                    Self.clearCooldown()
                    continuation.resume(returning: ())
                } catch {
                    Self.recordAirTrafficFailure(error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func readDir(path: String, pairingPath: String) async throws -> String? {
        try Self.ensureCooldownPassed()
        Self.logTriggerDiagnostics()
        try await installCarrierTrigger(pairingPath: pairingPath)
        var lastError: Error?
        for attempt in 1...3 {
            do {
                return try await readDirOnce(path: path, pairingPath: pairingPath)
            } catch {
                lastError = error
                if attempt < 3 {
                    CarrierLockLog.shared.append("[目录读取] 第 \(attempt) 次失败，5 秒后继续清理 AirTraffic/Books/Media 残留")
                    try await Task.sleep(for: .seconds(Self.failureCooldown))
                    CarrierLockLog.shared.append("[目录读取] 开始第 \(attempt + 1) 次目录事务")
                }
            }
        }
        throw lastError ?? CarrierError.transportFailed("AirLift read dir failed.")
    }

    private func readDirOnce(path: String, pairingPath: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.readDirSync(path: path, pairingPath: pairingPath)
                    Self.clearCooldown()
                    continuation.resume(returning: result)
                } catch {
                    Self.recordAirTrafficFailure(error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func restoreDefault(pairingPath: String) async throws -> String? {
        try Self.ensureCooldownPassed()
        try await installCarrierTrigger(pairingPath: pairingPath)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.restoreDefaultSync(pairingPath: pairingPath)
                    Self.clearCooldown()
                    continuation.resume(returning: result)
                } catch {
                    Self.recordAirTrafficFailure(error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cooldownSecondsRemaining() async -> Int {
        Self.cooldownSecondsRemainingSync()
    }

    private static func ensureCooldownPassed() throws {
        let seconds = cooldownSecondsRemainingSync()
        guard seconds > 0 else { return }
        CarrierLockLog.shared.append("[AirTraffic] 全局操作锁冷却中：还需 \(seconds) 秒")
        throw CarrierError.transportFailed(
            String(format: String(localized: "AirTraffic 刚刚操作失败，请等待 %d 秒后再试。"), seconds)
        )
    }

    private static func recordAirTrafficFailure(_ error: Error) {
        cooldownLock.lock()
        cooldownUntil = Date().addingTimeInterval(failureCooldown)
        cooldownLock.unlock()
        CarrierLockLog.shared.append("[AirTraffic] 操作失败，启用 \(Int(failureCooldown)) 秒全局冷却")
        CarrierLockLog.shared.append("[AirTraffic] 失败原因：\(error.localizedDescription)")
    }

    private static func clearCooldown() {
        cooldownLock.lock()
        cooldownUntil = nil
        cooldownLock.unlock()
    }

    private static func cooldownSecondsRemainingSync() -> Int {
        cooldownLock.lock()
        let remaining = cooldownUntil?.timeIntervalSinceNow ?? 0
        cooldownLock.unlock()
        return max(0, Int(remaining.rounded(.up)))
    }

    private static func writeSync(files: [Payload], pairingPath: String) throws {
        let stagingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "CarrierLock-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }

        for file in files {
            let url = stagingDirectory.appending(path: file.name)
            if let target = file.linkTarget {
                try FileManager.default.createSymbolicLink(
                    atPath: url.path,
                    withDestinationPath: target
                )
            } else {
                try Data().write(to: url, options: .atomic)
            }
        }

        var outputError: UnsafeMutablePointer<CChar>?
        let result = pairingPath.withCString { pairingCString in
            stagingDirectory.path.withCString { sourceCString in
                Self.targetDirectory.withCString { targetCString in
                    al_exploit_write_dir(
                        pairingCString,
                        sourceCString,
                        targetCString,
                        CarrierLockLog.ffiCallback,
                        nil,
                        &outputError
                    )
                }
            }
        }

        let message = outputError.map { String(cString: $0) }
        if let outputError { al_string_free(outputError) }

        guard result == 0 else {
            throw CarrierError.transportFailed(message ?? "AirLift write failed (\(result)).")
        }
    }

    private static func restoreDefaultSync(pairingPath: String) throws -> String? {
        var outJson: UnsafeMutablePointer<CChar>?
        var outError: UnsafeMutablePointer<CChar>?
        let result = pairingPath.withCString { pairingCString in
            Self.targetDirectory.withCString { pathCString in
                al_exploit_restore_dir(
                    pairingCString,
                    pathCString,
                    CarrierLockLog.ffiCallback,
                    nil,
                    &outJson,
                    &outError
                )
            }
        }

        let message = outError.map { String(cString: $0) }
        if let outError { al_string_free(outError) }

        guard result == 0 else {
            throw CarrierError.transportFailed(message ?? "AirLift restore failed (\(result)).")
        }
        guard let outJson else { return nil }
        let json = String(cString: outJson)
        al_string_free(outJson)
        return json
    }

    private static func readFileSync(path: String, pairingPath: String) throws -> Data? {
        var bytes: UnsafeMutablePointer<UInt8>?
        var length = 0
        var outputError: UnsafeMutablePointer<CChar>?
        let result = pairingPath.withCString { pairingCString in
            path.withCString { pathCString in
                al_exploit_read_file(
                    pairingCString,
                    pathCString,
                    CarrierLockLog.ffiCallback,
                    nil,
                    &bytes,
                    &length,
                    &outputError
                )
            }
        }

        let message = outputError.map { String(cString: $0) }
        if let outputError { al_string_free(outputError) }
        defer {
            if let bytes, length > 0 {
                al_bytes_free(bytes, length)
            }
        }

        guard result == 0 else {
            throw CarrierError.transportFailed(message ?? "AirLift read failed (\(result)).")
        }
        guard let bytes else { return nil }
        return Data((0..<length).map { bytes[$0] })
    }

    private static func readDirSync(path: String, pairingPath: String) throws -> String? {
        var outJson: UnsafeMutablePointer<CChar>?
        var outError: UnsafeMutablePointer<CChar>?
        let result = pairingPath.withCString { pairingCString in
            path.withCString { pathCString in
                al_exploit_read_dir(
                    pairingCString,
                    pathCString,
                    CarrierLockLog.ffiCallback,
                    nil,
                    &outJson,
                    &outError
                )
            }
        }

        let message = outError.map { String(cString: $0) }
        if let outError { al_string_free(outError) }

        guard result == 0 else {
            throw CarrierError.transportFailed(message ?? "AirLift read dir failed (\(result)).")
        }
        guard let outJson else { return nil }
        let json = String(cString: outJson)
        al_string_free(outJson)
        return json
    }

    private func installCarrierTrigger(pairingPath: String) async throws {
        guard let triggerURL = Self.carrierTriggerResource else {
            CarrierLockLog.shared.append("[初始化] 未找到 Carrier 触发器 Swisscom_ch.ipcc，跳过")
            return
        }

        CarrierLockLog.shared.append("[初始化] 安装 Carrier 触发器 \(triggerURL.lastPathComponent)")
        let start = Date()
        do {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var outputError: UnsafeMutablePointer<CChar>?
                    let result = pairingPath.withCString { pairingCString in
                        triggerURL.path.withCString { ipccCString in
                            al_install_carrier_trigger(
                                pairingCString,
                                ipccCString,
                                CarrierLockLog.ffiCallback,
                                nil,
                                &outputError
                            )
                        }
                    }
                    let message = outputError.map { String(cString: $0) }
                    if let outputError { al_string_free(outputError) }
                    if result == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CarrierError.transportFailed(
                            message ?? "Carrier trigger installation failed (\(result))."
                        ))
                    }
                }
            }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            CarrierLockLog.shared.append("[初始化] Carrier 触发器完成，耗时 \(ms) ms")
        } catch {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            CarrierLockLog.shared.append("[初始化] Carrier 触发器失败 (耗时 \(ms) ms)：\(error.localizedDescription)")
            throw error
        }
    }

    private static func logTriggerDiagnostics() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        CarrierLockLog.shared.append("""
        [初始化] CarrierLock \(version) (\(build)); \
        IPCC=\(carrierTriggerResource != nil ? "present" : "missing"); \
        FFI trigger=compiled
        """)
    }

}
