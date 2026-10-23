//
//  LocalMealCatalog.swift
//  CookieNotes
//
//  Curated meals (especially West African) that TheMealDB does not cover yet.
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
            tags: [area, "West African"].filter { !$0.isEmpty },
            illustrationIconID: illustration
        )
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
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return shared
            .filter { meal in
                meal.name.lowercased().contains(trimmed)
                    || meal.area.lowercased().contains(trimmed)
                    || meal.category.lowercased().contains(trimmed)
                    || meal.ingredients.contains { $0.lowercased().contains(trimmed) }
            }
            .map(\.summary)
    }

    static func filter(area: String) -> [DiscoveredRecipeSummary] {
        let key = area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return shared
            .filter { $0.area.lowercased() == key || $0.area.lowercased().contains(key) }
            .map(\.summary)
    }

    /// Country / demonym aliases that should resolve to a MealDB-style area name.
    static func resolvedArea(for query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let aliases: [String: String] = [
            "nigeria": "Nigerian",
            "nigerian": "Nigerian",
            "ghana": "Ghanaian",
            "ghanaian": "Ghanaian",
            "senegal": "Senegalese",
            "senegalese": "Senegalese",
            "mali": "Malian",
            "malian": "Malian",
            "west africa": "Nigerian",
            "west african": "Nigerian",
            "egypt": "Egyptian",
            "egyptian": "Egyptian",
            "morocco": "Moroccan",
            "moroccan": "Moroccan",
            "tunisia": "Tunisian",
            "tunisian": "Tunisian",
            "kenya": "Kenyan",
            "kenyan": "Kenyan",
            "china": "Chinese",
            "chinese": "Chinese",
            "japan": "Japanese",
            "japanese": "Japanese",
            "thailand": "Thai",
            "thai": "Thai",
            "vietnam": "Vietnamese",
            "vietnamese": "Vietnamese",
            "malaysia": "Malaysian",
            "malaysian": "Malaysian",
            "philippines": "Filipino",
            "filipino": "Filipino",
            "turkey": "Turkish",
            "turkish": "Turkish",
            "syria": "Syrian",
            "syrian": "Syrian",
            "saudi": "Saudi Arabian",
            "saudi arabia": "Saudi Arabian",
            "india": "Indian",
            "indian": "Indian",
            "mexico": "Mexican",
            "mexican": "Mexican",
            "latino": "Mexican",
            "latin": "Mexican",
            "latin america": "Mexican",
            "italy": "Italian",
            "italian": "Italian",
            "france": "French",
            "french": "French",
            "america": "American",
            "american": "American",
            "usa": "American",
            "united states": "American",
            "canada": "Canadian",
            "canadian": "Canadian",
            "jamaica": "Jamaican",
            "jamaican": "Jamaican",
            "caribbean": "Caribbean",
            "puerto rico": "Caribbean",
            "cuba": "Caribbean",
            "haiti": "Caribbean",
            "uk": "British",
            "british": "British",
            "england": "British"
        ]
        if let exact = aliases[trimmed] { return exact }
        for (alias, area) in aliases where trimmed.contains(alias) || alias.contains(trimmed) {
            return area
        }
        return nil
    }
}
