import SwiftUI
struct CarrierLockAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = CarrierService.shared
    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.teal)
                            .frame(width: 78, height: 78)
                            .background(.teal.opacity(0.12), in: .circle)

                        Text("CarrierLock")
                            .font(.title2.bold())
                        Text(versionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("简介") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CarrierLock 通过 Airlift 将运营商配置的符号链接写入 Overlay 目录，让 CommCenter 直接命中本地配置，减少卡贴日常使用中的跳激活。")
                        Text("支持系统：\(SystemCompatibility.supportedRangeDescription)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("跳激活的原因") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("卡贴会修改或伪装 SIM 上报给系统的网络标识。CommCenter 在重启、基带复位或 SIM 重新注册后，需要根据 IMSI/ICCID 重新选择运营商配置；当匹配结果不稳定或需要重新走激活流程时，系统会弹出“需要激活”。")
                        Text("夜间待机、长时间充电、Wi-Fi 环境下更容易发生，是因为系统会进行维护任务、网络切换或基带复位，从而触发重新匹配。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("锁定 IPCC 的目的") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("锁定是在 Overlay 中为指定 IMSI 建立到系统运营商配置的链接。匹配成功后，CommCenter 优先使用本地 Overlay 配置，减少联网匹配。")
                        Text("适合用于减少卡贴日常使用、重启、基带复位后的跳激活。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("无法实现的功能") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("不能解锁网络锁，也不能绕过运营商激活策略。", systemImage: "xmark.circle")
                        Label("不能阻止卡贴主动切换 IMSI 或改变上报标识。", systemImage: "xmark.circle")
                        Label("不能阻止 MEP 卡贴在开机时弹出的激活引导；弹出后请及时完成激活，否则可能出现屏幕方向锁定、无法接收消息通知等问题。", systemImage: "xmark.circle")
                        Label("不能修改系统只读分区、基带配置或需要 root 权限的文件。", systemImage: "xmark.circle")
                        Label("不能保证在更换 SIM、系统更新或 Airlift 失效后继续可用。", systemImage: "xmark.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("法律与免责声明") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本软件仅供个人学习、研究和维护本人拥有或已获授权的设备使用。下载、安装或使用本软件均属于个人自发行为，使用者应自行确认符合当地法律法规、运营商条款及相关平台协议。")
                        Text("本软件按“现状”提供，开发者不提供任何明示或默示保证，也不对因使用本软件导致的设备异常、数据丢失、业务中断、账户风险或法律后果承担责任。请在理解相关风险后自行决定是否使用。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                resetCarrierCard

                Section("运行日志") {
                    Label("日志包含配对、回环连接和 AirLift 文件操作。", systemImage: "list.bullet.rectangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ShareLink(item: CarrierLockLog.shared.exportText()) {
                        Label("导出日志", systemImage: "square.and.arrow.up")
                    }
                    Button("清空日志", role: .destructive) {
                        CarrierLockLog.shared.clear()
                    }
                    .font(.footnote)
                }

                Section("开源地址") {
                    Link(destination: URL(string: "https://github.com/Li-ong-o/CarrierLock")!) {
                        Label {
                            Text("查看源码")
                        } icon: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.teal)
                        }
                    }
                }
            }
            .navigationTitle("软件介绍")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "确认重置运营商配置？",
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("删除整个用户态 Carrier 目录", role: .destructive) {
                    Task { await service.resetCarrierConfiguration() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作只清空 /var/mobile/Library/Carrier Bundles/iPhone，不会修改 /System/Library/Carrier Bundles。")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var resetCarrierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Label("重置运营商配置", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("清空用户态 Carrier Overlay，恢复系统默认配置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("将删除用户态 Carrier Overlay 目录中的全部项目，让 CommCenter 回退到系统自带运营商配置。不会修改系统只读分区，也不会删除系统运营商 Bundle。删除后可重新初始化，或插入 SIM 让系统重新生成 Overlay 目录。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 12))

            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Label("重置运营商配置", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(service.mode == .locking || service.isCheckingStatus)

            if let message = service.verifyMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.3"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "7"
        return "版本 \(version) (\(build))"
    }
}

#Preview {
    CarrierLockAboutView()
}
