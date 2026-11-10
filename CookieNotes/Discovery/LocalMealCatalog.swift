//
//  LocalMealCatalog.swift
//  CookieNotes
//
//  Curated meals that TheMealDB does not cover yet.
//

import Foundation

struct LocalMealRecord: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let category: String
    let area: String
    let illustration: String?
    let ingredients: [String]
    let instructions: [String]
    let thumbnailURL: String?
    let sourceURL: String?

    var summary: DiscoveredRecipeSummary {
        DiscoveredRecipeSummary(
            id: id,
            name: name,
            thumbnailURL: thumbnailURL.flatMap(URL.init(string:)),
            category: category,
            area: area,
            illustrationIconID: illustration
        )
    }

    var detail: DiscoveredRecipeDetail {
        DiscoveredRecipeDetail(
            id: id,
            name: name,
            category: category,
            area: area,
            instructions: instructions,
            ingredients: ingredients,
            thumbnailURL: thumbnailURL.flatMap(URL.init(string:)),
            sourceURL: sourceURL,
            youtubeURL: nil,
            tags: [area, CuisineTaxonomy.region(forArea: area)?.rawValue ?? ""].filter { !$0.isEmpty },
            illustrationIconID: illustration
        )
    }

    func matches(search query: String) -> Bool {
        let terms = CuisineTaxonomy.normalized(query)
            .split(separator: " ")
            .map(String.init)
        guard !terms.isEmpty else { return false }

        let cuisineTerms = CuisineTaxonomy.searchTerms(forArea: area)
            + [CuisineTaxonomy.region(forArea: area)?.rawValue ?? ""]
        let searchableTerms = (
            [name, category, area, sourceURL ?? ""]
                + ingredients
                + instructions
                + cuisineTerms
        )
        .map(CuisineTaxonomy.normalized)
        .joined(separator: " ")
        .split(separator: " ")
        .map(String.init)

        return terms.allSatisfy { queryTerm in
            searchableTerms.contains { $0 == queryTerm || $0.hasPrefix(queryTerm) }
        }
    }
}

enum LocalMealCatalog {
    private static let enMeals: [LocalMealRecord] = load(file: "LocalMealCatalog")
    private static let frMeals: [LocalMealRecord] = load(file: "LocalMealCatalog_fr")

    static var shared: [LocalMealRecord] {
        AppLanguageManager.shared.activeLanguage == .french ? frMeals : enMeals
    }

    static var allEnglishMeals: [LocalMealRecord] { enMeals }
    static var allFrenchMeals: [LocalMealRecord] { frMeals }

    private static func load(file: String) -> [LocalMealRecord] {
        let urls: [URL?] = [
            Bundle.main.url(forResource: file, withExtension: "json"),
            Bundle.main.url(forResource: file, withExtension: "json", subdirectory: "Resources")
        ]
        for case let url? in urls {
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(File.self, from: data) else {
                continue
            }
            return decoded.meals
        }
        return []
    }

    private struct File: Codable {
        let meals: [LocalMealRecord]
    }

    static func record(id: String, language: AppLanguage? = nil) -> LocalMealRecord? {
        let canonical = MealDBClient.canonicalRecipeID(for: id)
        let pool = (language ?? AppLanguageManager.shared.activeLanguage) == .french ? frMeals : enMeals
        return pool.first { $0.id == canonical }
    }

    static func canonicalID(forSourceURL sourceURL: String) -> String? {
        let normalized = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return enMeals.first {
            $0.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }?.id
    }

    static func detail(id: String) -> DiscoveredRecipeDetail? {
        let canonical = MealDBClient.canonicalRecipeID(for: id)
        return shared.first { $0.id == canonical }?.detail
    }

    static func search(query: String) -> [DiscoveredRecipeSummary] {
        return shared
            .filter { $0.matches(search: query) }
            .map(\.summary)
    }

    static func filter(area: String) -> [DiscoveredRecipeSummary] {
        let key = CuisineTaxonomy.normalized(area)
        return shared
            .filter { CuisineTaxonomy.normalized($0.area) == key }
            .map(\.summary)
    }

    static func filter(region: CuisineRegion) -> [DiscoveredRecipeSummary] {
        shared
            .filter { CuisineTaxonomy.region(forArea: $0.area) == region }
            .map(\.summary)
    }

    static func resolvedArea(for query: String) -> String? {
        CuisineTaxonomy.canonicalArea(for: query)
    }
}

