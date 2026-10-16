//
//  AirliftEngine.swift
//  CarrierLock
//
//  Minimal Airlift bridge: device container lookup and respring, used for
//  pairing/VPN connectivity checks.
//

import Foundation
import AirliftFFI

public final class AirliftEngine {
    public static let shared = AirliftEngine()

    private init() {}

    // MARK: - Auto-detect PosterBoard Container

    public func detectPosterBoardContainer(pairingPath: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var outContainer: UnsafeMutablePointer<CChar>? = nil
                var outError: UnsafeMutablePointer<CChar>? = nil

                let rc = pairingPath.withCString { pairC in
                    "com.apple.PosterBoard".withCString { bundleC in
                        al_find_app_container(pairC, bundleC, nil, nil, &outContainer, &outError)
                    }
                }

                if rc == 0, let p = outContainer {
                    let containerStr = String(cString: p)
                    al_string_free(p)
                    continuation.resume(returning: containerStr)
                } else {
                    let errStr = outError.flatMap { p in
                        let s = String(cString: p)
                        al_string_free(p)
                        return s
                    } ?? "Failed to find PosterBoard container"
                    continuation.resume(throwing: NSError(
                        domain: "AirliftEngine",
                        code: Int(rc),
                        userInfo: [NSLocalizedDescriptionKey: errStr]
                    ))
                }
            }
        }
    }
}
