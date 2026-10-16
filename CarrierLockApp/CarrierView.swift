import SwiftUI

struct CarrierLockRootView: View {
    @StateObject private var service = CarrierService.shared
    @ObservedObject private var monitor = CarrierMonitor.shared
    @State private var showingAbout = false
    @State private var showingAirliftSetup = false
    @State private var showingBundlePicker = false
    @State private var editingIMSI: String?
    @State private var showingStartupGate = !PairingController.hasValidPairingFile()
    @State private var confirmingLock = false
    @State private var showingManualIMSIInput = false
    @State private var manualIMSI = ""
    @State private var showingIMEIWarning = false
    @State private var showingVerificationAlert = false
    @State private var verificationReport = ""

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

                    configurationCard
                    lockButton
                    verifyButton
                    restoreButton
                    CarrierMonitorView()
                    details
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
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
            service.dismissFailure()
        }) {
            CarrierLockAirliftSetupView()
        }
        .sheet(isPresented: $showingBundlePicker) {
            CarrierBundlePickerSheet(
                bundleName: Binding(
                    get: {
                        if let imsi = editingIMSI {
                            return service.bundle(forIMSI: imsi)
                        }
                        return service.bundleName
                    },
                    set: { value in
                        if let imsi = editingIMSI {
                            service.customBundlesByIMSI[imsi] = value
                        } else {
                            service.selectBundle(value)
                        }
                    }
                )
            )
            .presentationDetents([.large])
        }
        .alert("手动添加 IMSI", isPresented: $showingManualIMSIInput) {
            TextField("输入 15 位 IMSI", text: $manualIMSI)
                .keyboardType(.numberPad)
            Button("从剪贴板粘贴") {
                pasteIMSIFromClipboard()
            }
            Button("添加") {
                commitManualIMSI()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请输入完整的 15 位数字 SIM 卡 IMSI（国内通常以 460 开头）。可在爱思助手【设备详情】或下方监听中获取。")
        }
        .alert("疑似输入了 IMEI (手机串号)", isPresented: $showingIMEIWarning) {
            Button("仍然添加", role: .destructive) {
                let trimmed = manualIMSI.trimmingCharacters(in: .whitespacesAndNewlines)
                service.selectDetectedIMSI(trimmed)
            }
            Button("重新输入", role: .cancel) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingManualIMSIInput = true
                }
            }
        } message: {
            Text("您输入的号码以 35/86 开头，这是 iPhone 的硬件串号 (IMEI) 而非 SIM 卡的 IMSI。国内 SIM 卡的 IMSI 必定以 460 开头（可在电脑爱思助手【查看设备详情】中复制 InternationalMobileSubscriberIdentity）。锁定 IMEI 无法生效。")
        }
        .alert("锁定生效验证", isPresented: $showingVerificationAlert) {
            Button("知道了") {}
        } message: {
            Text(verificationReport)
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

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 默认目标运营商配置
            VStack(alignment: .leading, spacing: 8) {
                Label("目标运营商配置 (Carrier Bundle)", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)

                Button {
                    editingIMSI = nil
                    showingBundlePicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(service.bundleName)
                                .font(.body.weight(.semibold).monospaced())
                                .foregroundStyle(.primary)
                            Text(bundleDisplayName(for: service.bundleName))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("更换配置")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tint)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 待锁定 IMSI 列表与手动添加
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("待锁定 IMSI 列表", systemImage: "simcard.2")
                        .font(.headline)
                    Spacer()
                    Button {
                        manualIMSI = ""
                        showingManualIMSIInput = true
                    } label: {
                        Label("手动添加", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if service.selectedIMSIs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("暂无选中的 IMSI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("可在下方「自动获取 IMSI 并锁定」开始监听捕获，或点击右上角「手动添加」直接输入 15 位 IMSI。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill).opacity(0.6), in: .rect(cornerRadius: 10))
                } else {
                    ForEach(service.selectedIMSIs, id: \.self) { imsi in
                        HStack(spacing: 10) {
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
                            .controlSize(.small)

                            Button(role: .destructive) {
                                service.toggleDetectedIMSI(imsi)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
                    }
                }
            }

            Text("每个 IMSI 会按 PLMN 自动匹配对应 bundle；支持单卡或双卡独立配置与锁定。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func bundleDisplayName(for bundle: String) -> String {
        switch bundle {
        case "CMCC_cn": return "中国移动"
        case "Unicom_cn": return "中国联通"
        case "ChinaTelecom_USIM_cn": return "中国电信"
        case "CBN_cn": return "中国广电"
        case "ATT_US", "ATT_NR_US": return "AT&T (美国)"
        case "TMobile_US": return "T-Mobile (美国)"
        case "Verizon_LTE_US": return "Verizon (美国)"
        case "Vodafone_uk": return "Vodafone (英国)"
        case "Vodafone_de": return "Vodafone (德国)"
        default: return "自定义/系统配置"
        }
    }

    private var lockButton: some View {
        VStack(spacing: 8) {
            Button {
                confirmingLock = true
            } label: {
                Label("锁定运营商配置", systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(service.selectedIMSIs.isEmpty || isBusy)

            if service.selectedIMSIs.isEmpty {
                Text("请先添加或选择至少一个 IMSI")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var verifyButton: some View {
        Button {
            runActiveVerification()
        } label: {
            Label("验证锁定生效状态", systemImage: "checkmark.seal.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
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
                ? "尚未选择 IMSI，请先开始监听并开关飞行模式。"
                : "已选择 \(service.selectedIMSIs.count) 个 IMSI，确认后可锁定。"
        case .locking:
            "正在写入运营商配置链接。"
        case .locked:
            imsiDetail.isEmpty ? "已成功锁定运营商配置。" : "已锁定：\(imsiDetail)"
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

    private func pasteIMSIFromClipboard() {
        guard let clip = UIPasteboard.general.string else { return }
        let all15Digits = clip.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { $0.count == 15 }
        if let imsiMatch = all15Digits.first(where: { $0.hasPrefix("460") }) {
            manualIMSI = imsiMatch
            return
        }
        let digitsOnly = clip.filter(\.isNumber)
        if digitsOnly.count == 15 {
            manualIMSI = digitsOnly
            return
        }
        if let any15 = all15Digits.first {
            manualIMSI = any15
            return
        }
        manualIMSI = clip.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitManualIMSI() {
        let trimmed = manualIMSI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 15, trimmed.allSatisfy(\.isNumber) else { return }
        if trimmed.hasPrefix("35") || trimmed.hasPrefix("86") {
            showingIMEIWarning = true
        } else {
            service.selectDetectedIMSI(trimmed)
        }
    }

    private func runActiveVerification() {
        let slots = CarrierDetectionService.queryActiveSIMSlots()
        if slots.isEmpty {
            verificationReport = "未检测到活跃的 SIM 卡，请确保已插入物理 SIM 卡或启用了 eSIM。"
            showingVerificationAlert = true
            return
        }

        var lines: [String] = []
        var allPassed = true

        for slot in slots {
            let activeBundle = slot.activeBundle ?? "未知配置"
            var matchedExpected = false
            var expectedName = service.bundleName

            for imsi in service.selectedIMSIs {
                let expected = service.bundle(forIMSI: imsi)
                if expected == slot.activeBundle || (slot.plmn.count >= 5 && imsi.hasPrefix(slot.plmn)) {
                    matchedExpected = true
                    expectedName = expected
                    break
                }
            }

            if matchedExpected || service.monitoredBundleNames.contains(activeBundle) {
                lines.append("✅ 【\(slot.slotName)】\(slot.carrierName) (\(slot.plmn))\n   • 已挂载配置：\(activeBundle)\n   • 状态：锁定已生效！")
            } else {
                allPassed = false
                lines.append("❌ 【\(slot.slotName)】\(slot.carrierName) (\(slot.plmn))\n   • 当前加载：\(activeBundle)\n   • 期望目标：\(expectedName)\n   • 状态：尚未命中目标配置")
            }
        }

        if allPassed {
            lines.append("🎉 验证通过：活跃 SIM 卡已成功挂载目标运营商配置！")
        } else {
            lines.append("💡 提示：如果刚刚执行了锁定，请下拉控制中心打开【飞行模式】等待 5 秒再关闭，待信号重载后再次点击验证。")
        }

        verificationReport = lines.joined(separator: "\n\n")
        showingVerificationAlert = true
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

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredBundles: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return CarrierBundleCatalog.all.filter { $0.lowercased().contains(query) }
    }

    @ViewBuilder
    private func bundleRow(_ bundle: String) -> some View {
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
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .monospaced()

                        Button("使用自定义 Bundle") {
                            let input = customBundle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let canonical = CarrierBundleCatalog.canonicalName(for: input) ?? input
                            bundleName = canonical
                            dismiss()
                        }
                        .disabled(!isValid)
                    }
                }

                if !customMode {
                    if isSearching {
                        Section("搜索结果") {
                            ForEach(filteredBundles, id: \.self) { bundle in
                                bundleRow(bundle)
                            }
                        }
                    } else {
                        Section("常用配置") {
                            ForEach(CarrierBundleCatalog.preferred, id: \.self) { bundle in
                                bundleRow(bundle)
                            }
                        }

                        Section("全部配置") {
                            ForEach(CarrierBundleCatalog.all, id: \.self) { bundle in
                                bundleRow(bundle)
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
                _ = try await AirliftEngine.shared.detectPosterBoardContainer(pairingPath: path)
                status = .ready
            } catch {
                status = .setupRequired
                errorMessage = "LocalDevVPN 探测失败：\(error.localizedDescription)"
            }
        }
    }
}
