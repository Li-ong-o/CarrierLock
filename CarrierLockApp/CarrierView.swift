import SwiftUI

struct CarrierLockRootView: View {
    @StateObject private var service = CarrierService.shared
    @State private var showingAbout = false
    @State private var showingAirliftSetup = false
    @State private var showingBundlePickerForSlot: String?
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
                    } else {
                        selectionCard

                        if service.needsRecovery {
                            recoveryCard
                        }

                        actionButtons
                    }

                    details
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        .sheet(isPresented: $showingAirliftSetup) {
            CarrierLockAirliftSetupView()
        }
        .sheet(item: Binding(
            get: { showingBundlePickerForSlot.map(SlotPickerTarget.init) },
            set: { showingBundlePickerForSlot = $0?.slot }
        )) { target in
            CarrierBundlePickerSheet(
                slot: target.slot,
                bundleName: Binding(
                    get: { service.bundle(for: target.slot) },
                    set: { service.setBundle($0, for: target.slot) }
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
            "操作失败",
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
            Button("好") {
                service.dismissFailure()
            }
        } message: {
            if case let .failed(message) = service.mode {
                Text(message)
            }
        }
        .confirmationDialog(
            "确认锁定运营商配置？",
            isPresented: $confirmingLock,
            titleVisibility: .visible
        ) {
            Button("已核对，继续锁定", role: .destructive) {
                Task { await service.apply() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将为 \(service.selectedSims.map(\.displaySlot).joined(separator: "、")) 分别写入对应的运营商配置。请确认每个 SIM 的配置正确；CarrierSIM 会在写入前再次校验设备和 SIM 绑定。")
        }
        .task {
            if !service.needsAirliftSetup {
                await service.ensureInitialStatus()
            }
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
            Text("固定 SIM 对应的运营商配置，减少卡贴日常使用中的跳激活。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 48, height: 48)
                    .background(statusColor.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                Spacer(minLength: 0)

                if service.isWorking {
                    ProgressView()
                }
            }

            if !service.extraIMSILinks.isEmpty {
                let names = service.extraIMSILinks.map(\.imsi).joined(separator: "、")
                Label("检测到多余 IMSI 链接：\(names)。请点击“恢复”清理。", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("SIM 卡槽", systemImage: "square.grid.2x2")
                .font(.headline)

            HStack(spacing: 10) {
                slotButton("kOne")
                slotButton("kTwo")
            }

            if service.sims.isEmpty {
                Text("尚未读取 SIM 信息。请先点击“检查状态”。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(service.sims) { sim in
                    slotInfo(for: sim)
                }
            }

        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private func slotInfo(for sim: CarrierSIMInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let lockedBundle = service.imsiLinks
                .first { $0.imsi == sim.imsi }?
                .bundle
            let isLocked = lockedBundle != nil
            let suggestedBundle = service.suggestedBundle(for: sim)
            let displayedBundle = lockedBundle
                ?? suggestedBundle
                ?? service.bundle(for: sim.slot)

            HStack {
                Text(sim.displaySlot)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if service.imsiLinks.contains(where: { $0.imsi == sim.imsi }) {
                    Label("已锁定", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                }

            }

            HStack(spacing: 8) {
                Text("IMSI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sim.maskedIMSI)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
            }

            if !sim.carrier.isEmpty {
                let version = sim.version.isEmpty ? nil : sim.version
                Text([sim.displayCarrier, version].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(displayedBundle)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(1)

                if !isLocked && suggestedBundle != nil {
                    Label("自动", systemImage: "wand.and.stars")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button("选择") {
                    showingBundlePickerForSlot = sim.slot
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 8))
    }

    private func slotButton(_ slot: String) -> some View {
        let available = service.availableSlots.contains(slot)
        let selected = service.selectedSlots.contains(slot)

        return Button {
            guard available else { return }
            if selected {
                service.selectedSlots.remove(slot)
            } else {
                service.selectedSlots.insert(slot)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.teal : .secondary)
                Text(slotDisplayName(slot))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!available || service.isWorking)
        .opacity(available ? 1 : 0.45)
    }

    private var recoveryCard: some View {
        Label {
            Text("CarrierSIM 检测到未完成操作。系统已保留可恢复的目录快照和日志。")
                .font(.subheadline)
        } icon: {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.red.opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await service.refreshStatus() }
            } label: {
                Label("检查状态", systemImage: "checkmark.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(service.isWorking)

            Button {
                confirmingLock = true
            } label: {
                Label("锁定运营商配置", systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!service.canApply)

            Button(role: .destructive) {
                Task { await service.restore() }
            } label: {
                Label("恢复", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(service.isWorking)

            Button {
                Task { await service.recover() }
            } label: {
                Label("恢复未完成操作", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(service.isWorking)
        }
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

            Text("请先完成 iPhone 配对并连接 LocalDevVPN，CarrierLock 才能读取设备状态和写入 Overlay 链接。")
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
            Label("CarrierSIM 会把 15 位 IMSI 作为符号链接写入 Overlay 目录。", systemImage: "externaldrive.badge.timemachine")
            Label("更换 SIM 后 IMSI 改变，原链接会失效；请先恢复，再重新锁定。", systemImage: "simcard")
            Label("本应用依赖非公开系统行为，请谨慎使用。", systemImage: "exclamationmark.triangle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusTitle: String {
        if service.errorMessage != nil {
            return "检查失败（如果配对完成请重启软件）"
        }
        if service.mode == .locking {
            return "正在锁定"
        }
        if service.needsRecovery {
            return "需要恢复"
        }
        if service.isAfterSuccessfulApply {
            return "已锁定"
        }
        if let result = service.latestResult, result.isFullyVerified {
            return "已确认"
        }
        if service.allSelectedSimsLocked {
            return "已锁定"
        }
        if service.hasLoadedStatus, service.latestResult?.canApply == true {
            return "可以锁定"
        }
        if service.isWorking {
            return "正在处理"
        }
        return "等待检查"
    }

    private var statusDetail: String {
        if let errorMessage = service.errorMessage {
            return errorMessage
        }
        if let statusMessage = service.statusMessage {
            return statusMessage
        }
        if service.needsRecovery {
            return "请先恢复上次未完成操作，再尝试锁定。"
        }
        if !service.hasLoadedStatus {
            return "请先检查设备状态。"
        }
        return "已选择 \(service.sortedSlots.map(slotDisplayName).joined(separator: "、"))。"
    }

    private var statusSymbol: String {
        if service.errorMessage != nil {
            return "exclamationmark.triangle.fill"
        }
        if service.mode == .locking {
            return "lock.fill"
        }
        if service.needsRecovery {
            return "arrow.triangle.2.circlepath"
        }
        if service.isAfterSuccessfulApply {
            return "lock.fill"
        }
        if service.latestResult?.isFullyVerified == true {
            return "lock.fill"
        }
        if service.allSelectedSimsLocked {
            return "lock.fill"
        }
        if service.isWorking {
            return "hourglass"
        }
        if service.hasLoadedStatus, service.latestResult?.canApply == true {
            return "checkmark.circle.fill"
        }
        return "lock.open"
    }

    private var statusColor: Color {
        if service.errorMessage != nil {
            return .red
        }
        if service.mode == .locking {
            return .teal
        }
        if service.needsRecovery {
            return .orange
        }
        if service.isAfterSuccessfulApply {
            return .teal
        }
        if service.latestResult?.isFullyVerified == true {
            return .teal
        }
        if service.allSelectedSimsLocked {
            return .teal
        }
        if service.isWorking {
            return .blue
        }
        if service.hasLoadedStatus, service.latestResult?.canApply == true {
            return .green
        }
        return .secondary
    }

    private func slotDisplayName(_ slot: String) -> String {
        switch slot {
        case "kOne": "SIM 1"
        case "kTwo": "SIM 2"
        default: slot
        }
    }
}

#Preview {
    CarrierLockRootView()
}

private struct SlotPickerTarget: Identifiable {
    let slot: String
    var id: String { slot }
}

private struct CarrierBundlePickerSheet: View {
    let slot: String
    @Binding var bundleName: String
    @ObservedObject private var service = CarrierService.shared
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
                        if let sim = service.sims.first(where: { $0.slot == slot }),
                           service.autoMatchBundle(for: sim) {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Label("自动匹配", systemImage: "wand.and.stars")
                            Spacer()
                            if let sim = service.sims.first(where: { $0.slot == slot }),
                               let suggested = service.suggestedBundle(for: sim) {
                                Text(suggested)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("暂无")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(service.sims.first { $0.slot == slot }.flatMap(service.suggestedBundle(for:)) == nil)

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
