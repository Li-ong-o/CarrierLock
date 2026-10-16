import Combine
import Foundation

/// Thread-safe runtime log collector.
///
/// The Rust/FFI layer calls the C log callback from arbitrary threads, so
/// writes are guarded by a lock and the UI drains the buffer on demand.
final class CarrierLockLog: ObservableObject {
    static let shared = CarrierLockLog()

    private let lock = NSLock()
    private var lines: [String] = []
    private let capacity = 1000
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    @Published private(set) var updateToken: Int = 0

    private init() {}

    /// Append a line from any thread.
    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateToken &+= 1
        }
    }

    /// Return all collected lines so far and clear the buffer.
    func drain() -> [String] {
        lock.lock()
        let out = lines
        lines.removeAll()
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateToken &+= 1
        }
        return out
    }

    /// Return all collected lines without clearing.
    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    /// Timestamped log text for exporting / sharing.
    func exportText() -> String {
        let stamp = Self.dateFormatter.string(from: Date())
        let body = snapshot().joined(separator: "\n")
        return "CarrierLock log — \(stamp)\n----------------------------\n\(body)"
    }

    func clear() {
        lock.lock()
        lines.removeAll()
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateToken &+= 1
        }
    }
}

/// Non-capturing C callback so it can be passed to the Airlift FFI as a
/// function pointer. Rust calls it with a NUL-terminated message string.
private let alLogBridge: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void = { _, msg in
    guard let msg = msg else { return }
    CarrierLockLog.shared.append(String(cString: msg))
}

extension CarrierLockLog {
    /// The C callback to hand to AirLift operations.
    /// `@convention(c)` function types are Sendable, so it can be nonisolated and
    /// passed from CarrierTransport's nonisolated static helpers.
    nonisolated static var ffiCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void {
        alLogBridge
    }
}
