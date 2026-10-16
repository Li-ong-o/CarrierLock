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
        case locked(links: [String: String])
        case failed(String)
    }

    private static let lastLockedLinksKey = "CarrierLock_LastLockedLinks"
    private static let selectedIMSIsKey = "CarrierLock_SelectedIMSIs"

    @Published private(set) var mode: LockMode = .idle
    @Published private(set) var bundleName: String = "CMCC_cn"
    @Published var customBundlesByIMSI: [String: String] = [:]
    @Published private(set) var detectedIMSIs: [String] = []
    @Published private(set) var busyMessage: String?
    @Published private(set) var needsAirliftSetup = false
    @Published private(set) var detection: CarrierDetection?

    static let shared = CarrierService()
    private init() {
        // Restore persisted state across Resprings
        if let persistedLinks = UserDefaults.standard.dictionary(forKey: Self.lastLockedLinksKey) as? [String: String],
           !persistedLinks.isEmpty {
            mode = .locked(links: persistedLinks)
        }
        if let persistedIMSIs = UserDefaults.standard.stringArray(forKey: Self.selectedIMSIsKey),
           !persistedIMSIs.isEmpty {
            detectedIMSIs = persistedIMSIs
        }

        // Carrier detection is informational only. IMSI and bundle are
        // intentionally left for the user to choose; MEP devices often
        // expose the wrong IMSI through the public APIs.
        detectCarrier()
    }

    func detectCarrier() {
        detection = CarrierDetectionService.detect()
        if let detectedBundle = detection?.bundleName, !detectedBundle.isEmpty {
            bundleName = detectedBundle
        }
    }

    var monitoredBundleNames: Set<String> {
        if case .locked(let links) = mode {
            return Set(links.values)
        }
        if !detectedIMSIs.isEmpty {
            return Set(detectedIMSIs.map { bundle(forIMSI: $0) })
        }
        return Set([bundleName])
    }

    var monitoredBundleName: String {
        monitoredBundleNames.sorted().first ?? bundleName
    }

    var selectedIMSIs: [String] {
        detectedIMSIs
    }

    func selectBundle(_ name: String) {
        let canonical = CarrierBundleCatalog.canonicalName(for: name) ?? name
        bundleName = canonical
    }

    func bundle(forIMSI imsi: String) -> String {
        if let custom = customBundlesByIMSI[imsi]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return CarrierBundleCatalog.canonicalName(for: custom) ?? custom
        }

        if let prefix = CarrierDetectionService.prefixCandidate(for: imsi),
           let automatic = CarrierDetectionService.bundle(for: prefix) {
            return automatic
        }

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
        guard mode != .locking else { return }
        do {
            let imsis = selectedIMSIs
            guard !imsis.isEmpty else {
                mode = .idle
                UserDefaults.standard.removeObject(forKey: Self.lastLockedLinksKey)
                return
            }

            // Restore native carrier bundle for each IMSI
            for imsi in imsis {
                if let prefix = CarrierDetectionService.prefixCandidate(for: imsi),
                   let native = CarrierDetectionService.bundle(for: prefix) {
                    customBundlesByIMSI[imsi] = native
                } else if let native = detection?.bundleName {
                    customBundlesByIMSI[imsi] = native
                }
            }

            try await run()
            UserDefaults.standard.removeObject(forKey: Self.lastLockedLinksKey)
            mode = .idle
        } catch {
            mode = .failed(error.localizedDescription)
            needsAirliftSetup = shouldOfferAirliftSetup(for: error)
        }
    }

    func dismissFailure() {
        if case .failed = mode {
            mode = .idle
        }
    }

    func toggleDetectedIMSI(_ value: String) {
        guard let index = detectedIMSIs.firstIndex(of: value) else { return }
        detectedIMSIs.remove(at: index)
        customBundlesByIMSI.removeValue(forKey: value)
        persistSelectedIMSIs()
    }

    func selectDetectedIMSI(_ value: String) {
        guard value.count == 15, value.allSatisfy(\.isNumber),
              !detectedIMSIs.contains(value) else { return }
        detectedIMSIs.append(value)
        detectedIMSIs.sort()

        // Auto-assign corresponding bundle if known for this PLMN
        if let prefix = CarrierDetectionService.prefixCandidate(for: value),
           let autoBundle = CarrierDetectionService.bundle(for: prefix) {
            customBundlesByIMSI[value] = autoBundle
        }

        persistSelectedIMSIs()
    }

    private func persistSelectedIMSIs() {
        UserDefaults.standard.set(detectedIMSIs, forKey: Self.selectedIMSIsKey)
    }

    private func run() async throws {
        guard SystemCompatibility.isSupported else {
            throw CarrierError.unsupported
        }

        guard PairingController.hasValidPairingFile() else {
            throw CarrierError.pairingRequired
        }
        let pairingPath = PairingController.pairingFilePath()

        let imsis = selectedIMSIs
        guard !imsis.isEmpty else {
            throw CarrierError.invalidIMSI("(empty)")
        }

        let invalidIMSIs = imsis.filter { $0.count != 15 || !$0.allSatisfy(\.isNumber) }
        guard invalidIMSIs.isEmpty else {
            throw CarrierError.invalidIMSI(invalidIMSIs.joined(separator: ", "))
        }

        let links = Dictionary(uniqueKeysWithValues: imsis.map { imsi -> (String, String) in
            let raw = bundle(forIMSI: imsi)
            let canonical = CarrierBundleCatalog.canonicalName(for: raw) ?? raw
            return (imsi, canonical)
        })
        let invalidBundles = links.values.filter {
            $0.isEmpty || !$0.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
        }
        guard invalidBundles.isEmpty else {
            throw CarrierError.invalidBundle(invalidBundles.first ?? "(empty)")
        }

        // Guard against dead symlinks: the target must be a bundle Apple
        // actually ships (see CarrierBundleList.allBundles). A link to a
        // nonexistent bundle is silently ignored by CommCenter, which makes
        // the lock look successful while doing nothing.
        let unknownBundles = links.values.filter { !CarrierBundleCatalog.allSet.contains($0) }
        guard unknownBundles.isEmpty else {
            throw CarrierError.invalidBundle(unknownBundles.sorted().joined(separator: ", "))
        }

        busyMessage = String(localized: "Preparing carrier bundle link…")
        mode = .locking
        defer { busyMessage = nil }

        let payloads = try links.map { imsi, bundle in
            try buildSymlinkPayload(name: imsi, target: "/System/Library/Carrier Bundles/iPhone/\(bundle).bundle")
        }

        busyMessage = String(format: String(localized: "Writing %d carrier bundle overlay links…"), payloads.count)
        try await CarrierTransport.shared.write(files: payloads, pairingPath: pairingPath)

        mode = .locked(links: links)
        UserDefaults.standard.set(links, forKey: Self.lastLockedLinksKey)
        persistSelectedIMSIs()
    }

    /// Builds a symlink payload; the transport stages the real link so
    /// AirTraffic's recursive copy preserves it in the Overlay.
    private func buildSymlinkPayload(name: String, target: String) throws -> CarrierTransport.Payload {
        CarrierTransport.Payload(name: name, linkTarget: target)
    }

    private func shouldOfferAirliftSetup(for error: Error) -> Bool {
        if let carrierError = error as? CarrierError {
            switch carrierError {
            case .pairingRequired, .transportFailed:
                return true
            case .unsupported, .invalidIMSI, .invalidBundle, .symlinkFailed:
                return false
            }
        }
        return false
    }
}