enum CuisineRegion: String, CaseIterable, Identifiable {
    case african = "African"
    case asian = "Asian"
    case caribbean = "Caribbean"
    case european = "European"
    case middleEastern = "Middle Eastern"
    case northAmerican = "North American"
    case oceania = "Oceania"
    case southAmerican = "South American"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .african: return String.localized("African")
        case .asian: return String.localized("Asian")
        case .caribbean: return String.localized("Caribbean")
        case .european: return String.localized("European")
        case .middleEastern: return String.localized("Middle Eastern")
        case .northAmerican: return String.localized("North American")
        case .oceania: return String.localized("Oceania")
        case .southAmerican: return String.localized("South American")
        }
    }
}

enum CuisineTaxonomy {
    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "&", with: " and ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    static func region(forArea area: String, country: String? = nil) -> CuisineRegion? {
        if let country,
           let region = countryRegions[normalized(country)] {
            return region
        }
        let areaKey = normalized(area)
        if let region = localAreaRegions[areaKey] {
            return region
        }
        if let country = localAreaCountries[areaKey],
           let region = countryRegions[normalized(country)] {
            return region
        }
        if let canonicalArea = countryAndAreaAliases[areaKey] {
            let canonicalKey = normalized(canonicalArea)
            if let region = localAreaRegions[canonicalKey] {
                return region
            }
            if let country = localAreaCountries[canonicalKey] {
                return countryRegions[normalized(country)]
            }
        }
        return nil
    }

    static func canonicalArea(for query: String) -> String? {
        countryAndAreaAliases[normalized(query)]
    }

    static func searchTerms(forArea area: String) -> [String] {
        let key = normalized(area)
        guard localAreaCountries[key] != nil else { return [area] }
        return [area] + countryAndAreaAliases.compactMap { alias, canonical in
            canonical == area ? alias : nil
        }
    }

    static let regions = CuisineRegion.allCases

    private static let countryAndAreaAliases: [String: String] = [
        "algeria": "Algerian", "algerian": "Algerian", "algerie": "Algerian", "algerien": "Algerian", "algerienne": "Algerian",
        "nigeria": "Nigerian", "nigerian": "Nigerian", "nigeriane": "Nigerian",
        "ghana": "Ghanaian", "ghanaian": "Ghanaian", "ghaneen": "Ghanaian", "ghaneenne": "Ghanaian",
        "senegal": "Senegalese", "senegalese": "Senegalese", "senegalais": "Senegalese", "senegalaise": "Senegalese",
        "mali": "Malian", "malian": "Malian", "malien": "Malian", "malienne": "Malian",
        "cameroon": "Cameroonian", "cameroonian": "Cameroonian", "camerounais": "Cameroonian", "camerounaise": "Cameroonian",
        "ivory coast": "Ivorian", "cote d ivoire": "Ivorian", "ivorian": "Ivorian", "ivoirien": "Ivorian", "ivoirienne": "Ivorian",
        "gambia": "Gambian", "gambian": "Gambian", "gambien": "Gambian",
        "egypt": "Egyptian", "egyptian": "Egyptian", "egypte": "Egyptian", "egyptien": "Egyptian", "egyptienne": "Egyptian",
        "morocco": "Moroccan", "moroccan": "Moroccan", "maroc": "Moroccan", "marocain": "Moroccan", "marocaine": "Moroccan",
        "tunisia": "Tunisian", "tunisian": "Tunisian", "tunisie": "Tunisian", "tunisien": "Tunisian", "tunisienne": "Tunisian",
        "kenya": "Kenyan", "kenyan": "Kenyan", "kenyanne": "Kenyan",
        "china": "Chinese", "chinese": "Chinese", "chine": "Chinese", "chinois": "Chinese", "chinoise": "Chinese",
        "japan": "Japanese", "japanese": "Japanese", "japon": "Japanese", "japonais": "Japanese", "japonaise": "Japanese",
        "thailand": "Thai", "thai": "Thai", "thailande": "Thai", "thailandais": "Thai", "thailandaise": "Thai",
        "vietnam": "Vietnamese", "vietnamese": "Vietnamese", "vietnamien": "Vietnamese", "vietnamienne": "Vietnamese",
        "malaysia": "Malaysian", "malaysian": "Malaysian", "malaisie": "Malaysian", "malaisien": "Malaysian",
        "philippines": "Filipino", "filipino": "Filipino", "philippin": "Filipino", "philippine": "Filipino",
        "turkey": "Turkish", "turkish": "Turkish", "turquie": "Turkish", "turc": "Turkish", "turque": "Turkish",
        "syria": "Syrian", "syrian": "Syrian", "syrie": "Syrian", "syrien": "Syrian",
        "yemen": "Yemeni", "yemeni": "Yemeni", "yemenite": "Yemeni",
        "saudi": "Saudi Arabian", "saudi arabia": "Saudi Arabian", "arabie saoudite": "Saudi Arabian", "saoudien": "Saudi Arabian",
        "india": "Indian", "indian": "Indian", "inde": "Indian", "indien": "Indian", "indienne": "Indian",
        "mexico": "Mexican", "mexican": "Mexican", "mexique": "Mexican", "mexicain": "Mexican", "mexicaine": "Mexican",
        "italy": "Italian", "italian": "Italian", "italie": "Italian", "italien": "Italian", "italienne": "Italian",
        "france": "French", "french": "French", "francais": "French", "francaise": "French",
        "america": "American", "american": "American", "etats unis": "American", "etats-unis": "American", "americain": "American", "americaine": "American",
        "usa": "American", "united states": "American",
        "canada": "Canadian", "canadian": "Canadian", "canadien": "Canadian", "canadienne": "Canadian",
        "jamaica": "Jamaican", "jamaican": "Jamaican", "jamaique": "Jamaican", "jamaicain": "Jamaican", "jamaicaine": "Jamaican",
        "caribbean": "Caribbean", "caraibes": "Caribbean", "caribeen": "Caribbean", "caribeenne": "Caribbean", "puerto rico": "Puerto Rican",
        "cuba": "Cuban", "cubain": "Cuban", "cubaine": "Cuban", "haiti": "Haitian", "haitien": "Haitian", "haitienne": "Haitian",
        "uk": "British", "british": "British", "england": "British", "britannique": "British", "angleterre": "British", "anglais": "British", "anglaise": "British",
        "spain": "Spanish", "spanish": "Spanish", "espagne": "Spanish", "espagnol": "Spanish", "espagnole": "Spanish",
        "greece": "Greek", "greek": "Greek", "grece": "Greek", "grec": "Greek", "grecque": "Greek",
        "australia": "Australian", "australian": "Australian", "australie": "Australian", "australien": "Australian", "australienne": "Australian",
        "croatia": "Croatian", "croatian": "Croatian", "croatie": "Croatian", "croate": "Croatian",
        "ireland": "Irish", "irish": "Irish", "irlande": "Irish", "irlandais": "Irish", "irlandaise": "Irish",
        "dutch": "Dutch", "holland": "Dutch", "netherlands": "Dutch", "pays bas": "Dutch", "neerlandais": "Dutch", "neerlandaise": "Dutch",
        "poland": "Polish", "polish": "Polish", "pologne": "Polish", "polonais": "Polish", "polonaise": "Polish",
        "portugal": "Portuguese", "portuguese": "Portuguese", "portugais": "Portuguese", "portugaise": "Portuguese",
        "russia": "Russian", "russian": "Russian", "russie": "Russian", "russe": "Russian",
        "ukraine": "Ukrainian", "ukrainian": "Ukrainian", "ukrainien": "Ukrainian", "ukrainienne": "Ukrainian",
        "uruguay": "Uruguayan", "uruguayan": "Uruguayan", "uruguayen": "Uruguayan", "uruguayenne": "Uruguayan"
    ]

    private static let localAreaCountries: [String: String] = [
        "american": "united states", "canadian": "canada", "french": "france",
        "ghanaian": "ghana", "jamaican": "jamaica", "mexican": "mexico",
        "nigerian": "nigeria", "senegalese": "senegal", "caribbean": "caribbean"
    ]

    private static let localAreaRegions: [String: CuisineRegion] = [
        "algerian": .african,
        "american": .northAmerican, "canadian": .northAmerican, "mexican": .northAmerican,
        "french": .european, "ghanaian": .african, "nigerian": .african,
        "senegalese": .african, "jamaican": .caribbean, "caribbean": .caribbean,
        "cameroonian": .african, "egyptian": .african, "moroccan": .african,
        "tunisian": .african, "kenyan": .african, "ethiopian": .african,
        "south african": .african, "chinese": .asian, "japanese": .asian,
        "thai": .asian, "vietnamese": .asian, "malaysian": .asian, "filipino": .asian,
        "indian": .asian, "korean": .asian, "turkish": .middleEastern,
        "syrian": .middleEastern, "saudi arabian": .middleEastern, "yemeni": .middleEastern,
        "lebanese": .middleEastern, "iraqi": .middleEastern, "iranian": .middleEastern,
        "british": .european
    ]

    private static let countryRegions: [String: CuisineRegion] = {
        var result: [String: CuisineRegion] = [:]
        let assignments: [(CuisineRegion, [String])] = [
            (.african, [
                "Algeria", "Benin", "Burkina Faso", "Burundi", "Cameroon", "Cape Verde", "Central African Republic",
                "Chad", "Comoros", "Côte d'Ivoire", "Djibouti", "DR Congo", "Egypt", "Equatorial Guinea",
                "Eritrea", "Eswatini", "Ethiopia", "Gabon", "Gambia", "Ghana", "Guinea",
                "Guinea-Bissau", "Kenya", "Lesotho", "Liberia", "Libya", "Madagascar", "Malawi",
                "Mali", "Mauritania", "Mauritius", "Morocco", "Mozambique", "Namibia", "Niger",
                "Nigeria", "Republic of the Congo", "Rwanda", "São Tomé and Príncipe", "Senegal",
                "Seychelles", "Sierra Leone", "Somalia", "South Africa", "South Sudan", "Sudan",
                "Tanzania", "Togo", "Tunisia", "Uganda", "Zambia", "Zimbabwe", "Angola", "Botswana"
            ]),
            (.asian, [
                "Afghanistan", "Armenia", "Azerbaijan", "Bangladesh", "Bhutan", "Brunei", "Cambodia",
                "China", "Georgia", "Hong Kong", "India", "Indonesia", "Japan", "Kazakhstan",
                "Kyrgyzstan", "Laos", "Malaysia", "Maldives", "Mongolia", "Myanmar", "Nepal",
                "North Korea", "Pakistan", "Philippines", "Singapore", "South Korea", "Sri Lanka",
                "Taiwan", "Tajikistan", "Thailand", "Timor-Leste", "Turkmenistan", "Uzbekistan", "Vietnam"
            ]),
            (.middleEastern, [
                "Bahrain", "Iran", "Iraq", "Israel", "Jordan", "Kuwait", "Lebanon", "Oman",
                "Palestine", "Qatar", "Saudi Arabia", "Syria", "Turkey", "United Arab Emirates", "Yemen"
            ]),
            (.european, [
                "Albania", "Andorra", "Austria", "Belarus", "Belgium", "Bosnia and Herzegovina",
                "Bulgaria", "Croatia", "Cyprus", "Czechia", "Denmark", "Estonia", "Faroe Islands", "Finland",
                "France", "Germany", "Greece", "Hungary", "Iceland", "Ireland", "Italy", "Kosovo",
                "Gibraltar", "Guernsey", "Jersey", "Latvia", "Liechtenstein", "Lithuania", "Luxembourg",
                "Malta", "Moldova", "Monaco", "Montenegro", "Netherlands", "North Macedonia", "Norway", "Poland", "Portugal",
                "Romania", "Russia", "San Marino", "Serbia", "Slovakia", "Slovenia", "Spain",
                "Sweden", "Switzerland", "Ukraine", "United Kingdom", "Vatican City"
            ]),
            (.northAmerican, [
                "Belize", "Bermuda", "Canada", "Costa Rica", "El Salvador", "Greenland", "Guatemala",
                "Honduras", "Mexico", "Nicaragua", "Panama", "United States"
            ]),
            (.southAmerican, [
                "Argentina", "Bolivia", "Brazil", "Chile", "Colombia", "Ecuador", "French Guiana",
                "Guyana", "Paraguay", "Peru", "Suriname", "Uruguay", "Venezuela"
            ]),
            (.caribbean, [
                "Antigua and Barbuda", "Anguilla", "Aruba", "Bahamas", "Barbados", "Cayman Islands",
                "Cuba", "Dominica", "Dominican Republic", "Grenada", "Guadeloupe", "Haiti", "Jamaica",
                "Martinique", "Puerto Rico", "Saint Lucia", "Saint Vincent and the Grenadines",
                "Trinidad and Tobago"
            ]),
            (.oceania, [
                "Australia", "Fiji", "Guam", "New Zealand", "Papua New Guinea", "Samoa",
                "Solomon Islands", "Tonga", "Tuvalu", "Vanuatu"
            ])
        ]
        for (region, countries) in assignments {
            for country in countries {
                result[normalized(country)] = region
            }
        }
        result["ivory coast"] = .african
        result["cote d ivoire"] = .african
        result["dr congo"] = .african
        result["republic of the congo"] = .african
        result["united states of america"] = .northAmerican
        result["uk"] = .european
        return result
    }()
}
