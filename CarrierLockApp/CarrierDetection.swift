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
    /// name Apple ships in /System/Library/Carrier Bundles/iPhone. Covers the
    /// carriers common on MEO/QPESIM setups; anything else falls back to
    /// manual entry.
    private static let bundleByPLMN: [String: String] = [
        // 中国大陆
        "46000": "CMCC_cn", "46002": "CMCC_cn", "46004": "CMCC_cn",
        "46007": "CMCC_cn", "46008": "CMCC_cn",
        "46001": "Unicom_cn", "46006": "Unicom_cn", "46009": "Unicom_cn",
        "46003": "CTC_china", "46005": "CTC_china", "46011": "CTC_china",
        // 美国运营商（有锁机常见）
        "310410": "ATT_us", "311180": "ATT_us",
        "310260": "TMobile_us", "310240": "TMobile_us", "312530": "TMobile_us",
        "310120": "Sprint_us",
        "311480": "Verizon_us",
        // 卡贴常用伪装运营商
        "23415": "Vodafone_UK",
        "26202": "Vodafone_de", "26203": "Vodafone_de",
        "21401": "Vodafone_es", "21406": "Vodafone_es",
        "22210": "Vodafone_it",
        "20801": "Orange_fr", "20802": "Orange_fr",
        "25001": "MTS_RU", "25002": "MegaFon_RU", "25099": "Beeline_RU",
        "25701": "MTS_by", "25702": "velcom_by",
    ]

    static func detect() -> CarrierDetection {
        var result = CarrierDetection()

        let info = CTTelephonyNetworkInfo()

        // iOS 12+ splits per eSIM/physical-SIM service. Try both spellings of
        // the API across OS versions; only one will be populated.
        // CTCarrier's MCC/MNC accessors are deprecated but still the only
        // public CoreTelephony surface that reports them without entitlements.
        // They work on iOS 18/26 for the active subscription.
        applyCarrier(info.subscriberCellularProvider, to: &result)

        if result.source == .unknown, result.imsiPrefix != nil {
            result.source = .carrierInfo
        }
        // CoreTelephony reports 65535 as a placeholder when the real PLMN is
        // unavailable (common on MEP setups). Hide that noise entirely.
        if result.mcc == "65535" || result.mnc == "65535" {
            result = CarrierDetection()
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
        if let mcc = carrier.mobileCountryCode, !mcc.isEmpty { result.mcc = mcc }
        if let mnc = carrier.mobileNetworkCode, !mnc.isEmpty { result.mnc = mnc }
        if let prefix = result.imsiPrefix {
            result.bundleName = bundleByPLMN[prefix] ?? result.bundleName
        }
    }
}
