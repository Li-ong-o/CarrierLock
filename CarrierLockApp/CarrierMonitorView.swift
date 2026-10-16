import SwiftUI

struct CarrierMonitorView: View {
    @ObservedObject private var monitor = CarrierMonitor.shared
    @ObservedObject private var service = CarrierService.shared
    @State private var confirmingRespring = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("自动获取 IMSI 并锁定", systemImage: "waveform.path.ecg")
                        .font(.headline)

                    Text(monitorDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if monitor.state == .listening {
                    ProgressView()
                }
            }

            detectionCard

            operationGuideCard

            if !monitor.imsiCandidates.isEmpty {
                imsiCandidatesCard
            }

            if !monitor.matchedBundles.isEmpty {
                matchedBundlesCard
            }

            if !monitor.events.isEmpty {
                eventList
            }

            HStack(spacing: 10) {
                if monitor.state == .listening || monitor.state == .starting {
                    Button(role: .destructive) {
                        monitor.stop()
                    } label: {
                        Label("停止监听", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        monitor.start(expectedBundles: service.monitoredBundleNames)
                    } label: {
                        Label("开始监听", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    confirmingRespring = true
                } label: {
                    Label("重启桌面", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(monitor.respringing)
            }

            if monitor.state != .listening {
                Text("如果长期没有 bundle lookup，请点“开始监听”后再点“重启桌面”强制 CommCenter 重新匹配。国家/地区 Map（如 China_Map）不参与锁定判定。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .confirmationDialog(
            "立即重启桌面？",
            isPresented: $confirmingRespring,
            titleVisibility: .visible
        ) {
            Button("重启桌面", role: .destructive) {
                Task { await monitor.respring() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("SpringBoard 会重启，CommCenter 会重新扫描运营商配置。CarrierLock 会短暂关闭。")
        }
    }

    private var operationGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("操作步骤", systemImage: "list.number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                guideRow(1, "在 CarrierLock 点击“开始监听”")
                guideRow(2, "切到卡贴程序，刷新一次 SIM 卡信号")
                guideRow(3, "回到这里，点选日志捕获到的真实 IMSI")
                guideRow(4, "确认 bundle 后点击“锁定运营商配置”")
            }
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private func guideRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .frame(width: 18, height: 18)
                .background(Color.teal.opacity(0.14), in: .circle)
                .foregroundStyle(.teal)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var imsiCandidatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("从日志捕获的 IMSI", systemImage: "number.square")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(monitor.imsiCandidates).sorted(), id: \.self) { candidate in
                Button {
                    if service.selectedIMSIs.contains(candidate) {
                        service.toggleDetectedIMSI(candidate)
                    } else {
                        service.selectDetectedIMSI(candidate)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(candidate)
                                    .font(.callout.monospaced())
                                if isLikelyRealIMSI(candidate) {
                                    Text("疑似真实 IMSI")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.teal.opacity(0.14), in: .capsule)
                                        .foregroundStyle(.teal)
                                }
                            }
                            Text(service.bundle(forIMSI: candidate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if service.selectedIMSIs.contains(candidate) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.teal)
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("点一下即可加入多 IMSI 锁定列表，并自动匹配 bundle。可以同时勾选真实 IMSI、卡贴上报 IMSI 和双卡 IMSI。仍建议优先核对真实 IMSI；误选明显错误的 IMSI 可能导致配置匹配异常。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private var detectionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: detectionSymbol)
                .foregroundStyle(detectionColor)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text(detectionTitle)
                    .font(.subheadline.weight(.semibold))

                if let bundle = detectionBundle {
                    Text(bundle)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }

                if let date = monitor.detectedAt {
                    Text(date, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if case .noLogs = monitor.detection, let date = monitor.lastActivityAt {
                    Text("最近解析：\(Text(date, style: .time))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近的 CommCenter 事件")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(monitor.events.reversed().prefix(8)) { event in
                Text(event.text)
                    .font(.caption2.monospaced())
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private var monitorDescription: String {
        switch monitor.state {
        case .idle:
            "尚未开始监听。"
        case .starting:
            "正在连接设备 syslog…"
        case .listening:
            "正在监听。现在请到卡贴程序里刷新 SIM 卡信号。"
        case .stopped:
            "监听已停止。可重新开始监听。"
        case .failed(let message):
            message
        }
    }

    private var detectionTitle: String {
        switch monitor.detection {
        case .noLogs:
            String(localized: "尚未看到新的 bundle 解析")
        case .matched:
            "已匹配指定运营商配置"
        case .mismatch:
            "加载了不同的运营商配置"
        }
    }

    private var matchedBundlesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本次监听看到的 bundle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(monitor.matchedBundles).sorted(), id: \.self) { bundle in
                Text(bundle)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private var detectionBundle: String? {
        switch monitor.detection {
        case .noLogs: nil
        case .matched(let bundle): bundle
        case .mismatch(let expected, let found): "\(expected) → \(found)"
        }
    }

    private var detectionSymbol: String {
        switch monitor.detection {
        case .noLogs: "hourglass"
        case .matched: "lock.fill"
        case .mismatch: "lock.open"
        }
    }

    private var detectionColor: Color {
        switch monitor.detection {
        case .noLogs: .secondary
        case .matched: .green
        case .mismatch: .orange
        }
    }

    private func isLikelyRealIMSI(_ imsi: String) -> Bool {
        guard let prefix = CarrierDetectionService.prefixCandidate(for: imsi),
              CarrierDetectionService.bundle(for: prefix) != nil else { return false }

        // Adapter-generated identities often contain obvious artificial repetition (e.g. 000, 888)
        // or straight ascending/descending sequences (e.g. 1234, 4321).
        let middle = String(imsi.dropFirst(prefix.count).dropLast())
        guard middle.count >= 6 else { return false }
        let digits = middle.compactMap { $0.wholeNumberValue }

        // Check for 3 or more repeated digits
        var maxRepeat = 1
        var currentRepeat = 1
        for i in 1..<digits.count {
            if digits[i] == digits[i - 1] {
                currentRepeat += 1
                maxRepeat = max(maxRepeat, currentRepeat)
            } else {
                currentRepeat = 1
            }
        }
        if maxRepeat >= 3 { return false }

        // Check for 4 or more sequential digits
        var maxAsc = 1, currentAsc = 1
        var maxDesc = 1, currentDesc = 1
        for i in 1..<digits.count {
            if digits[i] == digits[i - 1] + 1 {
                currentAsc += 1
                maxAsc = max(maxAsc, currentAsc)
            } else {
                currentAsc = 1
            }
            if digits[i] == digits[i - 1] - 1 {
                currentDesc += 1
                maxDesc = max(maxDesc, currentDesc)
            } else {
                currentDesc = 1
            }
        }
        if maxAsc >= 4 || maxDesc >= 4 { return false }

        return true
    }
}
