import SwiftUI
import UIKit
import Network
import Combine

@MainActor
final class AirliftWiFiMonitor: ObservableObject {
    enum Status {
        case checking
        case connected
        case disconnected
    }

    @Published private(set) var status: Status = .checking

    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let queue = DispatchQueue(label: "me.ssus.carrierlock.airlift.wifi-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.status = path.status == .satisfied ? .connected : .disconnected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

enum SetupStepStatus {
    case pending
    case active
    case passed
    case failed

    var icon: String {
        switch self {
        case .pending: "circle.dotted"
        case .active: "arrow.right.circle.fill"
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending: .secondary
        case .active: .blue
        case .passed: .green
        case .failed: .red
        }
    }
}

struct SetupChecklistRow: View {
    let title: String
    let detail: String
    let status: SetupStepStatus

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if status == .active {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(status.tint)
                    .frame(width: 24, height: 24)
            }

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

struct PairingGuideCard: View {
    let running: Bool
    let pin: String?
    let error: String?
    let onStart: () -> Void
    let onImportPairingFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("配对 CarrierLock", systemImage: "iphone.gen3.radiowaves.left.and.right")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                guideStep(number: 1, text: "点“开始配对”，然后保持这个页面打开。")
                guideStep(number: 2, text: "前往 设置 › 隐私与安全性 › 开发者模式。")
                guideStep(number: 3, text: "点“与 CarrierLock 配对”，输入这里显示的 PIN。")
                guideStep(number: 4, text: "确认配对后返回 CarrierLock。")
            }

            if let pin {
                VStack(spacing: 6) {
                    Text("配对 PIN")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(pin)
                        .font(.title.monospacedDigit().bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: onStart) {
                SetupActionLabel(
                    running ? "等待确认" : "开始配对",
                    systemImage: "dot.radiowaves.left.and.right",
                    busyTitle: "等待确认",
                    isBusy: running
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(running)

            Button(action: onImportPairingFile) {
                SetupActionLabel("导入已有配对文件", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(running)
        }
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct LocalDevVPNGuideCard: View {
    let connectionError: String?
    let checking: Bool
    let onCheck: () -> Void
    let onPairAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("连接 LocalDevVPN", systemImage: "network")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                guideStep(number: 1, text: "打开 LocalDevVPN，选择 Loopback（回环）模式。")
                guideStep(number: 2, text: "回环地址使用 10.7.0.1 或 127.0.0.1。")
                guideStep(number: 3, text: "点“连接”并允许 VPN 配置，然后返回 CarrierLock。")
                guideStep(number: 4, text: "点“检查连接”，确认 Airlift 服务可用。")
            }

            Button {
                openLocalDevVPN()
            } label: {
                SetupActionLabel("打开 LocalDevVPN", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if let connectionError {
                Label(connectionError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)

                Button(role: .destructive, action: onPairAgain) {
                    SetupActionLabel("重新配对这台 iPhone", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: onCheck) {
                SetupActionLabel(
                    checking ? "正在检查连接" : "检查连接",
                    systemImage: "antenna.radiowaves.left.and.right",
                    busyTitle: "正在检查连接",
                    isBusy: checking
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(checking)
        }
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

struct SetupTroubleshootingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("故障排查", systemImage: "ladybug")
                .font(.headline)

            ForEach(troubleshootingItems, id: \.problem) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.problem)
                        .font(.subheadline.weight(.medium))
                    Text(item.solution)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private struct Item {
        let problem: String
        let solution: String
    }

    private var troubleshootingItems: [Item] {
        [
            Item(
                problem: "设置里没有出现配对入口",
                solution: "保持 CarrierLock 打开并连接 Wi-Fi，然后到 设置 › CarrierLock › 本地网络 打开权限。"
            ),
            Item(
                problem: "PIN 输入失败或消失",
                solution: "取消当前尝试后重新开始配对，等待期间不要锁屏。"
            ),
            Item(
                problem: "LocalDevVPN 检测失败",
                solution: "确认回环模式使用 10.7.0.1 或 127.0.0.1，断开再重新连接 VPN，然后重新检查。"
            ),
            Item(
                problem: "已有配对文件但 Airlift 仍失败",
                solution: "配对文件可能属于其他设备或主机。重新配对这台 iPhone，再重新连接 LocalDevVPN。"
            )
        ]
    }
}

#Preview("Checklist") {
    SetupChecklistRow(
        title: "LocalDevVPN",
        detail: "回环模式 · 10.7.0.1 或 127.0.0.1",
        status: .active
    )
}
