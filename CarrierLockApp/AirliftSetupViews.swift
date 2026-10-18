import Combine
import Network
import SwiftUI
import UIKit

/// Uses the interface table for the Wi-Fi decision. Once LocalDevVPN is active,
/// a Wi-Fi-specific path monitor can report unsatisfied even though en0 is up.
@MainActor
final class AirliftWiFiMonitor: ObservableObject {
    enum Status {
        case checking
        case connected
        case disconnected
    }

    @Published private(set) var status: Status = .checking

    private let queue = DispatchQueue(label: "com.carrier.lock.airlift.wifi-monitor")
    private let monitor = NWPathMonitor()

    init() {
        refresh()
        monitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func refresh() {
        status = NetworkStatus.wifiActive ? .connected : .disconnected
    }
}

struct SetupStepStatus {
    let icon: String
    let tint: Color

    static let pending = SetupStepStatus(icon: "circle.dotted", tint: .secondary)
    static let active = SetupStepStatus(icon: "arrow.right.circle.fill", tint: .blue)
    static let passed = SetupStepStatus(icon: "checkmark.circle.fill", tint: .green)
    static let failed = SetupStepStatus(icon: "xmark.circle.fill", tint: .red)
}

struct SetupChecklistRow: View {
    let title: String
    let detail: String
    let status: SetupStepStatus

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: status.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(status.tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }
}

struct SetupActionLabel: View {
    let title: String
    let systemImage: String
    let busyTitle: String?
    let isBusy: Bool

    init(_ title: String, systemImage: String, busyTitle: String? = nil, isBusy: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.busyTitle = busyTitle
        self.isBusy = isBusy
    }

    var body: some View {
        HStack {
            if isBusy {
                ProgressView()
            } else {
                Image(systemName: systemImage)
            }
            Text(isBusy ? (busyTitle ?? title) : title)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AirliftWiFiCheckingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("正在检查 Wi-Fi…")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }
}

struct AirliftWiFiRequiredView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("需要 Wi-Fi")
                .font(.largeTitle.bold())
            Text("Airlift 需要已连接的 Wi-Fi 网络，LocalDevVPN 不能在蜂窝网络下使用。")
                .foregroundStyle(.secondary)
            Text("请先连接 Wi-Fi。连接后 CarrierLock 会自动继续。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }
}

struct AirliftPairingView: View {
    let running: Bool
    let pin: String?
    let error: String?
    let onStart: () -> Void
    let onImportPairingFile: () -> Void
    var onDevicePairingSupported: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("配对这台 iPhone")
                .font(.largeTitle.bold())

            if onDevicePairingSupported {
                Text("开始配对后，前往 设置 › 隐私与安全性 › 开发者模式 › 与 CarrierLock 配对。")
                    .foregroundStyle(.secondary)
                if let pin {
                    Text(pin)
                        .font(.system(size: 46, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
                        .accessibilityLabel("配对 PIN")
                }
            } else {
                Text("此系统版本无法在手机上直接配对。请在电脑上用 iloader 或 idevice_pair 生成配对文件，然后导入这里。")
                    .foregroundStyle(.secondary)
                PairingToolLinks()
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }

            Spacer()

            if onDevicePairingSupported {
                Button(action: onStart) {
                    if running {
                        ProgressView("等待配对确认…")
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("开始配对")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(running)
            }

            if onDevicePairingSupported {
                importPairingButton
                    .buttonStyle(.bordered)
            } else {
                importPairingButton
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }

    private var importPairingButton: some View {
        Button(action: onImportPairingFile) {
            Label("导入配对文件", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(running)
    }
}

struct PairingToolLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("在电脑上生成配对文件后导入：")
                .font(.footnote)
                .foregroundStyle(.secondary)

            toolLink(
                name: "iloader",
                detail: "支持导出配对文件",
                url: "https://github.com/nab138/iloader"
            )
            toolLink(
                name: "idevice_pair",
                detail: "生成并保存配对记录",
                url: "https://github.com/jkcoxson/idevice_pair"
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private func toolLink(name: String, detail: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 10) {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct AirliftVPNView: View {
    let connectionError: String?
    let checking: Bool
    let onCheck: () -> Void
    let onPairAgain: () -> Void

    @State private var tunnelAddress: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: "network")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("连接 LocalDevVPN")
                .font(.largeTitle.bold())
            Text("打开 LocalDevVPN 并连接回环模式，然后返回 CarrierLock。")
                .foregroundStyle(.secondary)

            Button("打开 LocalDevVPN", action: openLocalDevVPN)
                .buttonStyle(.bordered)
                .controlSize(.large)

            if let connectionError {
                Text(connectionError)
                    .foregroundStyle(.red)
                Button("重新配对", action: onPairAgain)
                    .font(.footnote)
            }

            networkStatusRow
            Spacer()

            Button(action: onCheck) {
                if checking {
                    ProgressView("正在检查连接…")
                        .frame(maxWidth: .infinity)
                } else {
                    Text("检查并进入")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(checking)
        }
        .padding(24)
        .onAppear {
            tunnelAddress = NetworkStatus.tunnelInterfaceAddress
        }
    }

    private var networkStatusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusLine(
                symbol: "wifi",
                label: "Wi-Fi",
                value: NetworkStatus.wifiActive
                    ? (NetworkStatus.interfaces().first { $0.name == "en0" && $0.isUp }?.ipv4 ?? "已连接")
                    : "未连接"
            )
            statusLine(
                symbol: "network.badge.shield.half.filled",
                label: "LocalDevVPN",
                value: tunnelAddress ?? "未连接"
            )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private func statusLine(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 18)
            Text(label)
            Spacer(minLength: 8)
            Text(verbatim: value)
                .font(.footnote.monospaced())
                .multilineTextAlignment(.trailing)
        }
    }

    private func openLocalDevVPN() {
        let appURL = URL(string: "localdevvpn://")!
        let storeURL = URL(string: "https://apps.apple.com/app/id6755608044")!
        UIApplication.shared.open(appURL) { opened in
            guard !opened else { return }
            DispatchQueue.main.async {
                UIApplication.shared.open(storeURL)
            }
        }
    }
}
