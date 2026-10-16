import CoreTelephony
import Foundation

struct CarrierDetection {
    var imsi: String?
    var mcc: String?
    var mnc: String?
    var bundleName: String?
    var source: Source = .unknown

    enum Source {
        case imsiAPI
        case carrierInfo
        case unknown
    }

    var imsiPrefix: String? {
        guard let mcc, let mnc else { return nil }
        return mcc + mnc
    }

    var displayText: String? {
        switch source {
        case .imsiAPI:
            if let imsi, imsi.count == 15 {
                return "IMSI \(imsi) · \(bundleName ?? "?")"
            }
            if let prefix = imsiPrefix {
                return "运营商 \(prefix) · \(bundleName ?? "?")，IMSI 请补全"
            }
            return bundleName.map { "运营商 bundle \($0)" }
        case .carrierInfo:
            if let prefix = imsiPrefix {
                return "运营商 \(prefix) · \(bundleName ?? "?")"
            }
            return bundleName.map { "运营商 bundle \($0)" }
        case .unknown:
            return nil
        }
    }
}

enum CarrierDetectionService {
    /// Maps the SIM's reported PLMN (MCC+MNC) to the carrier-bundle folder
    /// name Apple ships in /System/Library/Carrier Bundles/iPhone. Names are
    /// verified against CarrierBundleList.allBundles (extracted from iOS):
    /// Unicom is "Unicom_cn" (not "China_Unicom") and Telecom is
    /// "ChinaTelecom_USIM_cn" (not "CTC_china") on modern iOS. Covers the
    /// carriers common on MEO/QPESIM setups; anything else falls back to
    /// manual entry.
    private static let bundleByPLMN: [String: String] = [
        // 中国大陆（含 46015 中国广电）
        "46000": "CMCC_cn", "46002": "CMCC_cn", "46004": "CMCC_cn",
        "46007": "CMCC_cn", "46008": "CMCC_cn",
        "46001": "Unicom_cn", "46006": "Unicom_cn", "46009": "Unicom_cn", "46010": "Unicom_cn",
        "46003": "ChinaTelecom_USIM_cn", "46005": "ChinaTelecom_USIM_cn",
        "46011": "ChinaTelecom_USIM_cn", "46012": "ChinaTelecom_USIM_cn",
        "46015": "CBN_cn",
        // 美国运营商（修正大小写与实际系统 Bundle 名）
        "310410": "ATT_US", "311180": "ATT_US",
        "310260": "TMobile_US", "310240": "TMobile_US", "312530": "TMobile_US",
        "310120": "Sprint_ISIM_LTE_US",
        "311480": "Verizon_LTE_US",
        // 卡贴常用伪装运营商（修正大小写与真实 Bundle 名）
        "23415": "Vodafone_uk",
        "26202": "Vodafone_de", "26203": "Vodafone_de",
        "21401": "Vodafone_es", "21406": "Vodafone_es",
        "22210": "Vodafone_it",
        "20801": "Orange_France", "20802": "Orange_France",
        "25001": "MTS_ru", "25002": "MegaFon_ru", "25099": "VimpelCom_ru",
        "25701": "MTS_by", "25702": "mobilkom_by",
    ]

    static func detect() -> CarrierDetection {
        var result = CarrierDetection()
        let info = CTTelephonyNetworkInfo()

        // Modern iOS 12+ multi-SIM providers
        if let providers = info.serviceSubscriberCellularProviders {
            for (_, carrier) in providers {
                applyCarrier(carrier, to: &result)
                if result.bundleName != nil { break }
            }
        }
        if result.bundleName == nil {
            applyCarrier(info.subscriberCellularProvider, to: &result)
        }

        if result.source == .unknown, (result.imsiPrefix != nil || result.bundleName != nil) {
            result.source = .carrierInfo
        }
        if result.mcc == "65535" || result.mnc == "65535" {
            result.mcc = nil
            result.mnc = nil
        }
        return result
    }

    static func prefixCandidate(for imsi: String) -> String? {
        // MCC is always 3 digits. Try 3-digit MNC first (US), then 2-digit
        // (China/Europe), and keep whichever has a known bundle mapping.
        guard imsi.count == 15, imsi.allSatisfy({ $0.isNumber }) else { return nil }
        for mncLength in [3, 2] {
            let prefix = String(imsi.prefix(3 + mncLength))
            if bundleByPLMN[prefix] != nil { return prefix }
        }
        return String(imsi.prefix(5))
    }

    static func bundle(for prefix: String) -> String? {
        bundleByPLMN[prefix]
    }

    private static func applyCarrier(_ carrier: CTCarrier?, to result: inout CarrierDetection) {
        guard let carrier else { return }
        if let mcc = carrier.mobileCountryCode, !mcc.isEmpty, mcc != "65535" { result.mcc = mcc }
        if let mnc = carrier.mobileNetworkCode, !mnc.isEmpty, mnc != "65535" { result.mnc = mnc }
        if let prefix = result.imsiPrefix {
            result.bundleName = bundleByPLMN[prefix] ?? result.bundleName
        }
        // Carrier name heuristic fallback (handles iOS 16.4+ where PLMN is obscured)
        if result.bundleName == nil, let name = carrier.carrierName {
            if name.contains("广电") {
                result.bundleName = "CBN_cn"
            } else if name.contains("移动") {
                result.bundleName = "CMCC_cn"
            } else if name.contains("联通") {
                result.bundleName = "Unicom_cn"
            } else if name.contains("电信") {
                result.bundleName = "ChinaTelecom_USIM_cn"
            } else if name.localizedCaseInsensitiveContains("AT&T") {
                result.bundleName = "ATT_US"
            } else if name.localizedCaseInsensitiveContains("T-Mobile") {
                result.bundleName = "TMobile_US"
            } else if name.localizedCaseInsensitiveContains("Verizon") {
                result.bundleName = "Verizon_LTE_US"
            }
        }
    }

    static func queryActiveSIMSlots() -> [ActiveSIMSlot] {
        let info = CTTelephonyNetworkInfo()
        var list: [ActiveSIMSlot] = []
        if let providers = info.serviceSubscriberCellularProviders {
            let sortedKeys = providers.keys.sorted()
            for (index, key) in sortedKeys.enumerated() {
                if let carrier = providers[key] {
                    var det = CarrierDetection()
                    applyCarrier(carrier, to: &det)
                    let cName = carrier.carrierName ?? "未知运营商"
                    let mcc = det.mcc ?? ""
                    let mnc = det.mnc ?? ""
                    let plmn = (mcc.isEmpty || mnc.isEmpty) ? "" : (mcc + mnc)
                    list.append(ActiveSIMSlot(
                        slotIndex: index + 1,
                        carrierName: cName,
                        mcc: mcc,
                        mnc: mnc,
                        plmn: plmn,
                        activeBundle: det.bundleName
                    ))
                }
            }
        }
        return list
    }
}

struct ActiveSIMSlot: Identifiable, Sendable {
    let id = UUID()
    let slotIndex: Int
    let carrierName: String
    let mcc: String
    let mnc: String
    let plmn: String
    let activeBundle: String?
}

