import SwiftUI

struct CarrierLockRootView: View {
    @StateObject private var service = CarrierService.shared
    @ObservedObject private var monitor = CarrierMonitor.shared
    @State private var showingAbout = false
    @State private var showingAirliftSetup = false
    @State private var showingBundlePicker = false
    @State private var editingIMSI: String?
    @State private var showingStartupGate = true
    @State private var confirmingLock = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    statusCard

                    if let busyMessage = service.busyMessage {
                        busyWarning(message: busyMessage)
                    }

                    if service.needsAirliftSetup {
                        airliftSetupCard
                    }

                    lockForm
                    lockButton
                    restoreButton
                    CarrierMonitorView()
                    details
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("CarrierLock")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if monitor.state == .listening || monitor.state == .starting {
                        Button {
                            CarrierMonitor.shared.stop()
                        } label: {
                            Label("停止监听", systemImage: "stop.circle.fill")
                        }
                        .foregroundStyle(.red)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About")
                }
            }
        }
        .sheet(isPresented: $showingAbout) {
            CarrierLockAboutView()
        }
        .sheet(isPresented: $showingAirliftSetup, onDismiss: {
            Task { await service.lock() }
        }) {
            CarrierLockAirliftSetupView()
        }
        .sheet(isPresented: $showingBundlePicker) {
            CarrierBundlePickerSheet(
                bundleName: Binding(
                    get: {
                        guard let imsi = editingIMSI else { return service.bundleName }
                        return service.bundle(forIMSI: imsi)
                    },
                    set: { value in
                        guard let imsi = editingIMSI else { return }
                        service.customBundlesByIMSI[imsi] = value
                    }
                )
            )
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showingStartupGate) {
            CarrierStartupGateView(onContinue: {
                showingStartupGate = false
            }, onOpenSetup: {
                showingStartupGate = false
                showingAirliftSetup = true
            })
        }
        .alert(
            "Operation Failed",
            isPresented: Binding(
                get: {
                    if case .failed = service.mode { return true }
                    return false
                },
                set: { presented in
                    if !presented {
                        service.dismissFailure()
                    }
                }
            )
        ) {
            Button("OK") {
                service.dismissFailure()
            }
        } message: {
            if case let .failed(message) = service.mode {
                Text(message)
            }
        }
        .confirmationDialog(
            "确认 IMSI 是否为本机号码",
            isPresented: $confirmingLock,
            titleVisibility: .visible
        ) {
            Button("已核对，继续锁定", role: .destructive) {
                Task { await service.lock() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先与电脑核对 IMSI 是否为本机 SIM 的 IMSI。如果误锁成卡贴伪装 IMSI，运营商配置会持续匹配到错误目标，可能导致信号不稳定、功能异常或反复触发激活。")
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.teal.gradient)
                    .frame(width: 88, height: 88)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("锁定 IPCC")
                .font(.title2.bold())
            Text("固定 SIM 对应的运营商配置，减少夜间或重启后的重新激活。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: modeSymbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(modeColor)
                .frame(width: 48, height: 48)
                .background(modeColor.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(modeTitle)
                    .font(.headline)
                Text(modeDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if case .locking = service.mode {
                ProgressView()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private var lockForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("已选 IMSI", systemImage: "checkmark.circle")
                .font(.headline)

            if !service.selectedIMSIs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(service.selectedIMSIs, id: \.self) { imsi in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(imsi)
                                    .font(.callout.monospaced())
                                Text(service.bundle(forIMSI: imsi))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                editingIMSI = imsi
                                showingBundlePicker = true
                            } label: {
                                Text("修改")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Text("每个 IMSI 会按 PLMN 自动匹配对应 bundle；无法识别或特殊场景可使用自定义 bundle 覆盖。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("暂无已选 IMSI。请先开始监听并刷新 SIM 信号。", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private var lockButton: some View {
        Button {
            confirmingLock = true
        } label: {
            Label("锁定运营商配置", systemImage: "lock.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isBusy)
    }
    private var restoreButton: some View {
        Button(role: .destructive) {
            Task { await service.restore() }
        } label: {
            Label("恢复", systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isBusy)
    }

    private func busyWarning(message: String) -> some View {
        Label {
            Text(message)
                .font(.headline)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.red.opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private var airliftSetupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("需要完成连接引导", systemImage: "link.badge.plus")
                .font(.headline)

            Text("请先完成 iPhone 配对并连接 LocalDevVPN，CarrierLock 才能写入 Overlay 链接。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showingAirliftSetup = true
            } label: {
                Label("打开连接引导", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bundle 名称必须对应系统运营商配置目录下的文件夹。", systemImage: "folder.badge.gearshape")
            Label("IMSI 符号链接会写入 Overlay 目录。", systemImage: "externaldrive.badge.timemachine")
            Label("更换 SIM 后 IMSI 改变，原链接会失效。", systemImage: "simcard")
            Label("本应用依赖非公开系统行为，请谨慎使用。", systemImage: "exclamationmark.triangle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isBusy: Bool {
        if case .locking = service.mode { return true }
        return false
    }

    private var modeTitle: String {
        switch service.mode {
        case .idle: "未锁定"
        case .locking: "锁定中…"
        case .locked(let links): "Locked: \(links.count) IMSI"
        case .failed: "失败"
        }
    }

    private var modeDetail: String {
        switch service.mode {
        case .idle:
            service.selectedIMSIs.isEmpty
                ? "尚未选择 IMSI。请先开始监听。"
                : "已选择 \(service.selectedIMSIs.count) 个 IMSI，确认后可锁定。"
        case .locking:
            "正在写入运营商配置链接。"
        case .locked:
            "上次写入已生效。请勿把它当作当前选择。"
        case .failed:
            "上次操作失败，请检查错误后重试。"
        }
    }

    private var modeSymbol: String {
        switch service.mode {
        case .idle: "lock.open"
        case .locking: "hourglass"
        case .locked: "lock.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var modeColor: Color {
        switch service.mode {
        case .idle: .secondary
        case .locking: .blue
        case .locked: .teal
        case .failed: .red
        }
    }

    private var imsiDetail: String {
        if case .locked(let links) = service.mode {
            return links
                .sorted { $0.key < $1.key }
                .map { "\($0.key) → \($0.value)" }
                .joined(separator: "、")
        }
        return ""
    }
}

#Preview {
    CarrierLockRootView()
}

private struct CarrierBundlePickerSheet: View {
    @Binding var bundleName: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var customMode = false
    @State private var customBundle = ""

    private var bundles: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return CarrierBundleCatalog.preferred + CarrierBundleCatalog.all }
        return CarrierBundleCatalog.all.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("搜索 bundle", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        customMode = true
                    } label: {
                        HStack {
                            Label("自定义…", systemImage: "square.and.pencil")
                            Spacer()
                            if customMode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }

                    if customMode {
                        TextField("Bundle 名称", text: $customBundle)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .monospaced()

                        Button("使用自定义 Bundle") {
                            bundleName = customBundle.trimmingCharacters(in: .whitespacesAndNewlines)
                            dismiss()
                        }
                        .disabled(!isValid)
                    }
                }

                if !customMode {
                    Section("运营商配置") {
                        ForEach(bundles, id: \.self) { bundle in
                            Button {
                                bundleName = bundle
                                dismiss()
                            } label: {
                                HStack {
                                    Text(bundle)
                                        .font(.callout.monospaced())
                                    Spacer()
                                    if bundle == bundleName {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("运营商配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("重置") {
                        customMode = false
                        searchText = ""
                    }
                    .disabled(!customMode && searchText.isEmpty)
                }
            }
        }
    }

    private var isValid: Bool {
        let value = customBundle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

private struct CarrierStartupGateView: View {
    let onContinue: () -> Void
    let onOpenSetup: () -> Void

    @State private var status = CarrierStartupStatus.checking
    @State private var checking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.tint)

                    Text("CarrierLock 启动检查")
                        .font(.largeTitle.bold())
                    Text("使用前请确认配对文件和 LocalDevVPN 回环连接正常。")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    SetupChecklistRow(
                        title: "Wi-Fi",
                        detail: wifiDetail,
                        status: wifiState
                    )
                    SetupChecklistRow(
                        title: "配对文件",
                        detail: pairingDetail,
                        status: pairingState
                    )
                    SetupChecklistRow(
                        title: "LocalDevVPN / Airlift",
                        detail: vpnDetail,
                        status: vpnState
                    )
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                VStack(spacing: 12) {
                    if status == .ready {
                        Button(action: onContinue) {
                            SetupActionLabel("进入 CarrierLock", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button {
                            check()
                        } label: {
                            SetupActionLabel(
                                checking ? "正在检查" : "重新检查",
                                systemImage: "arrow.clockwise",
                                busyTitle: "Checking",
                                isBusy: checking
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(checking)

                        Button {
                            onOpenSetup()
                        } label: {
                            SetupActionLabel("打开连接引导", systemImage: "gearshape")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(checking)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .task { check() }
    }

    private enum CarrierStartupStatus {
        case checking
        case ready
        case setupRequired
    }

    @StateObject private var wifiMonitor = AirliftWiFiMonitor()

    private var wifiState: SetupStepStatus {
        switch wifiMonitor.status {
        case .checking: .active
        case .connected: .passed
        case .disconnected: .failed
        }
    }

    private var wifiDetail: String {
        switch wifiMonitor.status {
        case .checking: "正在检查当前网络…"
        case .connected: "已连接"
        case .disconnected: "Wi-Fi 未连接或已关闭"
        }
    }

    private var pairingState: SetupStepStatus {
        status == .checking ? .active : (status == .ready ? .passed : .failed)
    }

    private var vpnState: SetupStepStatus {
        status == .checking ? .active : (status == .ready ? .passed : .failed)
    }

    private var pairingDetail: String {
        let path = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        return size > 0 ? "已找到 · \(size) 字节" : "未找到配对文件"
    }

    private var vpnDetail: String {
        status == .checking ? "正在探测回环隧道…" : (status == .ready ? "已连接 · 10.7.0.1 或 127.0.0.1" : "未连接 · 请使用回环模式")
    }

    private func check() {
        guard !checking else { return }
        checking = true
        status = .checking
        errorMessage = nil

        Task {
            defer { checking = false }
            let path = PairingController.pairingFilePath()
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            guard size > 0 else {
                status = .setupRequired
                errorMessage = "缺少配对文件。请打开连接引导完成配对，或导入已有配对文件。"
                return
            }

            do {
                _ = try await TendiesEngine.shared.detectPosterBoardContainer(pairingPath: path)
                status = .ready
            } catch {
                status = .setupRequired
                errorMessage = "LocalDevVPN 探测失败：\(error.localizedDescription)"
            }
        }
    }
}
