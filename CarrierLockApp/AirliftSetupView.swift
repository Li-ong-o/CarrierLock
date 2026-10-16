import Combine
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Completes the prerequisites used by the AirLift backend: an on-device
/// pairing record and the LocalDevVPN loopback connection.
struct CarrierLockAirliftSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pairing = PairingController.shared
    @StateObject private var wifiMonitor = AirliftWiFiMonitor()

    @State private var paired = FileManager.default.fileExists(
        atPath: PairingController.pairingFilePath()
    )
    @State private var connected = false
    @State private var checking = false
    @State private var pairingError: String?
    @State private var connectionError: String?
    @State private var isImportingPairingFile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("完成配对并连接 LocalDevVPN 后，CarrierLock 才能在手机端写入运营商 Overlay。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    checklist

                    if currentStep != nil {
                        currentCard
                            .padding(18)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
                    }

                    SetupTroubleshootingCard()
                        .padding(18)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("连接引导")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        pairing.softCancel()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isImportingPairingFile) {
                PairingFilePickerView { urls in
                    if let url = urls.first {
                        importPairingFile(from: url)
                    }
                }
            }
        }
    }

    private enum SetupStep: Identifiable {
        case wifi
        case pairing
        case vpn
        case ready

        var id: String {
            switch self {
            case .wifi: "wifi"
            case .pairing: "pairing"
            case .vpn: "vpn"
            case .ready: "ready"
            }
        }
    }

    private var checklist: some View {
        VStack(spacing: 10) {
            SetupChecklistRow(
                title: "Wi-Fi",
                detail: wifiDetail,
                status: wifiStatus
            )
            SetupChecklistRow(
                title: "配对文件",
                detail: pairingDetail,
                status: pairingStatus
            )
            SetupChecklistRow(
                title: "LocalDevVPN",
                detail: vpnDetail,
                status: vpnStatus
            )
            SetupChecklistRow(
                title: "Airlift 服务",
                detail: airliftDetail,
                status: airliftStatus
            )
        }
    }

    @ViewBuilder
    private var currentCard: some View {
        switch currentStep {
        case .wifi:
            VStack(alignment: .leading, spacing: 12) {
                Label("连接 Wi-Fi", systemImage: "wifi")
                    .font(.headline)
                    Text("本地配对和 LocalDevVPN 都要求 iPhone 处于已连接的 Wi-Fi 网络。状态变化后这里会自动更新。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .pairing:
            PairingGuideCard(
                running: pairing.running,
                pin: pairing.pairingPIN,
                error: pairingError,
                onStart: startPairing,
                onImportPairingFile: { isImportingPairingFile = true }
            )
        case .vpn:
            LocalDevVPNGuideCard(
                connectionError: connectionError,
                checking: checking,
                onCheck: checkConnection,
                onPairAgain: {
                    paired = false
                    connected = false
                    pairingError = nil
                    connectionError = nil
                }
            )
        case .ready:
            VStack(alignment: .leading, spacing: 14) {
                    Label("Airlift 已就绪", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                    Text("配对和 LocalDevVPN 已连接。现在可以回到主页，开始监听并自动获取 IMSI。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    dismiss()
                } label: {
                    SetupActionLabel("完成", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        case .none:
            EmptyView()
        }
    }

    private var currentStep: SetupStep? {
        switch wifiMonitor.status {
        case .checking:
            return .wifi
        case .disconnected:
            return .wifi
        case .connected:
            if connected { return .ready }
            return paired ? .vpn : .pairing
        }
    }

    private var wifiStatus: SetupStepStatus {
        switch wifiMonitor.status {
        case .checking: .active
        case .disconnected: .failed
        case .connected: .passed
        }
    }

    private var pairingStatus: SetupStepStatus {
        if connected { return .passed }
        if paired { return .passed }
        if wifiStatus == .passed { return pairing.running ? .active : .pending }
        return .pending
    }

    private var vpnStatus: SetupStepStatus {
        if connected { return .passed }
        if checking { return .active }
        if paired && wifiStatus == .passed { return .pending }
        return .pending
    }

    private var airliftStatus: SetupStepStatus {
        if connected { return .passed }
        if checking { return .active }
        if wifiStatus != .passed || !paired { return .pending }
        return .failed
    }

    private var wifiDetail: String {
        switch wifiMonitor.status {
        case .checking: "正在检查当前网络…"
        case .disconnected: "Wi-Fi 未开启或未连接，蜂窝网络不能用于本地配对。"
        case .connected: "已连接"
        }
    }

    private var pairingDetail: String {
        if connected { return "当前 iPhone 可用" }
        let path = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        if paired && size > 0 { return "已找到 · \(size) 字节" }
        if pairing.running { return "等待在设置里确认配对" }
        return "开始配对，或导入已有 pairing plist"
    }

    private var vpnDetail: String {
        if connected { return "回环已连接" }
        if checking { return "正在探测 10.7.0.1 / 127.0.0.1…" }
        return "回环模式 · 10.7.0.1 或 127.0.0.1"
    }

    private var airliftDetail: String {
        if connected { return "服务可用" }
        if checking { return "正在检查 Airlift 隧道…" }
        if wifiStatus != .passed { return "等待 Wi-Fi" }
        if !paired { return "等待配对" }
        return "未连接。请打开 LocalDevVPN 并连接后再检查。"
    }

    private func importPairingFile(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            pairingError = "选择的文件为空，或无法读取。"
            return
        }
        let adopted = PairingController.syncCanonicalPairingFile(from: url.path)
        CarrierLockLog.shared.append("imported pairing file: \(url.lastPathComponent)")
        if FileManager.default.fileExists(atPath: adopted) {
            paired = true
            connectionError = nil
        } else {
            pairingError = "配对文件无法导入到 CarrierLock。"
        }
    }

    private func startPairing() {
        guard !pairing.running else { return }
        pairingError = nil
        connected = false
        Task {
            do {
                _ = try await pairing.startAndWait()
                paired = true
                connectionError = nil
            } catch {
                pairingError = error.localizedDescription
            }
        }
    }

    private func checkConnection() {
        guard !checking else { return }
        checking = true
        connectionError = nil
        Task {
            defer { checking = false }
            do {
                _ = try await AirliftEngine.shared.detectPosterBoardContainer(
                    pairingPath: PairingController.pairingFilePath()
                )
                connected = true
            } catch {
                connected = false
                connectionError = error.localizedDescription
            }
        }
    }
}

/// UIDocumentPicker wrapper for importing an on-device pairing plist.
struct PairingFilePickerView: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var contentTypes: [UTType] = []
        contentTypes.append(.propertyList)
        if let plistType = UTType(filenameExtension: "plist") {
            contentTypes.append(plistType)
        }
        contentTypes.append(.data)

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: PairingFilePickerView

        init(_ parent: PairingFilePickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !urls.isEmpty else { return }
            parent.onPick(urls)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CarrierLockAirliftSetupView()
}
