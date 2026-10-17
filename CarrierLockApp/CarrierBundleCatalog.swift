import Foundation

enum CarrierBundleCatalog {
    static let preferred: [String] = [
        "ATT_US",
        "ATT_NR_US",
        "CMCC_cn",
        "CMCC_CMI",
        "CBN_cn",
        "ChinaUnicom_cn",
        "ChinaTelecom_USIM_cn",
        "Vodafone_uk",
        "Vodafone_de",
    ]

    static let all: [String] = CarrierBundleList.allBundles
}
