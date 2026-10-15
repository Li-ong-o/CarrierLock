import AirliftFFI
import Foundation

/// Serializes the blocking AirLift calls and moves carrier-bundle payloads
/// across the FFI boundary. Reuses the AirTraffic sandbox escape wired into
/// the vendored AirliftFFI, but targets the Carrier Bundles Overlay.
actor CarrierTransport {
    static let shared = CarrierTransport()

    /// Carrier bundle directory CommCenter scans before falling back to the
    /// read-only system store.
    private static let targetDirectory = "/var/mobile/Library/Carrier Bundles/iPhone"

    struct Payload: Sendable {
        let name: String
        /// When non-nil the staged entry is a symlink with this destination
        /// instead of a regular file. AirTraffic preserves symlinks when the
        /// host staging tree contains them.
        var linkTarget: String?
    }

    func readFile(path: String, pairingPath: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try Self.readFileSync(path: path, pairingPath: pairingPath)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func write(files: [Payload], pairingPath: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
        try Self.writeSync(files: files, pairingPath: pairingPath)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func writeSync(files: [Payload], pairingPath: String) throws {

        let stagingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "CarrierLock-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }

        var hasSymlink = false
        for file in files {
            let url = stagingDirectory.appending(path: file.name)
            if let linkTarget = file.linkTarget {
                try FileManager.default.createSymbolicLink(
                    atPath: url.path,
                    withDestinationPath: linkTarget
                )
                hasSymlink = true
            } else {
                try Data().write(to: url, options: .atomic)
            }
        }

        // AirLift's source scanner ignores directories that contain only
        // symlinks and reports "no valid files found". A tiny companion
        // file lets the payload pass stage verification without changing
        // the carrier bundle link itself.
        if hasSymlink {
            let marker = stagingDirectory.appending(path: "_carrierlock.marker")
            try Data("carrierlock".utf8).write(to: marker, options: .atomic)
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
}
