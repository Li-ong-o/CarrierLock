import Combine
import Foundation
import AirliftFFI

@MainActor
final class CarrierMonitor: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case listening
        case failed(String)
    }

    enum Detection: Equatable {
        case noLogs
        case matched(bundle: String)
        case mismatch(expected: String, found: String)
    }

    struct Event: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let text: String
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var detection: Detection = .noLogs
    @Published private(set) var detectedAt: Date?
    @Published private(set) var events: [Event] = []
    @Published private(set) var respringing = false
    @Published private(set) var lastActivityAt: Date?
    @Published private(set) var imsiCandidates: Set<String> = []
    @Published private(set) var matchedBundles: Set<String> = []

    static let shared = CarrierMonitor()

    private let maximumEvents = 12
    private var isStreaming = false
    private var expectedBundles: Set<String> = ["CMCC_cn"]

    private init() {}

    func start(expectedBundles: Set<String>) {
        guard !isStreaming else { return }

        guard PairingController.hasValidPairingFile() else {
            state = .failed(String(localized: "Pairing and LocalDevVPN are required for monitoring."))
            return
        }
        let pairingPath = PairingController.pairingFilePath()

        isStreaming = true
        state = .starting
        self.expectedBundles = expectedBundles.isEmpty ? ["CMCC_cn"] : expectedBundles
        detection = .noLogs
        detectedAt = nil
        matchedBundles.removeAll()
        events.removeAll()

        nonisolated(unsafe) let context = Unmanaged.passRetained(self).toOpaque()

        DispatchQueue.global(qos: .userInitiated).async {
            var outputError: UnsafeMutablePointer<CChar>?
            let result = pairingPath.withCString { pairingCString in
                al_syslog_stream_start(
                    pairingCString,
                    monitorLineCallback,
                    context,
                    &outputError
                )
            }

            let message = outputError.map { String(cString: $0) }
            if let outputError { al_string_free(outputError) }

            Task { @MainActor in
                let monitor = Unmanaged<CarrierMonitor>.fromOpaque(context).takeRetainedValue()
                monitor.finishStream(result: result, message: message)
            }
        }
    }

    func start(expectedBundle: String) {
        start(expectedBundles: [expectedBundle])
    }

    func stop() {
        guard isStreaming else { return }
        al_syslog_stream_stop()
        isStreaming = false
        state = .stopped
    }

    func clearCandidates() {
        imsiCandidates.removeAll()
    }

    func respring() async {
        guard !respringing else { return }
        respringing = true
        defer { respringing = false }

        guard PairingController.hasValidPairingFile() else {
            state = .failed(String(localized: "Pairing and LocalDevVPN are required for monitoring."))
            return
        }
        let pairingPath = PairingController.pairingFilePath()

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var outputError: UnsafeMutablePointer<CChar>?
                let result = pairingPath.withCString { pairingCString in
                    al_device_respring(
                        pairingCString,
                        CarrierLockLog.ffiCallback,
                        nil,
                        &outputError
                    )
                }

                let message = outputError.map { String(cString: $0) }
                if let outputError { al_string_free(outputError) }

                Task { @MainActor in
                    if result != 0 {
                        self.state = .failed(message ?? "Respring failed (\(result)).")
                    }
                    continuation.resume()
                }
            }
        }
    }

    fileprivate func handle(line: String) {
        if state == .starting {
            state = .listening
        }

        if line.contains("CommCenter") {
            appendEvent(line)
        }

        // CommCenter and baseband logs often print the full IMSI during
        // bundle matching or SIM identity reads. Capture any 15-digit number
        // near an IMSI mention, or bare 15-digit strings in CommCenter lines.
        if line.range(of: "IMSI", options: .caseInsensitive) != nil || line.contains("CommCenter") {
            for candidate in Self.imsiMatches(in: line) {
                imsiCandidates.insert(candidate)
            }
        }

        guard let bundle = Self.bundleName(from: line) else { return }
        // Ignore malformed or empty extractions from unrelated log lines.
        guard !bundle.isEmpty,
              bundle.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            return
        }
        matchedBundles.insert(bundle)
        lastActivityAt = Date()

        detectedAt = Date()
        if expectedBundles.contains(bundle) {
            detection = .matched(bundle: bundle)
        } else {
            let expectedDisplay = expectedBundles.sorted().joined(separator: ", ")
            detection = .mismatch(expected: expectedDisplay, found: bundle)
        }
    }

    nonisolated private static func bundleName(from line: String) -> String? {
        // CountryBundleUpdateMatch is a separate country/region map lookup,
        // not the SIM carrier bundle. Treating China_Map as a carrier bundle
        // produced false "different bundle loaded" results.
        guard !line.contains("CountryBundleUpdateMatch") else { return nil }

        // CommCenter emits several formats:
        //   Best match found is CMCC_cn
        //   Current bundle ID CMCC_cn and version 71.5.35
        //   CMCC_cn is already covered
        //   OperatorBundleChange: kNoChange : kSimBased : com.apple.CMCC_cn : 71.5.35
        let patterns = [
            "Best match found is ",
            "Current bundle ID ",
        ]
        for pattern in patterns {
            if let range = line.range(of: pattern) {
                let rest = line[range.upperBound...]
                let token = rest.prefix { !$0.isWhitespace && $0 != "," && $0 != ":" && $0 != ";" }
                if !token.isEmpty { return String(token) }
            }
        }

        if let operatorRange = line.range(of: "OperatorBundleChange") {
            let scanner = Scanner(string: String(line[operatorRange.upperBound...]))
            while !scanner.isAtEnd {
                if let token = scanner.scanUpToCharacters(
                    from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":"))
                ), token.hasPrefix("com.apple.") {
                    return String(token.dropFirst("com.apple.".count))
                }
                scanner.scanString(":")
            }
        }

        if let coveredRange = line.range(of: " is already covered") {
            let before = line[..<coveredRange.lowerBound]
            let token = before.split(separator: " ").last?.trimmingCharacters(in: CharacterSet(charactersIn: ":;,")) ?? ""
            if !token.isEmpty { return String(token) }
        }

        if line.contains("OperatorBundleChange") || line.contains("carrier_bundle slot") {
            for word in line.split(separator: " ") {
                let token = word.trimmingCharacters(in: CharacterSet(charactersIn: ":;,"))
                if token.hasPrefix("com.apple.") {
                    let name = String(token.dropFirst("com.apple.".count))
                    if !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                        return name
                    }
                }
            }
        }

        return nil
    }

    private func appendEvent(_ text: String) {
        events.append(Event(date: Date(), text: text))
        if events.count > maximumEvents {
            events.removeFirst(events.count - maximumEvents)
        }
    }

    nonisolated private static func imsiMatches(in line: String) -> [String] {
        var matches: [String] = []
        var current = ""

        for char in line {
            if char.isNumber {
                current.append(char)
            } else {
                if current.count == 15 {
                    matches.append(current)
                }
                current.removeAll(keepingCapacity: true)
            }
        }

        if current.count == 15 {
            matches.append(current)
        }

        return matches
    }

    private func finishStream(result: Int32, message: String?) {
        isStreaming = false

        if result == 0 {
            if case .starting = state { state = .stopped }
        } else {
            state = .failed(message ?? "Syslog stream failed (\(result)).")
        }
    }
}

private let monitorLineCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void = { context, linePointer in
    guard let context, let linePointer else { return }
    let line = String(cString: linePointer)

    // Cheap prefilter before dispatching to the main actor. Syslog can flood
    // with unrelated lines; parsing them all caused scene-update watchdog
    // terminations.
    let relevant =
        line.contains("CommCenter") ||
        line.range(of: "IMSI", options: .caseInsensitive) != nil ||
        line.contains("OperatorBundleChange") ||
        line.contains("Best match found is ") ||
        line.contains("Current bundle ID ") ||
        line.contains("carrier_bundle slot") ||
        line.contains(" is already covered")
    guard relevant else { return }

    Task { @MainActor in
        let monitor = Unmanaged<CarrierMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.handle(line: line)
    }
}
