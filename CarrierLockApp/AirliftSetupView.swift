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
            Group {
                switch wifiMonitor.status {
                case .checking:
                    AirliftWiFiCheckingView()
                case .disconnected:
                    AirliftWiFiRequiredView()
                case .connected:
                    if connected {
                        readyView
                    } else if paired {
                        AirliftVPNView(
                            connectionError: connectionError,
                            checking: checking,
                            onCheck: checkConnection,
                            onPairAgain: {
                                paired = false
                                pairingError = nil
                                connectionError = nil
                            }
                        )
                    } else {
                        AirliftPairingView(
                            running: pairing.running,
                            pin: pairing.pairingPIN,
                            error: pairingError,
                            onStart: startPairing,
                            onImportPairingFile: { isImportingPairingFile = true },
                            onDevicePairingSupported: SystemCompatibility.supportsOnDevicePairing
                        )
                    }
                }
            }
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

    private var readyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.green)
            Text("CarrierLock 已就绪")
                .font(.largeTitle.bold())
            Text("配对和 LocalDevVPN 已连接。现在可以返回 CarrierLock 检查或锁定运营商配置。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
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
            pairingError = nil
            connectionError = nil
        } else {
            pairingError = "配对文件无法导入到 CarrierLock。"
        }
    }

    private func startPairing() {
        guard !pairing.running else { return }
        pairingError = nil
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
                _ = try await TendiesEngine.shared.detectPosterBoardContainer(
                    pairingPath: PairingController.pairingFilePath()
                )
                connected = true
            } catch {
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
