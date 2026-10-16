"""
CarrierLock - Carrier Bundle Catalog and PLMN Mapping
"""

CARRIER_PLMN_MAP = {
    # 中国广电
    "46015": ("CBN_cn", "中国广电 5G"),
    # 中国联通
    "46001": ("Unicom_cn", "中国联通 4G/5G"),
    "46006": ("Unicom_cn", "中国联通 4G/5G"),
    "46009": ("Unicom_cn", "中国联通 4G/5G"),
    # 中国移动
    "46000": ("CMCC_cn", "中国移动 4G/5G"),
    "46002": ("CMCC_cn", "中国移动 4G/5G"),
    "46004": ("CMCC_cn", "中国移动 4G/5G"),
    "46007": ("CMCC_cn", "中国移动 4G/5G"),
    "46008": ("CMCC_cn", "中国移动 4G/5G"),
    # 中国电信
    "46003": ("ChinaTelecom_USIM_cn", "中国电信 4G/5G"),
    "46005": ("ChinaTelecom_USIM_cn", "中国电信 4G/5G"),
    "46011": ("ChinaTelecom_USIM_cn", "中国电信 4G/5G"),
    # 港澳台
    "45407": ("CT_HK_cn", "中国电信香港"),
    "45412": ("CT_HK_cn", "中国电信香港"),
    "45502": ("CT_Macau_cn", "中国电信澳门"),
    "45507": ("CT_Macau_cn", "中国电信澳门"),
    "45400": ("HK_CSL_cn", "香港 CSL"),
    "45402": ("HK_CSL_cn", "香港 CSL"),
    "45418": ("HK_CSL_cn", "香港 CSL"),
    "45406": ("SmarTone_HK_cn", "香港数码通"),
    "46692": ("Chunghwa_tw", "中华电信"),
    "46697": ("TaiwanMobile_tw", "台湾大哥大"),
    "46601": ("FarEasTone_tw", "远传电信"),
}

POPULAR_BUNDLES = [
    ("CBN_cn", "中国广电 (CBN_cn)"),
    ("Unicom_cn", "中国联通 (Unicom_cn)"),
    ("CMCC_cn", "中国移动 (CMCC_cn)"),
    ("ChinaTelecom_USIM_cn", "中国电信 (ChinaTelecom_USIM_cn)"),
    ("CT_HK_cn", "中国电信香港 (CT_HK_cn)"),
    ("CT_Macau_cn", "中国电信澳门 (CT_Macau_cn)"),
    ("HK_CSL_cn", "香港 CSL (HK_CSL_cn)"),
    ("SmarTone_HK_cn", "香港数码通 (SmarTone_HK_cn)"),
    ("Chunghwa_tw", "中华电信 (Chunghwa_tw)"),
    ("TaiwanMobile_tw", "台湾大哥大 (TaiwanMobile_tw)"),
    ("FarEasTone_tw", "远传电信 (FarEasTone_tw)"),
    ("TMobile_US", "T-Mobile US (TMobile_US)"),
    ("ATT_US", "AT&T (ATT_US)"),
    ("Verizon_LTE_US", "Verizon (Verizon_LTE_US)"),
]

def guess_bundle_for_imsi(imsi: str) -> tuple[str, str] | None:
    if not imsi or len(imsi) < 5:
        return None
    prefix5 = imsi[:5]
    if prefix5 in CARRIER_PLMN_MAP:
        return CARRIER_PLMN_MAP[prefix5]
    prefix6 = imsi[:6]
    if prefix6 in CARRIER_PLMN_MAP:
        return CARRIER_PLMN_MAP[prefix6]
    return None
