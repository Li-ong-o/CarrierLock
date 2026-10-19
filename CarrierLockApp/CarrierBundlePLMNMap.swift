import Foundation

enum CarrierBundlePLMNMap {
    // Generated from iOS 27.0.1 carrier bundle metadata and mcc-mnc.csv.
    // Keys are normalized PLMN digits without leading zero.
    static let bundleByPLMN: [String: String] = [
        "20201": "TMobile_gr", // Cosmote / Greece
        "20205": "Vodafone_gr", // Vodafone / Greece
        "20210": "Wind_gr", // Wind / Greece
        "20404": "Vodafone_nl", // Vodafone / Netherlands
        "20408": "KPN_nl", // KPN / Netherlands
        "20412": "KPN_Telfort_nl", // Telfort / Netherlands
        "20416": "TMobile_nl", // Odido / Netherlands
        "20469": "KPN_nl", // KPN Mobile The Netherlands B.V. / Netherlands
        "20601": "Proximus_be", // Proximus / Belgium
        "20605": "Telenet_be", // Telenet / Belgium
        "20610": "Mobistar_be", // Orange Belgium / Belgium
        "20620": "BASE_be", // Base / Belgium
        "20628": "BICS", // BICS / Belgium
        "20801": "Orange_France", // Orange / France
        "20802": "Orange_France", // Orange / France
        "20809": "Coriolis_fr", // SFR / France
        "20810": "SFR_fr", // SFR / France
        "20811": "Coriolis_fr", // SFR / France
        "20812": "Truphone_US", // Truphone / France
        "20813": "Coriolis_fr", // SFR / France
        "20815": "Free_fr", // Free Mobile / France
        "20820": "Bouygues_fr", // Bouygues / France
        "20826": "NRJ_fr", // NRJ Mobile / France
        "20827": "Coriolis_fr", // Coriolis Telecom / France
        "21210": "MonacoTel_mc", // Office des Telephones / Monaco
        "21303": "Mobiland_ad", // Mobiland / Andorra
        "21401": "Vodafone_es", // Vodafone / Spain
        "21402": "vivo_br", // Altecom/Fibracat / Spain
        "21403": "Orange_es", // Orange / Spain
        "21404": "Yoigo_es", // Yoigo / Spain
        "21405": "Telefonica_eSimFLAG", // Movistar / Spain
        "21406": "Vodafone_Lowi_es", // Vodafone / Spain
        "21407": "movistar_sv", // Movistar / Spain
        "21427": "Truphone_US", // Truphone / Spain
        "21601": "Telenor_hu", // Telenor Hungary / Hungary
        "21630": "TMobile_hu", // T-Mobile / Hungary
        "21670": "Vodafone_hu", // Vodafone / Hungary
        "21805": "TelekomSrbija_ba", // m:tel BiH / Bosnia and Herzegovina
        "21890": "TelekomSlovenije_ba", // BH Mobile / Bosnia and Herzegovina
        "21901": "TMobile_hr", // T-Mobile / Croatia
        "21902": "Telemach_hr", // Tele2 / Croatia
        "21910": "mobilkom_hr", // A1 / Croatia
        "22001": "Telenor_rs", // Telenor / Serbia
        "22003": "TelekomSrbija_rs", // mts / Serbia
        "22005": "mobilkom_rs", // VIP / Serbia
        "22102": "TelekomSlovenije_xk", // IPKO / Kosovo
        "22201": "TIM_Kena_it", // TIM / Italy
        "22207": "TIM_Kena_it", // Kena Mobile / Italy
        "22208": "Fastweb_it", // Fastweb / Italy
        "22210": "Vodafone_it", // Vodafone / Italy
        "22250": "Iliad_it", // Iliad / Italy
        "22288": "Wind_Very_it", // Wind / Italy
        "22299": "Wind_Very_it", // 3 Italia / Italy
        "22601": "Vodafone_ro", // Vodafone / Romania
        "22603": "TMobile_ro", // Telekom / Romania
        "22606": "TMobile_ro", // Telekom/Zapp / Romania
        "22610": "Orange_ro", // Orange / Romania
        "22801": "Swisscom_ch", // Swisscom / Switzerland
        "22802": "Sunrise_ch", // Sunrise / Switzerland
        "22803": "Orange_ch", // Salt / Switzerland
        "22860": "Sunrise_ch", // Sunrise / Switzerland
        "23001": "TMobile_cz", // T-Mobile / Czech Republic
        "23002": "O2_cz", // O2 / Czech Republic
        "23003": "Vodafone_cz", // Vodafone / Czech Republic
        "23101": "Orange_sk", // Orange / Slovakia
        "23102": "TMobile_sk", // Telekom / Slovakia
        "23106": "O2_sk", // O2 / Slovakia
        "23201": "mobilkom_at", // A1.net / Austria
        "23202": "mobilkom_at", // A1 Telekom Austria / Austria
        "23203": "TMobile_at", // Magenta / Austria
        "23205": "One_at", // 3 / Austria
        "23207": "TMobile_at", // tele.ring / Austria
        "23210": "Hutchison_at", // 3 / Austria
        "23211": "mobilkom_at", // bob / Austria
        "23212": "mobilkom_at", // yesss! / Austria
        "23223": "TMobile_at", // Magenta / Austria
        "23402": "O2_Sky_uk", // O2 (UK) / United Kingdom
        "23408": "BT_OnePhone_uk", // BT OnePhone / United Kingdom
        "23410": "O2_UK", // O2 (UK) / United Kingdom
        "23411": "O2_Sky_uk", // O2 (UK) / United Kingdom
        "23415": "Vodafone_uk", // Vodafone UK / United Kingdom
        "23420": "Hutchison_uk", // 3 / United Kingdom
        "23425": "Truphone_US", // Truphone / United Kingdom
        "23430": "TMobile_uk", // T-Mobile UK / United Kingdom
        "23433": "Orange_uk", // Orange / United Kingdom
        "23450": "JerseyTelecom_je", // JT / United Kingdom
        "23453": "Tango", // Limitless Mobile Ltd / United Kingdom
        "23455": "Sure_im", // Sure Mobile / Jersey (UK)
        "23457": "eSIMGO", // Sky UK Limited / United Kingdom
        "23458": "ManxTelecom_im", // Pronto GSM / United Kingdom
        "23801": "TDC_dk", // TDC / Denmark
        "23802": "Telenor_dk", // Telenor / Denmark
        "23806": "Hutchison_dk", // 3 / Denmark
        "23820": "Telia_dk", // Telia / Denmark
        "23830": "Telia_dk", // Interactive digital media GmbH / Denmark
        "23866": "Telia_dk", // TT-Netværket P/S / Denmark
        "23877": "Telenor_dk", // Telenor / Denmark
        "24001": "Telia_se", // Telia / Sweden
        "24002": "Hutchison_se", // 3 / Sweden
        "24004": "Telenor_se", // SWEDEN / Sweden
        "24005": "Telia_se", // Sweden 3G / Sweden
        "24007": "Tele2_se", // Tele2 / Sweden
        "24008": "Telenor_se", // Telenor / Sweden
        "24024": "Telenor_se", // Sweden 2G / Sweden
        "24042": "Uros", // Telenor Connexion AB / Sweden
        "24201": "Telenor_no", // Telenor / Norway
        "24202": "NetworkNorway_no", // Telia / Norway
        "24205": "NetworkNorway_no", // Telia / Norway
        "24214": "Ice_no", // ice / Norway
        "24403": "DNA_fi", // DNA / Finland
        "24405": "elisa_fi", // Elisa / Finland
        "24412": "DNA_fi", // DNA / Finland
        "24414": "Alcom_ax", // Ålcom / Finland
        "24421": "Saunalahti_fi", // Elisa- Saunalahti / Finland
        "24491": "Sonera_fi", // Telia / Finland
        "24601": "Omnitel_lt", // Telia / Lithuania
        "24602": "Bite_lt", // BITĖ / Lithuania
        "24603": "Tele2_lt", // Tele2 / Lithuania
        "24608": "CarrierLab", // MEZON / Lithuania
        "24701": "LMT_lv", // LMT / Latvia
        "24702": "Tele2_lv", // Tele2 / Latvia
        "24705": "Bite_lv", // Bite / Latvia
        "24801": "EMT_ee", // Telia / Estonia
        "24802": "Elisa_ee", // Elisa / Estonia
        "24803": "Tele2_ee", // Tele2 / Estonia
        "25001": "MTS_ru", // MTS / Russian Federation
        "25002": "MegaFon_ru", // MegaFon / Russian Federation
        "25011": "MegaFon_Yota_ru", // Yota / Russian Federation
        "25020": "Tele2_ru", // Tele2 / Russian Federation
        "25050": "Tele2_Sberbank_ru", // MTS / Russian Federation
        "25099": "VimpelCom_ru", // Beeline / Russian Federation
        "25501": "MTS_ua", // Vodafone / Ukraine
        "25503": "Kyivstar_ua", // Kyivstar / Ukraine
        "25506": "Turkcell_lifecell_ua", // lifecell / Ukraine
        "25507": "MTS_ua", // 3Mob; Lycamobile / Ukraine
        "25701": "mobilkom_by", // A1 / Belarus
        "25702": "MTS_by", // MTS / Belarus
        "25704": "life_by", // life:) / Belarus
        "25901": "Orange_md", // Orange / Moldova
        "25902": "Telia_md", // Moldcell / Moldova
        "26001": "Polkomtel_pl", // Plus / Poland
        "26002": "TMobile_pl", // T-Mobile / Poland
        "26003": "Orange_pl", // Orange / Poland
        "26006": "Play_pl", // Play / Poland
        "26033": "Truphone_US", // Truphone / Poland
        "26201": "TMobile_Germany", // Telekom / Germany
        "26202": "Vodafone_de", // Vodafone / Germany
        "26203": "O2_1and1_de", // O2 / Germany
        "26206": "TMobile_Germany", // Telekom / Germany
        "26207": "O2_Debitel_de", // O2 / Germany
        "26223": "1and1_de", // Drillisch Online AG / Germany
        "26242": "Truphone_US", // CCC Event / Germany
        "26278": "TMobile_Germany", // Telekom / Germany
        "26601": "TelekomSlovenije_gi", // GibTel / Gibraltar (UK)
        "26801": "Vodafone_pt", // Vodafone / Portugal
        "26803": "Optimus_pt", // NOS / Portugal
        "26806": "TMN_pt", // MEO / Portugal
        "27001": "MTX_lu", // POST / Luxembourg
        "27002": "MTX_lu", // MTX Connect S.a.r.l. / Luxembourg
        "27077": "Tango_lu", // Tango / Luxembourg
        "27099": "VOX_lu", // Orange / Luxembourg
        "27201": "Vodafone_ie", // Vodafone / Ireland
        "27202": "O2_ie", // 3 / Ireland
        "27203": "Meteor_ie", // Eir / Ireland
        "27205": "Hutchison_ie", // 3 / Ireland
        "27401": "Siminn_is", // Síminn / Iceland
        "27402": "Vodafone_is", // Vodafone / Iceland
        "27411": "Nova_is", // Nova / Iceland
        "27601": "TMobile_al", // Telekom.al / Albania
        "27602": "Vodafone_al", // Vodafone / Albania
        "27801": "Vodafone_mt", // Vodafone / Malta
        "27821": "GoMobile_mt", // GO / Malta
        "27877": "Melita_mt", // Melita / Malta
        "28001": "Cyta_cy", // Cytamobile-Vodafone / Cyprus
        "28010": "MTN_cy", // Epic / Cyprus
        "28020": "PrimeTel_cy", // PrimeTel / Cyprus
        "28022": "Cablenet_cy", // lemontel / Cyprus
        "28201": "Telia_ge", // Geocell / Georgia
        "28202": "Magticom_ge", // Magti / Georgia
        "28204": "VimpelCom_ge", // Beeline / Georgia
        "28301": "VimpelCom_am", // Beeline / Armenia
        "28305": "MTS_am", // VivaCell-MTS / Armenia
        "28310": "Orange_am", // Ucom / Armenia
        "28401": "mobilkom_bg", // A1 / Bulgaria
        "28403": "Vivacom_bg", // Vivacom / Bulgaria
        "28405": "TMobile_bg", // Telenor / Bulgaria
        "28601": "Turkcell_tr", // Turkcell / Turkey
        "28602": "Vodafone_tr", // Vodafone / Turkey
        "28603": "AVEA_tr", // Türk Telekom / Turkey
        "28604": "AVEA_tr", // Aycell / Turkey
        "28801": "FaroeseTelecom_fo", // Faroese Telecom / Faroe Islands
        "29001": "TELE_gl", // TELE Greenland A/S / Greenland
        "29340": "mobilkom_si", // A1 / Slovenia
        "29341": "Telekom_si", // Mobitel / Slovenia
        "29370": "Telemach_si", // Telemach / Slovenia
        "29401": "TMobile_mk", // Telekom.mk / North Macedonia
        "29402": "TelekomSlovenije_mk", // vip / North Macedonia
        "29403": "mobilkom_mk", // vip / North Macedonia
        "29502": "Orange_li", // 7acht / Liechtenstein
        "29505": "TelecomLiechtenstein_li", // FL1 / Liechtenstein
        "29510": "Soracom", // Soracom LI Ltd. / Liechtenstein
        "29701": "Telenor_me", // Telenor / Montenegro
        "29702": "TMobile_me", // T-Mobile / Montenegro
        "29703": "TelekomSrbija_me", // m:tel CG / Montenegro
        "302130": "Xplornet_ca", // Xplornet / Canada
        "302220": "Telus_ca", // Telus Mobility, Koodo Mobile, Public Mobile / Canada
        "302221": "Telus_ca", // Telus / Canada
        "302222": "Telus_ca", // Telus / Canada
        "302270": "Eastlink_ca", // EastLink / Canada
        "302320": "Rogers_chatr_ca", // Rogers Wireless / Canada
        "302370": "Fido_ca", // Fido / Canada
        "302490": "FreedomMobile_ca", // Freedom Mobile / Canada
        "302500": "Videotron_ca", // Videotron / Canada
        "302520": "Videotron_ca", // Videotron / Canada
        "302610": "Bell_ca", // Bell Mobility / Canada
        "302630": "Bell_ca", // Aliant Mobility / Canada
        "302640": "Bell_ca", // Bell / Canada
        "302690": "KnowRoaming", // Bell / Canada
        "302720": "Tbaytel_ca", // Rogers Wireless / Canada
        "302780": "Sasktel_ca", // SaskTel / Canada
        "302880": "Telus_ca", // Bell / Telus / SaskTel / Canada
        "310014": "Comcast_NR_US", //  / United States of America
        "310020": "UnionWireless_US", // Union Wireless / United States of America
        "310030": "ATT_US", // AT&T / United States of America
        "310110": "ITE_gu", // IT&E Wireless / United States of America
        "310120": "Sprint_ISIM_LTE_US", // Sprint / United States of America
        "310130": "CarolinaWest_LTE_US", // Carolina West Wireless / United States of America
        "310140": "GTA_gu", // GTA Wireless / United States of America
        "310150": "ATT_aio_US", // AT&T / United States of America
        "310160": "TMobile_US", // T-Mobile / United States of America
        "310170": "ATT_US", // AT&T / United States of America
        "310200": "TMobile_US", // T-Mobile / United States of America
        "310210": "TMobile_US", // T-Mobile / United States of America
        "310220": "TMobile_US", // T-Mobile / United States of America
        "310230": "TMobile_US", // T-Mobile / United States of America
        "310240": "TMobile_Wholesale_US", // T-Mobile / United States of America
        "310250": "TMobile_US", // T-Mobile / United States of America
        "310260": "TMobile_Wholesale_US", // T-Mobile / United States of America
        "310270": "TMobile_US", // T-Mobile / United States of America
        "310280": "ATT_US", // AT&T / United States of America
        "310300": "Truphone_US", // Big Sky Mobile / United States of America
        "310310": "TMobile_US", // T-Mobile / United States of America
        "310370": "Docomo_gu", // Docomo / United States of America
        "310380": "GigSky_US", // AT&T / United States of America
        "310410": "ATT_aio_US", // AT&T / United States of America
        "310450": "Viaero_US", // Viaero / United States of America
        "310470": "Docomo_gu", // NTT DoCoMo Pacific / United States of America
        "310480": "Choice_gu", // iConnect / United States of America
        "310490": "TMobile_US", // T-Mobile / United States of America
        "310560": "ATT_aio_US", // AT&T / United States of America
        "310580": "Inland_LTE_US", // Inland Cellular Telephone Company / United States of America
        "310590": "Verizon_TFW_LTE_US", // Verizon Wireless / United States of America
        "310660": "TMobile_US", // T-Mobile / United States of America
        "310800": "TMobile_US", // T-Mobile / United States of America
        "310830": "TMobile_US", // Sprint / United States of America
        "310840": "Telefonica_eSimFLAG", // telna Mobile / United States of America
        "310950": "ATT_US", // AT&T / United States of America
        "311040": "ATN_Viya_vi", // Choice Wireless / United States of America
        "311180": "ATT_US", // AT&T / United States of America
        "311230": "CellularSouth_LTE_US", // C Spire Wireless / United States of America
        "311320": "ATN_Viya_vi", // Choice Wireless / United States of America
        "311370": "GCI_US", // GCI Wireless / United States of America
        "311450": "PTCI_LTE_only_US", // PTCI / United States of America
        "311480": "Verizon_Visible_LTE_US", // Verizon / United States of America
        "311488": "Verizon_MVNO_US", // Verizon / United States of America
        "311490": "Sprint_ISIM_LTE_US", // Sprint / United States of America
        "311580": "USCellular_LTE_US", // U.S. Cellular / United States of America
        "311650": "UnitedWireless_LTE_US", // United Wireless / United States of America
        "311660": "TMobile_US", // Metro / United States of America
        "311780": "ASTCA_as", // ASTCA / United States of America
        "311840": "CellcomWI_LTE_US", // Cellcom / United States of America
        "311850": "Cellcom_LTE_US", // Cellcom / United States of America
        "311870": "Sprint_ISIM_LTE_US", // Boost Mobile / United States of America
        "311880": "Sprint_ISIM_LTE_US", // Sprint / United States of America
        "311882": "TMobile_US", // Sprint / United States of America
        "312130": "AppWire_LTE_US", // Appalachian Wireless / United States of America
        "312190": "Sprint_ISIM_LTE_US", // Sprint / United States of America
        "312250": "TMobile_US", // Sprint / United States of America
        "312290": "StrataNetwork_LTE_US", // STRATA / United States of America
        "312380": "CopperValleyTelecom_LTE_US", // Copper Valley Wireless / United States of America
        "312420": "NexTech_LTE_US", // Nex-Tech Wireless / United States of America
        "312480": "NemontWireless_LTE_US", // Nemont / United States of America
        "312530": "Sprint_ISIM_LTE_US", // Sprint / United States of America
        "312670": "ATT_FirstNet_US", // FirstNet / United States of America
        "312870": "GigSky_US", // GigSky Mobile, LLC / United States of America
        "313010": "CrossWireless_Bravado_LTE_US", // Bravado Wireless / United States of America
        "313100": "ATT_FirstNet_US", // FirstNet / United States of America
        "313110": "Docomo_gu", // FirstNet / United States of America
        "313340": "Dish_US", // Dish Network / United States of America
        "313390": "Altice_LTE_US", // Altice USA Wireless, Inc. / United States of America
        "315010": "NonPublicNetwork", // CBRS / United States of America
        "330110": "Claro_pr", // Claro Puerto Rico / Puerto Rico
        "330120": "OpenMobile_LTE_pr", // Open Mobile / Puerto Rico
        "334020": "Telcel_mx", // Telcel / Mexico
        "334050": "iusacell_mx", // AT&T / Unefon / Mexico
        "334090": "iusacell_mx", // AT&T / Mexico
        "338050": "Digicel_lc", // Digicel / Turks and Caicos Islands
        "338180": "CW_wi", // FLOW / Jamaica
        "34001": "Orange_mq", // Orange / French Antilles (France)
        "34002": "SFR_Caraibe_mq", // SFR Caraïbe / French Antilles (France)
        "34003": "Chippie_mf", // Chippie / French Antilles (France)
        "34009": "Free_mq", // Free / French Antilles (France)
        "34020": "Digicel_mq", // Digicel / French Antilles (France)
        "342600": "CW_wi", // FLOW / Barbados
        "344030": "APUA_ag", // APUA / Antigua and Barbuda
        "344920": "CW_wi", // FLOW / Antigua and Barbuda
        "346140": "CW_wi", // FLOW / Cayman Islands (UK)
        "348170": "CW_wi", // FLOW / British Virgin Islands (UK)
        "348770": "Digicel_vg", // Digicel / British Virgin Islands (UK)
        "352110": "CW_wi", // FLOW / Grenada
        "354860": "CW_wi", // FLOW / Montserrat (UK)
        "356110": "CW_wi", // FLOW / Saint Kitts and Nevis
        "358110": "CW_wi", // FLOW / Saint Lucia
        "360110": "CW_wi", // FLOW / Saint Vincent and the Grenadines
        "36269": "Digicel_cw", // Digicel / Former Netherlands Antilles
        "36291": "Chippie_cw", // Chippie / Former Netherlands Antilles
        "36301": "Setar_aw", // SETAR / Aruba
        "36302": "Digicel_aw", // Digicel / Aruba
        "36439": "CW_bs", // BTC / Bahamas
        "36449": "Aliv_bs", // Aliv / Bahamas
        "365840": "CW_wi", // FLOW / Anguilla (UK)
        "366110": "CW_wi", // FLOW / Dominica
        "37001": "Orange_do", // Altice / Dominican Republic
        "37002": "Claro_do", // Claro / Dominican Republic
        "37201": "Digicel_ht", // Voila / Haiti
        "37203": "Natcom_ht", // Natcom / Haiti
        "37412": "CW_tt", // bmobile / Trinidad and Tobago
        "374130": "Digicel_tt", // Digicel / Trinidad and Tobago
        "376350": "CW_wi", // FLOW / Turks and Caicos Islands
        "376360": "ATN_tc", // FLOW / Turks and Caicos Islands
        "40001": "Telia_az", // Azercell / Azerbaijan
        "40002": "Bakcell_az", // Bakcell / Azerbaijan
        "40004": "Azerfon_az", // Nar Mobile / Azerbaijan
        "40101": "VimpelCom_kz", // Beeline / Kazakhstan
        "40102": "Telia_kz", // Kcell / Kazakhstan
        "40177": "Tele2_kz", // Tele2.kz / Kazakhstan
        "40211": "BhutanTelecom_bt", // B-Mobile / Bhutan
        "40277": "TashiCell_bt", // TashiCell / Bhutan
        "40401": "Vodafone_in", // Vodafone India / India
        "40402": "BhartiAirtel_in", // AirTel / India
        "40403": "BhartiAirtel_in", // AirTel / India
        "40404": "Idea_in", // IDEA / India
        "40405": "Vodafone_in", // Vodafone India / India
        "40407": "Idea_in", // IDEA / India
        "40410": "BhartiAirtel_in", // AirTel / India
        "40411": "Vodafone_in", // Vodafone India / India
        "40412": "Idea_in", // IDEA / India
        "40413": "Vodafone_in", // Vodafone India / India
        "40414": "Idea_in", // IDEA / India
        "40415": "Vodafone_in", // Vodafone India / India
        "40416": "BhartiAirtel_in", // Airtel / India
        "40419": "Idea_in", // IDEA / India
        "40420": "Vodafone_in", // Vodafone India / India
        "40422": "Idea_in", // IDEA / India
        "40424": "Idea_in", // IDEA / India
        "40427": "Vodafone_in", // Vodafone India / India
        "40430": "Vodafone_in", // Vodafone India / India
        "40431": "BhartiAirtel_in", // AirTel / India
        "40440": "BhartiAirtel_in", // AirTel / India
        "40443": "Vodafone_in", // Vodafone India / India
        "40444": "Idea_in", // IDEA / India
        "40445": "BhartiAirtel_in", // Airtel / India
        "40446": "Vodafone_in", // Vodafone India / India
        "40449": "BhartiAirtel_in", // Airtel / India
        "40456": "Idea_in", // IDEA / India
        "40460": "Vodafone_in", // Vodafone India / India
        "40470": "BhartiAirtel_in", // AirTel / India
        "40478": "Idea_in", // IDEA / India
        "40482": "Idea_in", // IDEA / India
        "40484": "Vodafone_in", // Vodafone India / India
        "40486": "Vodafone_in", // Vodafone India / India
        "40487": "Idea_in", // IDEA / India
        "40488": "Vodafone_in", // Vodafone India / India
        "40489": "Idea_in", // IDEA / India
        "40490": "BhartiAirtel_in", // AirTel / India
        "40492": "BhartiAirtel_in", // AirTel / India
        "40493": "BhartiAirtel_in", // AirTel / India
        "40494": "BhartiAirtel_in", // AirTel / India
        "40495": "BhartiAirtel_in", // AirTel / India
        "40496": "BhartiAirtel_in", // AirTel / India
        "40497": "BhartiAirtel_in", // AirTel / India
        "40498": "BhartiAirtel_in", // AirTel / India
        "40551": "BhartiAirtel_in", // AirTel / India
        "40552": "BhartiAirtel_in", // AirTel / India
        "40553": "BhartiAirtel_in", // AirTel / India
        "40554": "BhartiAirtel_in", // AirTel / India
        "40555": "BhartiAirtel_in", // Airtel / India
        "40556": "BhartiAirtel_in", // AirTel / India
        "40566": "Vodafone_in", // Vodafone India / India
        "40567": "Vodafone_in", // Vodafone India / India
        "40570": "Idea_in", // IDEA / India
        "405750": "Vodafone_in", // Vodafone India / India
        "405751": "Vodafone_in", // Vodafone India / India
        "405752": "Vodafone_in", // Vodafone India / India
        "405753": "Vodafone_in", // Vodafone India / India
        "405754": "Vodafone_in", // Vodafone India / India
        "405755": "Vodafone_in", // Vodafone India / India
        "405756": "Vodafone_in", // Vodafone India / India
        "405799": "Idea_in", // IDEA / India
        "405840": "RelianceJio_in", // Jio / India
        "405845": "Idea_in", // IDEA / India
        "405846": "Idea_in", // IDEA / India
        "405848": "Idea_in", // IDEA / India
        "405849": "Idea_in", // IDEA / India
        "405850": "Idea_in", // IDEA / India
        "405852": "Idea_in", // IDEA / India
        "405853": "Idea_in", // IDEA / India
        "405854": "RelianceJio_in", // Jio / India
        "405855": "RelianceJio_in", // Jio / India
        "405856": "RelianceJio_in", // Jio / India
        "405857": "RelianceJio_in", // Jio / India
        "405858": "RelianceJio_in", // Jio / India
        "405859": "RelianceJio_in", // Jio / India
        "405860": "RelianceJio_in", // Jio / India
        "405861": "RelianceJio_in", // Jio / India
        "405862": "RelianceJio_in", // Jio / India
        "405863": "RelianceJio_in", // Jio / India
        "405864": "RelianceJio_in", // Jio / India
        "405865": "RelianceJio_in", // Jio / India
        "405866": "RelianceJio_in", // Jio / India
        "405867": "RelianceJio_in", // Jio / India
        "405868": "RelianceJio_in", // Jio / India
        "405869": "RelianceJio_in", // Jio / India
        "405870": "RelianceJio_in", // Jio / India
        "405871": "RelianceJio_in", // Jio / India
        "405872": "RelianceJio_in", // Jio / India
        "405873": "RelianceJio_in", // Jio / India
        "405874": "RelianceJio_in", // Jio / India
        "41001": "Mobilink_pk", // Jazz / Pakistan
        "41003": "Ufone_pk", // Ufone / Pakistan
        "41004": "Zong_pk", // Zong / Pakistan
        "41006": "Telenor_pk", // Telenor / Pakistan
        "41007": "Warid_pk", // Jazz / Pakistan
        "41201": "AWCC_af", // AWCC / Afghanistan
        "41220": "Roshan_af", // Roshan / Afghanistan
        "41250": "Etisalat_af", // Etisalat / Afghanistan
        "41301": "Mobitel_lk", // Mobitel / Sri Lanka
        "41302": "Dialog_lk", // Dialog / Sri Lanka
        "41305": "BhartiAirtel_lk", // Airtel / Sri Lanka
        "41308": "Hutchison_lk", // Hutch / Sri Lanka
        "41311": "KnowRoaming", // Dialog / Sri Lanka
        "41405": "Qtel_mm", // Ooredoo / Myanmar
        "41406": "Telenor_mm", // Telenor / Myanmar
        "41501": "Alfa_lb", // Alfa / Lebanon
        "41503": "Zain_lb", // Touch / Lebanon
        "41601": "Zain_jo", // zain JO / Jordan
        "41603": "Umniah_jo", // Umniah / Jordan
        "41677": "Orange_jo", // Orange / Jordan
        "41805": "Qtel_iq", // Asia Cell / Iraq
        "41820": "Zain_iq", // Zain / Iraq
        "41830": "Zain_iq", // Zain / Iraq
        "41840": "Korek_iq", // Korek / Iraq
        "41902": "Zain_kw", // zain KW / Kuwait
        "41903": "Qtel_kw", // K.S.C Ooredoo / Kuwait
        "41904": "Viva_kw", // STC / Kuwait
        "42001": "STC_sa", // Al Jawal (STC ) / Saudi Arabia
        "42003": "mobily_sa", // Mobily / Saudi Arabia
        "42004": "Zain_sa", // Zain SA / Saudi Arabia
        "42202": "Omantel_om", // Omantel / Oman
        "42203": "Qtel_om", // ooredoo / Oman
        "42204": "KnowRoaming", // Omantel / Oman
        "42402": "Etisalat_ae", // Etisalat / United Arab Emirates
        "42403": "du_ae", // du / United Arab Emirates
        "42501": "Orange_il", // Partner / Israel
        "42502": "Cellcom_il", // Cellcom / Israel
        "42503": "Pelephone_il", // Pelephone / Israel
        "42504": "Webbing", // Globalsim Ltd / Israel
        "42505": "Jawwal_ps", // Jawwal / Palestine
        "42506": "Qtel_ps", // Wataniya / Palestine
        "42507": "Orange_il", // Hot Mobile / Israel
        "42508": "Cellcom_Golan_il", // Golan Telecom / Israel
        "42510": "Orange_il", // Partner / Israel
        "42512": "PrimeMobile", // x2one / Israel
        "42528": "Orange_il", // PHI Networks / Israel
        "42601": "Batelco_bh", // Batelco / Bahrain
        "42602": "Zain_bh", // zain BH / Bahrain
        "42604": "Viva_bh", // STC / Bahrain
        "42701": "Qtel_qa", // ooredoo / Qatar
        "42702": "Vodafone_qa", // Vodafone / Qatar
        "42888": "Unitel_mn", // Unitel / Mongolia
        "42899": "MobiCom_mn", // Mobicom / Mongolia
        "42901": "NepalTelecom_np", // Namaste / NT Mobile / Sky Phone / Nepal
        "42902": "Ncell_np", // Ncell / Nepal
        "43404": "VimpelCom_uz", // Beeline / Uzbekistan
        "43408": "UZTelecom_uz", // UzMobile / Uzbekistan
        "43601": "Telia_tj", // Tcell / Tajikistan
        "43602": "Telia_tj", // Tcell / Tajikistan
        "43605": "VimpelCom_tj", // ZET-Mobile / Tajikistan
        "43701": "VimpelCom_kg", // Beeline / Kyrgyzstan
        "44010": "Docomo_jp", // NTT docomo / Japan
        "44011": "Rakuten_jp", // Rakuten Mobile Network, Inc. / Japan
        "44020": "Softbank_jp", // SoftBank / Japan
        "44051": "KDDI_UQ_LTE_only_jp", // au / Japan
        "44053": "Rakuten_jp", // au / Japan
        "44054": "KDDI_UQ_NR_jp", // au / Japan
        "45002": "KTF_kr", // KT / South Korea
        "45005": "SKT_kr", // SKTelecom / South Korea
        "45006": "LGU_kr", // LG U+ / South Korea
        "45008": "KTF_kr", // olleh / South Korea
        "45201": "Mobifone_vn", // MobiFone / Vietnam
        "45202": "VinaPhone_vn", // Vinaphone / Vietnam
        "45204": "Viettel_vn", // Viettel Mobile / Vietnam
        "45400": "Unicom_hk", // 1O1O / One2Free / New World Mobility / SUNMobile / Hong Kong
        "45402": "Unicom_hk", // CSL Limited / Hong Kong
        "45403": "Unicom_hk", // 3 / Hong Kong
        "45404": "Unicom_hk", // 3 (2G) / Hong Kong
        "45406": "SmarTone_hk", // SmarTone / Hong Kong
        "45407": "Unicom_hk", // China Unicom / Hong Kong
        "45408": "Truphone_US", // Truphone / Hong Kong
        "45410": "Unicom_hk", // New World Mobility / Hong Kong
        "45412": "CMCC_hk", // CMCC HK / Hong Kong
        "45413": "CMCC_hk", // CMCC HK / Hong Kong
        "45414": "Unicom_hk", // Hutchison Telecom / Hong Kong
        "45415": "SmarTone_hk", // SmarTone Mobile Communications Limited / Hong Kong
        "45416": "PCCW_hk", // PCCW Mobile (2G) / Hong Kong
        "45417": "SmarTone_hk", // SmarTone Mobile Communications Limited / Hong Kong
        "45418": "Unicom_hk", // CSL Limited / Hong Kong
        "45419": "Unicom_hk", // PCCW Mobile (3G) / Hong Kong
        "45420": "Unicom_hk", // PCCW Mobile (4G) / Hong Kong
        "45424": "Multibyte", // Multibyte Info Technology Ltd / Hong Kong
        "45431": "ChinaTelecom_hk", // CTExcel / Hong Kong
        "45435": "Webbing", // Webbing Hong Kong Ltd / Hong Kong
        "45500": "SmarTone_mo", // SmarTone / Macau (China)
        "45501": "CTM_mo", // CTM / Macau (China)
        "45503": "Hutchison_mo", // 3 / Macau (China)
        "45504": "CTM_mo", // CTM / Macau (China)
        "45505": "Hutchison_mo", // 3 / Macau (China)
        "45506": "SmarTone_mo", // SmarTone / Macau (China)
        "45507": "ChinaTelecom_USIM_mo", // China Telecom / Macau (China)
        "45601": "Cellcard_kh", // Cellcard / Cambodia
        "45602": "Smart_kh", // Smart / Cambodia
        "45605": "Smart_kh", // Smart / Cambodia
        "45606": "Smart_kh", // Smart / Cambodia
        "45608": "Metfone_kh", // Metfone / Cambodia
        "45611": "Seatel_kh", // SEATEL / Cambodia
        "45701": "Laotel_la", // LaoTel / Laos
        "45703": "Unitel_la", // Unitel / Laos
        "46000": "CMCC_cn", // China Mobile / China
        "46001": "Unicom_cn", // China Unicom / China
        "46002": "CMCC_cn", // China Mobile / China
        "46007": "CMCC_cn", // China Mobile / China
        "46008": "CMCC_cn", // China Mobile / China
        "46009": "Unicom_cn", // China Unicom / China
        "46011": "ChinaTelecom_USIM_cn", // China Telecom / China
        "46601": "FarEasTone_tw", // FarEasTone / Taiwan
        "46689": "Vibo_tw", // T Star / Taiwan
        "46690": "Vibo_tw", // T Star / Taiwan
        "46692": "Chunghwa_tw", // Chunghwa / Taiwan
        "46697": "TaiwanMobile_tw", // Taiwan Mobile / Taiwan
        "47001": "Grameenphone_bd", // Grameenphone / Bangladesh
        "47002": "Robi_bd", // Robi / Bangladesh
        "47003": "Banglalink_bd", // Banglalink / Bangladesh
        "47007": "Robi_BhartiAirtel_bd", // Airtel / Bangladesh
        "47201": "Dhiraagu_mv", // Dhiraagu / Maldives
        "47202": "Qtel_mv", // Ooredoo / Maldives
        "50212": "Maxis_my", // Maxis / Malaysia
        "502152": "Yes_my", // Yes / Malaysia
        "50216": "DiGi_my", // DiGi / Malaysia
        "50218": "UMobile_my", // U Mobile / Malaysia
        "50219": "Celcom_my", // Celcom / Malaysia
        "50501": "Telstra_au", // Telstra / Australia
        "50502": "Optus_au", // Optus / Australia
        "50503": "Vodafone_au", // Vodafone / Australia
        "50511": "Telstra_au", // Telstra / Australia
        "50538": "Truphone_US", // Truphone / Australia
        "50571": "Telstra_au", // Telstra / Australia
        "50572": "Telstra_au", // Telstra / Australia
        "51001": "Indosat_id", // Indosat Ooredoo / Indonesia
        "51009": "Smartfren_id", // Smartfren / Indonesia
        "51010": "Telkomsel_id", // Telkomsel / Indonesia
        "51011": "XL_id", // XL / Indonesia
        "51021": "Indosat_id", // IM3 / Indonesia
        "51028": "Smartfren_id", // Fren/Hepi / Indonesia
        "51089": "Indosat_id", // 3 / Indonesia
        "51402": "TimorTelecom_tl", // TT / East Timor
        "51502": "Globe_ph", // Globe / Philippines
        "51503": "Smart_ph", // SMART / Philippines
        "52000": "TrueH_th", // TrueMove H / my by CAT / Thailand
        "52001": "AIS_th", // AIS / Thailand
        "52003": "AIS_th", // AIS / Thailand
        "52004": "TrueH_th", // TrueMove H / Thailand
        "52005": "dtac_th", // dtac TriNet / LINE / Thailand
        "52018": "dtac_th", // dtac / Thailand
        "52047": "dtac_th", // dtac-T / LINE / TOT Mobile / Thailand
        "52501": "SingTel_sg", // SingTel / Singapore
        "52502": "Telefonica_eSimFLAG", // SingTel-G18 / Singapore
        "52503": "MobileOne_sg", // M1 / Singapore
        "52505": "StarHub_sg", // StarHub / Singapore
        "52801": "Imagine_bn", // TelBru / Brunei
        "52802": "Progresif_bn", // PCSB / Brunei
        "52803": "DSTCom_bn", // UNN / Brunei
        "52811": "DSTCom_bn", // DST / Brunei
        "53001": "Vodafone_nz", // Vodafone / New Zealand
        "53002": "Telecom_nz", // Telecom / New Zealand
        "53005": "Telecom_nz", // Spark / New Zealand
        "53024": "2degrees_nz", // 2degrees / New Zealand
        "53701": "bMobile_pg", // bmobile / Papua New Guinea
        "53703": "Digicel_pg", // Digicel / Papua New Guinea
        "53901": "TCC_to", // U-Call / Tonga
        "53988": "Digicel_to", // Digicel / Tonga
        "54002": "bMobile_sb", // BeMobile / Solomon Islands
        "54101": "Orange_vu", // SMILE / Vanuatu
        "54105": "Digicel_vu", // Digicel / Vanuatu
        "54201": "Vodafone_fj", // Vodafone / Fiji
        "54202": "Digicel_fj", // Digicel / Fiji
        "54301": "SPT_wf", // Manuia / Wallis and Futuna
        "54411": "Bluesky_as", // Bluesky / American Samoa (USA)
        "54501": "Vodafone_ki", // Kiribati - ATH / Kiribati
        "54601": "OPT_nc", // Mobilis / New Caledonia (France)
        "54705": "Ora_pf", // Ora / French Polynesia (France)
        "54720": "Vini_pf", // Vini / French Polynesia (France)
        "54801": "TelecomCook_ck", // Bluesky / Cook Islands (Pacific Ocean)
        "54900": "Digicel_ws", // Digicel / Samoa
        "54927": "Bluesky_ws", // Bluesky / Samoa
        "55001": "FSMTC_fm", // FSMTC / Federated States of Micronesia
        "55201": "PNCC_pw", // PNCC / Palau
        "60201": "mobinil_eg", // Orange / Egypt
        "60202": "Vodafone_eg", // Vodafone / Egypt
        "60203": "Etisalat_eg", // Etisalat / Egypt
        "60204": "TelecomEgypt_eg", // WE / Egypt
        "60301": "Mobilis_dz", // Mobilis / Algeria
        "60302": "Djezzy_dz", // Djezzy / Algeria
        "60303": "Qtel_dz", // Ooredoo / Algeria
        "60400": "Meditel_ma", // Orange Morocco / Morocco
        "60401": "Maroc_ma", // IAM / Morocco
        "60402": "INWI_ma", // INWI / Morocco
        "60501": "Orange_tn", // Orange / Tunisia
        "60502": "Tuntel_tn", // Tunicell / Tunisia
        "60503": "Qtel_tn", // OOREDOO TN / Tunisia
        "60601": "Almadar_ly", // Madar / Libya
        "60801": "Orange_sn", // Orange / Senegal
        "60802": "Tigo_sn", // Tigo / Senegal
        "61002": "Orange_ml", // Orange / Mali
        "61101": "Orange_gn", // Orange / Guinea
        "61202": "Etisalat_ci", // Moov / Ivory Coast
        "61203": "Orange_ci", // Orange / Ivory Coast
        "61205": "MTN_ci", // MTN / Ivory Coast
        "61302": "BhartiAirtel_bf", // Orange / Burkina Faso
        "61402": "BhartiAirtel_ne", // Airtel / Niger
        "61404": "Orange_ne", // Orange / Niger
        "61602": "Etisalat_bj", // Moov / Benin
        "61603": "MTN_bj", // MTN / Benin
        "61605": "Globacom_bj", // Glo / Benin
        "61701": "Orange_mu", // my.t / Mauritius
        "61710": "Tigo_mu", // Emtel / Mauritius
        "61807": "Orange_lr", // Orange LBR / Liberia
        "61901": "BhartiAirtel_sl", // Orange / Sierra Leone
        "62001": "MTN_gh", // MTN / Ghana
        "62003": "Tigo_gh", // AirtelTigo / Ghana
        "62006": "BhartiAirtel_gh", // AirtelTigo / Ghana
        "62007": "Globacom_gh", // Globacom / Ghana
        "62120": "BhartiAirtel_ng", // Airtel / Nigeria
        "62130": "MTN_ng", // MTN / Nigeria
        "62150": "Globacom_ng", // Glo / Nigeria
        "62160": "Etisalat_ng", // 9mobile / Nigeria
        "62201": "BhartiAirtel_td", // Airtel / Chad
        "62203": "Tigo_td", // Tigo / Chad
        "62303": "Orange_cf", // Orange / Central African Republic
        "62401": "MTN_cm", // MTN Cameroon / Cameroon
        "62402": "Orange_cm", // Orange / Cameroon
        "62802": "Moov_ga", // Moov / Gabon
        "62803": "BhartiAirtel_ga", // Airtel / Gabon
        "62901": "BhartiAirtel_cg", // Airtel / Congo
        "62910": "MTN_cg", // Libertis Telecom / Congo
        "63001": "Vodafone_cd", // Vodacom / Democratic Republic of the Congo
        "63002": "BhartiAirtel_cd", // Airtel / Democratic Republic of the Congo
        "63086": "Orange_cd", // Orange RDC / Democratic Republic of the Congo
        "63089": "Tigo_cd", // Orange RDC / Democratic Republic of the Congo
        "63102": "Unitel_ao", // UNITEL / Angola
        "63104": "Movicel_ao", // MOVICEL / Angola
        "63203": "Orange_gw", // Orange / Guinea-Bissau
        "63301": "CW_sc", // Cable & Wireless / Seychelles
        "63310": "BhartiAirtel_sc", // Airtel / Seychelles
        "63510": "MTN_rw", // MTN / Rwanda
        "63513": "Tigo_rw", // Airtel / Rwanda
        "63514": "BhartiAirtel_rw", // Airtel / Rwanda
        "63902": "Safaricom_ke", // Safaricom / Kenya
        "63903": "BhartiAirtel_ke", // Airtel / Kenya
        "63907": "Orange_ke", // Telkom / Kenya
        "64002": "Tigo_tz", // tiGO / Tanzania
        "64003": "Etisalat_tz", // Zantel / Tanzania
        "64004": "Vodafone_tz", // Vodacom / Tanzania
        "64005": "BhartiAirtel_tz", // Airtel / Tanzania
        "64101": "BhartiAirtel_ug", // Airtel / Uganda
        "64110": "MTN_ug", // MTN / Uganda
        "64301": "mcel_mz", // mCel / Mozambique
        "64304": "Vodafone_mz", // Vodacom / Mozambique
        "64501": "BhartiAirtel_zm", // Airtel / Zambia
        "64502": "MTN_zm", // MTN / Zambia
        "64601": "BhartiAirtel_mg", // Airtel / Madagascar
        "64602": "Orange_mg", // Orange / Madagascar
        "64604": "Telma_mg", // Telma / Madagascar
        "64700": "Orange_re", // Orange / French Indian Ocean Territories (France)
        "64702": "Free_yt", // Only / French Indian Ocean Territories (France)
        "64703": "Free_re", // Free / French Indian Ocean Territories (France)
        "64704": "Zeop_re", // Zeop / French Indian Ocean Territories (France)
        "64710": "SFR_re", // SFR Réunion / French Indian Ocean Territories (France)
        "64804": "Econet_zw", // Econet / Zimbabwe
        "64901": "MTC_na", // MTC / Namibia
        "64903": "TelecomNamibia_na", // TN Mobile / Namibia
        "65010": "BhartiAirtel_mw", // Airtel / Malawi
        "65101": "Vodafone_ls", // Vodacom / Lesotho
        "65201": "Mascom_bw", // Mascom / Botswana
        "65202": "Orange_bw", // Orange / Botswana
        "65204": "BTC_bw", // beMobile / Botswana
        "65501": "Vodafone_za", // Vodacom / South Africa
        "65502": "8ta_za", // Telkom / South Africa
        "65507": "CellC_za", // Cell C / South Africa
        "65510": "MTN_za", // MTN / South Africa
        "70267": "BTL_bz", // DigiCell / Belize
        "70269": "Smart_bz", // SMART / Belize
        "70401": "Claro_gt", // Claro / Guatemala
        "70402": "Tigo_gt", // Tigo / Guatemala
        "70403": "movistar_gt", // movistar / Guatemala
        "70601": "Claro_sv", // Claro / El Salvador
        "70602": "Digicel_sv", // Digicel / El Salvador
        "70603": "Tigo_sv", // Tigo / El Salvador
        "70604": "movistar_sv", // movistar / El Salvador
        "708001": "Claro_hn", // Claro / Honduras
        "71021": "Claro_ni", // Claro / Nicaragua
        "71030": "movistar_ni", // movistar / Nicaragua
        "71201": "ICE_cr", // Kölbi ICE / Costa Rica
        "71202": "ICE_cr", // Kölbi ICE / Costa Rica
        "71203": "Claro_cr", // Claro / Costa Rica
        "71204": "movistar_cr", // movistar / Costa Rica
        "71401": "CW_pa", // Cable & Wireless / Panama
        "71402": "movistar_pa", // movistar / Panama
        "71403": "Claro_pa", // Claro / Panama
        "71404": "Digicel_pa", // Digicel / Panama
        "71606": "movistar_pe", // Movistar / Peru
        "71610": "Claro_pe", // Claro / Peru
        "71617": "Entel_pe", // Entel / Peru
        "722010": "Telefonica_Tuenti_ar", // Movistar / Argentina
        "722070": "movistar_ar", // Movistar / Argentina
        "722310": "Claro_ar", // Claro / Argentina
        "722341": "Personal_ar", // Personal / Argentina
        "72402": "TIM_br", // TIM / Brazil
        "72403": "TIM_br", // TIM / Brazil
        "72404": "TIM_br", // TIM / Brazil
        "72405": "Claro_br", // Claro / Brazil
        "72406": "vivo_br", // Vivo / Brazil
        "72410": "vivo_br", // Vivo / Brazil
        "72411": "vivo_br", // Vivo / Brazil
        "72416": "Oi_BrT_br", // Brasil Telecom GSM / Brazil
        "72418": "Webbing", // datora / Brazil
        "72423": "vivo_br", // Vivo / Brazil
        "72431": "Oi_br", // Oi / Brazil
        "72432": "Algar_br", // Algar Telecom / Brazil
        "72433": "Algar_br", // Algar Telecom / Brazil
        "72434": "Algar_br", // Algar Telecom / Brazil
        "72454": "BICS", // Conecta / Brazil
        "73001": "EntelPCS_cl", // entel / Chile
        "73002": "movistar_cl", // movistar / Chile
        "73003": "Claro_cl", // CLARO CL / Chile
        "73008": "vtr_cl", // VTR Móvil / Chile
        "73009": "movistar_cl", // WOM / Chile
        "73010": "EntelPCS_cl", // entel / Chile
        "73023": "Claro_cl", // Claro Servicios Empresariales S. A. / Chile
        "732101": "WOM_co", // Claro / Colombia
        "732103": "Tigo_co", // Tigo / Colombia
        "732111": "Tigo_co", // Tigo / Colombia
        "732123": "movistar_co", // movistar / Colombia
        "732130": "Avantel_co", // AVANTEL / Colombia
        "73603": "Tigo_bo", // Tigo / Bolivia
        "738002": "ATN_gy", // GT&T Cellink Plus / Guyana
        "73801": "Digicel_gy", // Digicel / Guyana
        "74000": "movistar_ec", // Movistar / Ecuador
        "74001": "Porta_ec", // Claro / Ecuador
        "74402": "Claro_py", // Claro / Paraguay
        "74404": "Tigo_py", // Tigo / Paraguay
        "74602": "Telesur_sr", // Telesur / Suriname
        "74603": "Digicel_sr", // Digicel / Suriname
        "74801": "Antel_uy", // Antel / Uruguay
        "74807": "movistar_uy", // Movistar / Uruguay
        "74810": "Claro_uy", // Claro / Uruguay
        "90131": "Webbing", // Orange / Worldwide
        "90137": "Transatel", // Transatel / Worldwide
        "90139": "MTX_lu", // MTX Connect Ltd / Worldwide
        "90188": "Simly", // UN Office for the Coordination of Humanitarian Affairs (OCHA) / Worldwide
    ]
}
