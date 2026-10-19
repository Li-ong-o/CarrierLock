import SwiftUI
struct CarrierLockAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = CarrierService.shared

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
                        Text("CarrierLock 的作用很简单：把你的 SIM IMSI 和某个运营商配置 Bundle“绑定”起来。锁定后，系统重启、基带复位或卡贴重新注册时，不需要反复猜该用哪个配置，从而减少配置漂移和跳激活。")
                        Text("支持系统：\(SystemCompatibility.supportedRangeDescription)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("跳激活的原因") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("卡贴会把自己伪装成某种运营商信息。手机重启、基带复位或 SIM 重新注册后，系统会重新判断该用哪个运营商配置。这个判断一旦不稳定，系统就可能要求重新激活。")
                        Text("晚上待机、长时间插着充电、Wi-Fi 环境下更容易发生，因为这时系统常做维护、切网或复位基带，容易触发重新匹配。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("锁定运营商 Bundle 的目的") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("锁定时会为你的 IMSI 创建一个指向运营商配置 Bundle 的链接。写入前会先备份，写入后会回读确认链接已经存在。")
                        Text("它主要让配置选择更稳定：重启、基带复位、卡贴重新注册后，减少 CommCenter 反复匹配带来的配置漂移。")
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
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
