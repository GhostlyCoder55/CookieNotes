//
//  MealDBClient.swift
//  CookieNotes
//

import Foundation

struct DiscoveredRecipeSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailURL: URL?
    let category: String?
    let area: String?
}

struct DiscoveredRecipeDetail: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String?
    let area: String?
    let instructions: [String]
    let ingredients: [String]
    let thumbnailURL: URL?
    let sourceURL: String?
    let youtubeURL: String?
    let tags: [String]

    var attribution: String {
        var parts = ["TheMealDB"]
        if let area, !area.isEmpty { parts.append(area) }
        if let category, !category.isEmpty { parts.append(category) }
        return parts.joined(separator: " · ")
    }
}

enum MealDBError: LocalizedError {
    case invalidURL
    case badResponse
    case decoding
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Could not build the recipe request."
        case .badResponse: "The recipe service didn’t respond."
        case .decoding: "Recipe data looked unexpected."
        case .empty: "No recipes matched."
        }
    }
}

actor MealDBClient {
    static let shared = MealDBClient()

    /// Development falls back to TheMealDB test key `1`. Set `COOKIENOTES_MEALDB_API_KEY` before App Store release.
    private var apiKey: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "CookieNotesMealDBAPIKey") as? String ?? ""
        let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        #if DEBUG
        return "1"
        #else
        // Release with a blank xcconfig still needs a key so Discover does not hard-crash;
        // ship a supporter key in Release.xcconfig before submitting.
        AppLog.storage.error("COOKIENOTES_MEALDB_API_KEY is blank in Release; using TheMealDB test key")
        return "1"
        #endif
    }

    private var baseURL: URL {
        URL(string: "https://www.themealdb.com/api/json/v1/\(apiKey)/")!
    }

    func search(query: String) async throws -> [DiscoveredRecipeSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let url = baseURL.appendingPathComponent("search.php").appending(queryItems: [URLQueryItem(name: "s", value: trimmed)])
            ?? URL(string: baseURL.absoluteString + "search.php?s=\(encoded)")!
        let meals = try await fetchMeals(url: url)
        return meals.map(\.asSummary)
    }

    func filter(category: String) async throws -> [DiscoveredRecipeSummary] {
        let url = URL(string: baseURL.absoluteString + "filter.php?c=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)")!
        let meals = try await fetchMeals(url: url)
        return meals.map { $0.asSummary(categoryHint: category) }
    }

    func lookup(id: String) async throws -> DiscoveredRecipeDetail {
        let url = URL(string: baseURL.absoluteString + "lookup.php?i=\(id)")!
        let meals = try await fetchMeals(url: url)
        guard let meal = meals.first else { throw MealDBError.empty }
        return meal.asDetail
    }

    func categories() async throws -> [String] {
        let url = baseURL.appendingPathComponent("list.php").appending(queryItems: [URLQueryItem(name: "c", value: "list")])
            ?? URL(string: baseURL.absoluteString + "list.php?c=list")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MealDBError.badResponse
        }
        struct ListEnvelope: Decodable {
            struct Item: Decodable { let strCategory: String? }
            let meals: [Item]?
        }
        let decoded = try JSONDecoder().decode(ListEnvelope.self, from: data)
        return (decoded.meals ?? []).compactMap(\.strCategory)
    }

    private func fetchMeals(url: URL) async throws -> [MealDBMeal] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MealDBError.badResponse
        }
        do {
            let envelope = try JSONDecoder().decode(MealDBEnvelope.self, from: data)
            return envelope.meals ?? []
        } catch {
            throw MealDBError.decoding
        }
    }
}

private struct MealDBEnvelope: Decodable {
    let meals: [MealDBMeal]?
}

private struct MealDBMeal: Decodable {
    let idMeal: String?
    let strMeal: String?
    let strCategory: String?
    let strArea: String?
    let strInstructions: String?
    let strMealThumb: String?
    let strSource: String?
    let strYoutube: String?
    let strTags: String?
    let strIngredient1: String?
    let strIngredient2: String?
    let strIngredient3: String?
    let strIngredient4: String?
    let strIngredient5: String?
    let strIngredient6: String?
    let strIngredient7: String?
    let strIngredient8: String?
    let strIngredient9: String?
    let strIngredient10: String?
    let strIngredient11: String?
    let strIngredient12: String?
    let strIngredient13: String?
    let strIngredient14: String?
    let strIngredient15: String?
    let strIngredient16: String?
    let strIngredient17: String?
    let strIngredient18: String?
    let strIngredient19: String?
    let strIngredient20: String?
    let strMeasure1: String?
    let strMeasure2: String?
    let strMeasure3: String?
    let strMeasure4: String?
    let strMeasure5: String?
    let strMeasure6: String?
    let strMeasure7: String?
    let strMeasure8: String?
    let strMeasure9: String?
    let strMeasure10: String?
    let strMeasure11: String?
    let strMeasure12: String?
    let strMeasure13: String?
    let strMeasure14: String?
    let strMeasure15: String?
    let strMeasure16: String?
    let strMeasure17: String?
    let strMeasure18: String?
    let strMeasure19: String?
    let strMeasure20: String?

    var asSummary: DiscoveredRecipeSummary {
        asSummary(categoryHint: strCategory)
    }

    func asSummary(categoryHint: String?) -> DiscoveredRecipeSummary {
        DiscoveredRecipeSummary(
            id: idMeal ?? UUID().uuidString,
            name: strMeal ?? "Recipe",
            thumbnailURL: URL(string: strMealThumb ?? ""),
            category: categoryHint ?? strCategory,
            area: strArea
        )
    }

    var asDetail: DiscoveredRecipeDetail {
        let pairs: [(String?, String?)] = [
            (strIngredient1, strMeasure1), (strIngredient2, strMeasure2), (strIngredient3, strMeasure3),
            (strIngredient4, strMeasure4), (strIngredient5, strMeasure5), (strIngredient6, strMeasure6),
            (strIngredient7, strMeasure7), (strIngredient8, strMeasure8), (strIngredient9, strMeasure9),
            (strIngredient10, strMeasure10), (strIngredient11, strMeasure11), (strIngredient12, strMeasure12),
            (strIngredient13, strMeasure13), (strIngredient14, strMeasure14), (strIngredient15, strMeasure15),
            (strIngredient16, strMeasure16), (strIngredient17, strMeasure17), (strIngredient18, strMeasure18),
            (strIngredient19, strMeasure19), (strIngredient20, strMeasure20)
        ]
        let ingredients = pairs.compactMap { ingredient, measure -> String? in
            let name = ingredient?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return nil }
            let amount = measure?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return amount.isEmpty ? name : "\(amount) \(name)"
        }
        let steps = (strInstructions ?? "")
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return DiscoveredRecipeDetail(
            id: idMeal ?? UUID().uuidString,
            name: strMeal ?? "Recipe",
            category: strCategory,
            area: strArea,
            instructions: steps.isEmpty ? [strInstructions ?? ""].filter { !$0.isEmpty } : steps,
            ingredients: ingredients,
            thumbnailURL: URL(string: strMealThumb ?? ""),
            sourceURL: strSource,
            youtubeURL: strYoutube,
            tags: (strTags ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        )
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        return components?.url
    }
}
