import Combine
import Foundation

@MainActor
final class CarrierService: ObservableObject {
    enum Mode: Equatable {
        case idle
        case working
        case locking
        case locked
        case failed(String)
    }

    static let shared = CarrierService()

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var isWorking = false
    @Published private(set) var isCheckingStatus = false
    @Published private(set) var latestResult: CarrierSIMResult?
    @Published private(set) var device: CarrierDeviceInfo?
    @Published private(set) var sims: [CarrierSIMInfo] = []
    @Published private(set) var imsiLinks: [CarrierIMSILink] = []
    @Published private(set) var extraIMSILinks: [CarrierIMSILink] = []
    @Published private(set) var availableSlots: Set<String> = ["kOne", "kTwo"]
    @Published private(set) var needsRecovery = false
    @Published private(set) var hasLoadedStatus = false
    @Published private(set) var busyMessage: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isAfterSuccessfulApply = false

    @Published var selectedSlots: Set<String> {
        didSet {
            UserDefaults.standard.set(sortedSlots, forKey: Self.selectedSlotsKey)
        }
    }

    @Published var bundleBySlot: [String: String] {
        didSet {
            UserDefaults.standard.set(bundleBySlot, forKey: Self.bundleBySlotKey)
        }
    }

    @Published private(set) var automaticBundleSlots: Set<String> = []
    @Published private(set) var manualBundleIMSIs: Set<String> = []
    @Published private(set) var revealedIMSISlots: Set<String> = []
    @Published private(set) var imsiOverrides: [String: String] = [:]
    @Published private(set) var imsiOverrideSources: [String: String] = [:]

    private let transport = CarrierSIMTransport.shared
    private static let selectedSlotsKey = "carrierlock.selectedSlots"
    private static let bundleBySlotKey = "carrierlock.bundleBySlot"
    private static let automaticBundleSlotsKey = "carrierlock.automaticBundleSlots"
    private static let manualBundleIMSIsKey = "carrierlock.manualBundleIMSIs"
    private static let legacyManualBundleSlotsKey = "carrierlock.manualBundleSlots"
    private static let imsiOverridesKey = "carrierlock.imsiOverrides"
    private static let imsiOverrideSourcesKey = "carrierlock.imsiOverrideSources"

    init() {
        let savedSlots = UserDefaults.standard.stringArray(forKey: Self.selectedSlotsKey) ?? ["kOne", "kTwo"]
        let initialSlots = Set(savedSlots.filter { $0 == "kOne" || $0 == "kTwo" })
        self.selectedSlots = initialSlots.isEmpty ? ["kOne", "kTwo"] : initialSlots
        let savedBundles = UserDefaults.standard.dictionary(forKey: Self.bundleBySlotKey) as? [String: String] ?? [:]
        self.bundleBySlot = [
            "kOne": savedBundles["kOne"] ?? "CMCC_cn",
            "kTwo": savedBundles["kTwo"] ?? "CMCC_cn",
        ]
        self.automaticBundleSlots = Set(
            UserDefaults.standard.stringArray(forKey: Self.automaticBundleSlotsKey)?
                .filter { $0 == "kOne" || $0 == "kTwo" } ?? []
        )
        self.manualBundleIMSIs = Set(
            UserDefaults.standard.stringArray(forKey: Self.manualBundleIMSIsKey)?
                .filter { $0.count == 15 && $0.allSatisfy(\.isNumber) } ?? []
        )
        self.imsiOverrides = UserDefaults.standard.dictionary(forKey: Self.imsiOverridesKey) as? [String: String] ?? [:]
        self.imsiOverrideSources = UserDefaults.standard.dictionary(forKey: Self.imsiOverrideSourcesKey) as? [String: String] ?? [:]
    }

    var sortedSlots: [String] {
        ["kOne", "kTwo"].filter(selectedSlots.contains)
    }

