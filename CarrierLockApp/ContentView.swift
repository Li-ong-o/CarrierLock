import SwiftUI

@main
struct CarrierLockApp: App {
    init() {
        UIWindow.appearance().backgroundColor = .systemGroupedBackground
    }

    var body: some Scene {
        WindowGroup {
            CarrierLockRootView()
        }
    }
}
