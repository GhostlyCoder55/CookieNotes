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
    static let shared: [LocalMealRecord] = load()

    private static func load() -> [LocalMealRecord] {
        guard let url = Bundle.main.url(forResource: "LocalMealCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.meals
    }

    private struct File: Codable {
        let meals: [LocalMealRecord]
    }

    static func detail(id: String) -> DiscoveredRecipeDetail? {
        shared.first { $0.id == id }?.detail
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
        "nigeria": "Nigerian", "nigerian": "Nigerian",
        "ghana": "Ghanaian", "ghanaian": "Ghanaian",
        "senegal": "Senegalese", "senegalese": "Senegalese",
        "mali": "Malian", "malian": "Malian",
        "cameroon": "Cameroonian", "cameroonian": "Cameroonian",
        "ivory coast": "Ivorian", "cote d ivoire": "Ivorian", "ivorian": "Ivorian",
        "gambia": "Gambian", "gambian": "Gambian",
        "egypt": "Egyptian", "egyptian": "Egyptian",
        "morocco": "Moroccan", "moroccan": "Moroccan",
        "tunisia": "Tunisian", "tunisian": "Tunisian",
        "kenya": "Kenyan", "kenyan": "Kenyan",
        "china": "Chinese", "chinese": "Chinese",
        "japan": "Japanese", "japanese": "Japanese",
        "thailand": "Thai", "thai": "Thai",
        "vietnam": "Vietnamese", "vietnamese": "Vietnamese",
        "malaysia": "Malaysian", "malaysian": "Malaysian",
        "philippines": "Filipino", "filipino": "Filipino",
        "turkey": "Turkish", "turkish": "Turkish",
        "syria": "Syrian", "syrian": "Syrian",
        "yemen": "Yemeni", "yemeni": "Yemeni",
        "saudi": "Saudi Arabian", "saudi arabia": "Saudi Arabian",
        "india": "Indian", "indian": "Indian",
        "mexico": "Mexican", "mexican": "Mexican",
        "italy": "Italian", "italian": "Italian",
        "france": "French", "french": "French",
        "america": "American", "american": "American",
        "usa": "American", "united states": "American",
        "canada": "Canadian", "canadian": "Canadian",
        "jamaica": "Jamaican", "jamaican": "Jamaican",
        "caribbean": "Caribbean", "puerto rico": "Puerto Rican",
        "cuba": "Cuban", "haiti": "Haitian",
        "uk": "British", "british": "British", "england": "British"
    ]

    private static let localAreaCountries: [String: String] = [
        "american": "united states", "canadian": "canada", "french": "france",
        "ghanaian": "ghana", "jamaican": "jamaica", "mexican": "mexico",
        "nigerian": "nigeria", "senegalese": "senegal", "caribbean": "caribbean"
    ]

    private static let localAreaRegions: [String: CuisineRegion] = [
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