    var needsAirliftSetup: Bool {
        let pairingPath = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: pairingPath)[.size] as? Int) ?? 0
        return size <= 0 || Bundle.main.url(forResource: "assets", withExtension: "zip") == nil
    }

    var canApply: Bool {
        guard hasLoadedStatus,
              !isWorking,
              !needsRecovery,
              !sortedSlots.isEmpty,
              selectedSlots.isSubset(of: availableSlots),
              latestResult?.canApply == true else {
            return false
        }
        return true
    }

    var selectedSims: [CarrierSIMInfo] {
        sims.filter { selectedSlots.contains($0.slot) }
    }

    var allSelectedSimsLocked: Bool {
        guard hasLoadedStatus, !selectedSims.isEmpty else { return false }
        return selectedSims.allSatisfy { sim in
            imsiLinks.contains { $0.imsi == effectiveIMSI(for: sim) }
        }
    }

    func bundle(for slot: String) -> String {
        bundleBySlot[slot] ?? "CMCC_cn"
    }

    func isAutomaticBundle(for slot: String) -> Bool {
        automaticBundleSlots.contains(slot)
    }

    func suggestedBundle(for sim: CarrierSIMInfo) -> String? {
        Self.suggestedBundle(mcc: sim.mcc, mnc: sim.mnc)
    }

    func autoMatchBundle(for sim: CarrierSIMInfo) -> Bool {
        guard let suggested = suggestedBundle(for: sim) else { return false }
        bundleBySlot[sim.slot] = suggested
        manualBundleIMSIs.remove(effectiveIMSI(for: sim))
        automaticBundleSlots.insert(sim.slot)
        return true
    }

    func setBundle(_ bundle: String, for slot: String) {
        bundleBySlot[slot] = bundle
        if let sim = sims.first(where: { $0.slot == slot }) {
            manualBundleIMSIs.insert(effectiveIMSI(for: sim))
        }
        automaticBundleSlots.remove(slot)
    }

    func isIMSIRevealed(for slot: String) -> Bool {
        revealedIMSISlots.contains(slot)
    }

    func toggleIMSIReveal(for slot: String) {
        if revealedIMSISlots.contains(slot) {
            revealedIMSISlots.remove(slot)
        } else {
            revealedIMSISlots.insert(slot)
        }
    }

    func hasIMSIOverride(for slot: String) -> Bool {
        guard let sim = sims.first(where: { $0.slot == slot }) else { return false }
        return effectiveIMSI(for: sim) != sim.imsi
    }

    func effectiveIMSI(for sim: CarrierSIMInfo) -> String {
        guard let override = imsiOverrides[sim.slot],
              imsiOverrideSources[sim.slot] == sim.imsi,
              Self.isValidIMSI(override) else {
            return sim.imsi
        }
        return override
    }

    func setIMSIOverride(_ imsi: String, for sim: CarrierSIMInfo) {
        let normalized = imsi.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldIMSI = effectiveIMSI(for: sim)

        if normalized == sim.imsi || !Self.isValidIMSI(normalized) {
            imsiOverrides.removeValue(forKey: sim.slot)
            imsiOverrideSources.removeValue(forKey: sim.slot)
            revealedIMSISlots.remove(sim.slot)
        } else {
            imsiOverrides[sim.slot] = normalized
            imsiOverrideSources[sim.slot] = sim.imsi
        }

        if !automaticBundleSlots.contains(sim.slot), oldIMSI != normalized {
            manualBundleIMSIs.remove(oldIMSI)
            if Self.isValidIMSI(normalized) {
                manualBundleIMSIs.insert(normalized)
            }
        }

        persistIMSIOverrides()
        persistManualBundleIMSIs()
    }

    static func suggestedBundle(mcc: String, mnc: String) -> String? {
        let mcc = mcc.trimmingCharacters(in: .whitespacesAndNewlines)
        let mnc = mnc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mcc.count == 3, (2...3).contains(mnc.count),
              mcc.allSatisfy(\.isNumber), mnc.allSatisfy(\.isNumber) else {
            return nil
        }

        // Some lockdownd sources return 2-digit MNCs while bundle metadata uses
        // the decimal form without a leading zero (460+07 -> 46007).
        let candidates = [
            mcc + mnc,
            mnc.hasPrefix("0") ? mcc + String(mnc.dropFirst()) : nil
        ].compactMap { $0 }

        for candidate in candidates where CarrierBundlePLMNMap.bundleByPLMN[candidate] != nil {
            return CarrierBundlePLMNMap.bundleByPLMN[candidate]
        }
        return nil
    }

    func ensureInitialStatus() async {
        guard !hasLoadedStatus, !isWorking, !needsAirliftSetup else { return }
        await refreshStatus()
    }

    func refreshStatus() async {
        guard begin(action: .status, busyMessage: "正在检查运营商配置…") else { return }
        isCheckingStatus = true
        defer { finishWorking() }

        do {
            var result = try await transport.execute(
                action: .status,
                slots: sortedSlots,
                bundle: bundle(for: sortedSlots.first ?? "kOne")
            )

            if result.isFailure, sortedSlots.count == 2 {
                let one = try await transport.execute(
                    action: .status,
                    slots: ["kOne"],
                    bundle: bundle(for: "kOne")
                )
                let two = try await transport.execute(
                    action: .status,
                    slots: ["kTwo"],
                    bundle: bundle(for: "kTwo")
                )

                if !one.isFailure || !two.isFailure {
                    result = Self.mergeStatusResults(one, two)
                }
            }

            process(result, action: .status)
        } catch {
            process(error: error, action: .status)
        }
    }

    func apply() async {
        guard sortedSlots.count > 0 else {
            errorMessage = "请至少选择一个 SIM 卡槽。"
            return
        }
        await run(action: .apply, busyMessage: "正在锁定运营商配置…")
    }

    func restore() async {
        await run(action: .restore, busyMessage: "正在恢复…")
    }

    func recover() async {
        await run(action: .recover, busyMessage: "正在恢复未完成操作…")
    }

    func dismissFailure() {
        guard case .failed = mode else { return }
        mode = .idle
        errorMessage = nil
        busyMessage = nil
    }

    private func run(action: CarrierSIMAction, busyMessage: String) async {
        guard begin(action: action, busyMessage: busyMessage) else { return }
        defer { finishWorking() }

        do {
            var assignments: [String: String] = [:]
            if action == .apply {
                assignments = selectedSims.reduce(into: [:]) { result, sim in
                    result[effectiveIMSI(for: sim)] = bundle(for: sim.slot)
                }
            }

            let result = try await transport.execute(
                action: action,
                slots: sortedSlots,
                bundle: bundle(for: sortedSlots.first ?? "kOne"),
                assignments: assignments
            )
            process(result, action: action)
        } catch {
            process(error: error, action: action)
        }
    }

    private func begin(action: CarrierSIMAction, busyMessage: String) -> Bool {
        guard !isWorking else { return false }
        isAfterSuccessfulApply = false
        isWorking = true
        self.busyMessage = busyMessage
        errorMessage = nil
        statusMessage = nil
        if action == .status {
            isCheckingStatus = true
            mode = .working
        } else if action == .apply {
            mode = .locking
        } else {
            mode = .working
        }
        return true
    }

    private func finishWorking() {
        isWorking = false
        isCheckingStatus = false
        busyMessage = nil
    }

    private func process(_ result: CarrierSIMResult, action: CarrierSIMAction) {
        latestResult = result
        if let device = result.device {
            self.device = device
        }
        if !result.sims.isEmpty {
            var seenSlots = Set<String>()
            let uniqueSims = result.sims.filter { seenSlots.insert($0.slot).inserted }
            sims = uniqueSims.sorted { $0.displaySlot < $1.displaySlot }
            availableSlots = Set(uniqueSims.map(\.slot))
        }
        imsiLinks = result.imsiLinks
        extraIMSILinks = result.imsiLinks.filter { link in
            !sims.contains { effectiveIMSI(for: $0) == link.imsi }
        }
        needsRecovery = result.needsRecovery
        if action == .status {
            hasLoadedStatus = true
            reconcileSelectedSlots()
            reconcileIMSIOverrides()
            if !result.sims.isEmpty {
                autoSelectBundlesFromPLMN()
            }
        }

        if result.isFailure {
            let message = Self.localizedCarrierMessage(result.rawError ?? result.message ?? result.reason)
            errorMessage = message
            statusMessage = nil
            mode = .failed(message)
            return
        }

        errorMessage = nil
        if action == .status, !selectedStatusText(result).isEmpty {
            statusMessage = selectedStatusText(result)
        } else {
            statusMessage = Self.statusText(for: result, action: action)
        }
        if action == .apply, result.returnCode == 0 {
            mode = .locked
            isAfterSuccessfulApply = true
        } else {
            mode = .idle
        }
    }

    private func process(error: Error, action: CarrierSIMAction) {
        let message = Self.localizedCarrierMessage(error.localizedDescription)
        errorMessage = message
        statusMessage = nil
        if action == .status {
            hasLoadedStatus = true
        }
        mode = .failed(message)
    }

    private func reconcileSelectedSlots() {
        if !selectedSlots.isSubset(of: availableSlots) {
            selectedSlots = selectedSlots.intersection(availableSlots)
        }
        if selectedSlots.isEmpty {
            selectedSlots = availableSlots
        }
    }

    private func autoSelectBundlesFromPLMN() {
        var selections = bundleBySlot
        var automaticSlots = Set<String>()
        migrateLegacyManualBundleSlotsIfNeeded()
        for sim in sims {
            guard !manualBundleIMSIs.contains(effectiveIMSI(for: sim)) else { continue }
            guard let suggested = Self.suggestedBundle(mcc: sim.mcc, mnc: sim.mnc) else {
                automaticSlots.remove(sim.slot)
                continue
            }
            selections[sim.slot] = suggested
            automaticSlots.insert(sim.slot)
        }

        bundleBySlot = selections
        automaticBundleSlots = automaticSlots
        UserDefaults.standard.set(Array(automaticSlots), forKey: Self.automaticBundleSlotsKey)
        persistManualBundleIMSIs()
    }

    /// Migration from the old slot-based manual selection. The first successful
    /// status after update transfers the preference to the IMSI currently in
    /// that slot, so changing the card later returns to automatic matching.
    private func migrateLegacyManualBundleSlotsIfNeeded() {
        let legacySlots = Set(
            UserDefaults.standard.stringArray(forKey: Self.legacyManualBundleSlotsKey)?
                .filter { $0 == "kOne" || $0 == "kTwo" } ?? []
        )
        guard !legacySlots.isEmpty else { return }

        for sim in sims where legacySlots.contains(sim.slot) {
            manualBundleIMSIs.insert(effectiveIMSI(for: sim))
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyManualBundleSlotsKey)
        persistManualBundleIMSIs()
    }

    private func persistManualBundleIMSIs() {
        UserDefaults.standard.set(Array(manualBundleIMSIs), forKey: Self.manualBundleIMSIsKey)
    }

    private func persistIMSIOverrides() {
        UserDefaults.standard.set(imsiOverrides, forKey: Self.imsiOverridesKey)
        UserDefaults.standard.set(imsiOverrideSources, forKey: Self.imsiOverrideSourcesKey)
    }

    private func reconcileIMSIOverrides() {
        var changed = false
        for (slot, source) in imsiOverrideSources {
            guard let sim = sims.first(where: { $0.slot == slot }) else { continue }
            if sim.imsi != source {
                imsiOverrides.removeValue(forKey: slot)
                imsiOverrideSources.removeValue(forKey: slot)
                revealedIMSISlots.remove(slot)
                changed = true
            }
        }
        if changed {
            persistIMSIOverrides()
        }
    }

    private static func isValidIMSI(_ imsi: String) -> Bool {
        imsi.count == 15 && imsi.allSatisfy(\.isNumber)
    }

    private static func mergeStatusResults(_ one: CarrierSIMResult, _ two: CarrierSIMResult) -> CarrierSIMResult {
        let deviceJSON = (one.device ?? two.device).map(deviceJSON(_:))
        var seenSlots = Set<String>()
        let mergedSims = (one.sims + two.sims).filter { seenSlots.insert($0.slot).inserted }
        let simsJSON = mergedSims
            .sorted { $0.displaySlot < $1.displaySlot }
            .map(simJSON(_:))
        let object: [String: Any] = [
            "action": "status",
            "device": deviceJSON ?? NSNull(),
            "sims": simsJSON,
            "imsi_links": (one.imsiLinks + two.imsiLinks).map { ["imsi": $0.imsi, "bundle": $0.bundle] },
            "needs_recovery": one.needsRecovery || two.needsRecovery,
            "can_apply": one.canApply && two.canApply,
            "reason": one.reason ?? two.reason ?? NSNull(),
            "warning": one.warning ?? two.warning ?? NSNull(),
            "catalog_verified": one.catalogVerified || two.catalogVerified,
            "commcenter_verified": one.commcenterVerified || two.commcenterVerified,
            "error": one.error && two.error,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        let raw = String(data: data, encoding: .utf8) ?? ""
        return (try? CarrierSIMResult(returnCode: 0, rawJSON: raw, rawError: nil)) ?? one
    }

    private static func deviceJSON(_ device: CarrierDeviceInfo) -> [String: Any] {
        [
            "identity_hash": device.identityHash,
            "name": device.name,
            "model": device.model,
            "hardware": device.hardware,
            "ios": device.ios,
            "build": device.build,
            "activated": device.activated,
        ]
    }

    private static func simJSON(_ sim: CarrierSIMInfo) -> [String: Any] {
        [
            "slot": sim.slot,
            "mcc": sim.mcc,
            "mnc": sim.mnc,
            "imsi": sim.imsi,
            "carrier": sim.carrier,
            "version": sim.version,
        ]
    }

    private static func statusText(for result: CarrierSIMResult, action: CarrierSIMAction) -> String {
        switch action {
        case .status:
            if result.needsRecovery {
                return "检测到上次操作尚未完成。请先点击“恢复未完成操作”。"
            }
            if result.imsiLinks.isEmpty {
                return "未检测到 IMSI 链接。如需固定运营商配置，请继续锁定。"
            }
            if let reason = result.reason, !reason.isEmpty {
                return localizedCarrierMessage(reason)
            }
            if result.canApply {
                return "当前设备可以锁定。请确认 SIM 卡槽和运营商配置后继续。"
            }
            return "已读取设备状态。"
        case .apply:
            if result.returnCode == 0 {
                return "锁定成功。已写入并回读确认 IMSI 链接，建议开关一次飞行模式，让系统重新读取配置。"
            }
            return localizedCarrierMessage(result.message) 
        case .restore:
            if result.isFullyVerified {
                return "已恢复默认运营商选择。"
            }
            if result.returnCode == 2 {
                return "恢复目录已确认，CommCenter 尚未确认最终选择。建议开关一次飞行模式。"
            }
            return localizedCarrierMessage(result.message)
        case .recover:
            return localizedCarrierMessage(result.message)
        }
    }

    private func selectedStatusText(_ result: CarrierSIMResult) -> String {
        guard !sims.isEmpty else { return "" }
        let lockedSims = sims.filter { sim in
            result.imsiLinks.contains { $0.imsi == effectiveIMSI(for: sim) }
        }
        if lockedSims.count == sims.count {
            return "已锁定。所有 SIM 的 IMSI 链接都已存在，无需重复写入。"
        }
        if !lockedSims.isEmpty {
            return "部分 SIM 已锁定，还有 SIM 未锁定。请选择未锁定的 SIM 后继续锁定。"
        }
        return ""
    }

    static func localizedCarrierWarning(_ warning: String) -> String {
        if warning.lowercased().contains("версия") {
            return "当前 iOS 版本不在 CarrierSIM 原始验证范围内，操作可能不完全兼容。"
        }
        return warning
    }

    private static func localizedCarrierMessage(_ message: String?) -> String {
        guard let message, !message.isEmpty else {
            return "CarrierSIM 未返回详细说明。"
        }

        let lower = message.lowercased()
        if lower.contains("незаверш") ||
            lower.contains("прошлая операция") ||
            lower.contains("сначала нажмите") ||
            lower.contains("сначала восстанов") {
            return "上次操作未完成。请先点击“恢复未完成操作”，保留的备份会自动处理。"
        }
        if lower.contains("не активирован") || lower.contains("активирован") {
            return "iPhone 未激活，无法执行该操作。"
        }
        if lower.contains("сим") ||
            lower.contains("слот") ||
            lower.contains("выберите") ||
            lower.contains("найдена") ||
            lower.contains("доступна") {
            return "SIM 卡槽选择无效或所选 SIM 不可用，请检查 SIM 1/2 后重试。"
        }
        if lower.contains("версия ios") || lower.contains("сборки") {
            return "当前 iOS 版本不在 CarrierSIM 原始验证范围内，操作可能不完全兼容。"
        }
        if lower.contains("файл сопряжения") {
            return "配对文件不可用，请重新完成连接引导。"
        }
        if lower.contains("commcenter") {
            return "CommCenter 尚未确认运营商选择，请开关一次飞行模式后重试。"
        }
        return message
    }
}
