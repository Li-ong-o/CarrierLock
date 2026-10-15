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
        }
    }
}

@MainActor
final class CarrierService: ObservableObject {
    enum LockMode: Equatable {
        case idle
        case locking
        case locked(bundle: String, imsi: String)
        case failed(String)
    }

    @Published private(set) var mode: LockMode = .idle
    @Published var bundleName: String = "CMCC_cn"
    @Published var imsi: String = ""
    @Published private(set) var busyMessage: String?
    @Published private(set) var needsAirliftSetup = false
    @Published private(set) var detection: CarrierDetection?

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
        if case .locked(let bundle, _) = mode { return bundle }
        return bundleName
    }

    func lock() async {
        guard mode != .locking else { return }
        do {
            try await run()
        } catch {
            mode = .failed(error.localizedDescription)
            needsAirliftSetup = shouldOfferAirliftSetup(for: error)
        }
    }

    func restore() async {
        // Airlift FFI has no delete primitive in this build. Keep the failure
        // explicit so the user is not misled into thinking restore worked.
        mode = .failed(
            String(localized: "Restore is not yet supported in the iOS app. Use CarrierSIM --restore from your Mac.")
        )
    }

    func dismissFailure() {
        if case .failed = mode {
            mode = .idle
        }
    }

    func applyDetectedIMSI(_ value: String) {
        imsi = value
        if let mccMnc = CarrierDetectionService.prefixCandidate(for: value) {
            if let bundle = CarrierDetectionService.bundle(for: mccMnc) {
                bundleName = bundle
            } else {
                detection = CarrierDetection(
                    imsi: value,
                    mcc: String(value.prefix(3)),
                    mnc: String(value.dropFirst(3).prefix(mccMnc.count - 3)),
                    bundleName: bundleName,
                    source: .carrierInfo
                )
            }
        }
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

        let imsi = imsi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imsi.count == 15, imsi.allSatisfy({ $0.isNumber }) else {
            throw CarrierError.invalidIMSI(imsi.isEmpty ? "(empty)" : imsi)
        }

        let bundle = bundleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundle.isEmpty, bundle.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            throw CarrierError.invalidBundle(bundle)
        }

        busyMessage = String(localized: "Preparing carrier bundle link…")
        mode = .locking
        defer { busyMessage = nil }

        let linkTarget = "/System/Library/Carrier Bundles/iPhone/\(bundle).bundle"
        let payload = try buildSymlinkPayload(name: imsi, target: linkTarget)

        busyMessage = String(localized: "Writing carrier bundle overlay…")
        try await CarrierTransport.shared.write(files: [payload], pairingPath: pairingPath)

        mode = .locked(bundle: bundle, imsi: imsi)
    }

    /// Builds a symlink payload; the transport stages the real link so
    /// AirTraffic's recursive copy preserves it in the Overlay.
    private func buildSymlinkPayload(name: String, target: String) throws -> CarrierTransport.Payload {
        CarrierTransport.Payload(name: name, linkTarget: target)
    }

    private func shouldOfferAirliftSetup(for error: Error) -> Bool {
        guard let error = error as? CarrierError else { return false }
        switch error {
        case .pairingRequired, .transportFailed:
            return true
        case .unsupported, .invalidIMSI, .invalidBundle, .symlinkFailed:
            return false
        }
    }
}
