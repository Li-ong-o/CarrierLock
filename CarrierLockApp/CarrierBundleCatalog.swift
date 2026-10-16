import Foundation

enum CarrierBundleCatalog {
    static let preferred: [String] = [
        "CMCC_cn",
        "Unicom_cn",
        "ChinaTelecom_USIM_cn",
        "CBN_cn",
        "CMCC_CMI",
        "ATT_US",
        "ATT_NR_US",
        "TMobile_US",
        "Verizon_LTE_US",
        "Vodafone_uk",
        "Vodafone_de",
    ]

    static let all: [String] = CarrierBundleList.allBundles
    static let allSet: Set<String> = Set(CarrierBundleList.allBundles)

    private static let canonicalMap: [String: String] = {
        var map = [String: String]()
        for bundle in CarrierBundleList.allBundles {
            map[bundle.lowercased()] = bundle
        }
        return map
    }()

    static func canonicalName(for name: String) -> String? {
        canonicalMap[name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }
}
