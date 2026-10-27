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
    var illustrationIconID: String? = nil

    var isLocal: Bool { id.hasPrefix("local-") }

    /// TheMealDB serves ~500px variants; full-size images are 4x heavier than a card needs.
    var cardThumbnailURL: URL? {
        guard let thumbnailURL,
              thumbnailURL.host?.contains("themealdb.com") == true,
              !thumbnailURL.lastPathComponent.hasSuffix("medium") else { return thumbnailURL }
        return thumbnailURL.appendingPathComponent("medium")
    }
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
    var illustrationIconID: String? = nil

    var isLocal: Bool { id.hasPrefix("local-") }

    var timeEstimate: RecipeTimeEstimate {
        RecipeTimeEstimator.estimate(
            instructions: instructions,
            ingredientCount: ingredients.count,
            category: category
        )
    }

    var attribution: String {
        let sourceLabel: String
        if let sourceURL, sourceURL.contains("epicurious.com") {
            sourceLabel = "Epicurious"
        } else if isLocal {
            sourceLabel = "CookieNotes kitchen"
        } else {
            sourceLabel = "the meal database"
        }
        var parts = [sourceLabel]
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

    private var cachedAreas: [String]?
    private var cachedCategories: [String]?
    private var listCache: [String: [DiscoveredRecipeSummary]] = [:]
    private var detailCache: [String: DiscoveredRecipeDetail] = [:]
    private var detailTasks: [String: Task<DiscoveredRecipeDetail, Error>] = [:]
    private var timeCache: [String: RecipeTimeEstimate] = [:]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 40 * 1024 * 1024)
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Instant results for chips / searches already loaded this session.
    func cachedList(forKey key: String) -> [DiscoveredRecipeSummary]? {
        listCache[key]
    }

    static func listKey(category: String) -> String { "c:\(category.lowercased())" }
    static func listKey(area: String) -> String { "a:\(area.lowercased())" }
    static func listKey(search: String) -> String {
        "s:\(search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    func timeEstimate(id: String) async -> RecipeTimeEstimate? {
        if let cached = timeCache[id] { return cached }
        guard let detail = try? await lookup(id: id) else { return nil }
        let estimate = detail.timeEstimate
        timeCache[id] = estimate
        return estimate
    }

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
        let key = Self.listKey(search: trimmed)
        if let cached = listCache[key] { return cached }

        // Country / region queries (e.g. "Nigeria", "Thai") browse by area.
        if let area = LocalMealCatalog.resolvedArea(for: trimmed) {
            let results = try await filter(area: area)
            listCache[key] = results
            return results
        }
        if let area = await matchedRemoteArea(for: trimmed) {
            let results = try await filter(area: area)
            listCache[key] = results
            return results
        }

        let local = LocalMealCatalog.search(query: trimmed)
        let url = try endpoint("search.php", queryItems: [URLQueryItem(name: "s", value: trimmed)])
        let remote: [DiscoveredRecipeSummary]
        do {
            let meals = try await fetchMeals(url: url)
            // search.php returns full meals — seed the detail cache so opening one is instant.
            for meal in meals {
                let detail = meal.asDetail
                detailCache[detail.id] = detail
            }
            remote = meals.map(\.asSummary)
        } catch {
            if local.isEmpty { throw error }
            // Offline: show local matches but don't cache them as the full answer.
            return local
        }
        let results = Self.merging(local: local, remote: remote)
        listCache[key] = results
        return results
    }

    func filter(category: String) async throws -> [DiscoveredRecipeSummary] {
        let key = Self.listKey(category: category)
        if let cached = listCache[key] { return cached }
        let url = try endpoint("filter.php", queryItems: [URLQueryItem(name: "c", value: category)])
        let meals = try await fetchMeals(url: url)
        let remote = meals.map { $0.asSummary(categoryHint: category) }
        let local = LocalMealCatalog.shared
            .filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
            .map(\.summary)
        let results = Self.merging(local: local, remote: remote)
        listCache[key] = results
        return results
    }

    func filter(area: String) async throws -> [DiscoveredRecipeSummary] {
        let key = Self.listKey(area: area)
        if let cached = listCache[key] { return cached }
        let local = LocalMealCatalog.filter(area: area)
        let url = try endpoint("filter.php", queryItems: [URLQueryItem(name: "a", value: area)])
        let remote: [DiscoveredRecipeSummary]
        do {
            let meals = try await fetchMeals(url: url)
            remote = meals.map { meal in
                DiscoveredRecipeSummary(
                    id: meal.idMeal ?? UUID().uuidString,
                    name: meal.strMeal ?? "Recipe",
                    thumbnailURL: URL(string: meal.strMealThumb ?? ""),
                    category: meal.strCategory,
                    area: area
                )
            }
        } catch {
            remote = []
            if local.isEmpty { throw error }
        }
        let results = Self.merging(local: local, remote: remote)
        if !remote.isEmpty { listCache[key] = results }
        return results
    }

    func lookup(id: String) async throws -> DiscoveredRecipeDetail {
        if let local = LocalMealCatalog.detail(id: id) {
            return local
        }
        if let cached = detailCache[id] { return cached }
        // Cards prefetch details for their times; share one request per meal.
        if let running = detailTasks[id] { return try await running.value }

        let url = try endpoint("lookup.php", queryItems: [URLQueryItem(name: "i", value: id)])
        let task = Task { [session] () throws -> DiscoveredRecipeDetail in
            let meals = try await Self.fetchMeals(url: url, session: session)
            guard let meal = meals.first else { throw MealDBError.empty }
            return meal.asDetail
        }
        detailTasks[id] = task
        defer { detailTasks[id] = nil }
        let detail = try await task.value
        detailCache[id] = detail
        return detail
    }

    func areas() async throws -> [String] {
        if let cachedAreas { return cachedAreas }
        let url = try endpoint("list.php", queryItems: [URLQueryItem(name: "a", value: "list")])
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MealDBError.badResponse
        }
        struct ListEnvelope: Decodable {
            struct Item: Decodable { let strArea: String? }
            let meals: [Item]?
        }
        let decoded = try JSONDecoder().decode(ListEnvelope.self, from: data)
        let list = (decoded.meals ?? []).compactMap(\.strArea)
        cachedAreas = list
        return list
    }

    func categories() async throws -> [String] {
        if let cachedCategories { return cachedCategories }
        let url = try endpoint("list.php", queryItems: [URLQueryItem(name: "c", value: "list")])
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MealDBError.badResponse
        }
        struct ListEnvelope: Decodable {
            struct Item: Decodable { let strCategory: String? }
            let meals: [Item]?
        }
        let decoded = try JSONDecoder().decode(ListEnvelope.self, from: data)
        let list = (decoded.meals ?? []).compactMap(\.strCategory)
        if !list.isEmpty { cachedCategories = list }
        return list
    }

    /// Builds MealDB URLs with `URLQueryItem` values so query input is never string-interpolated.
    private func endpoint(_ path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw MealDBError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw MealDBError.invalidURL }
        return url
    }

    private func fetchMeals(url: URL) async throws -> [MealDBMeal] {
        try await Self.fetchMeals(url: url, session: session)
    }

    private static func fetchMeals(url: URL, session: URLSession) async throws -> [MealDBMeal] {
        let (data, response) = try await session.data(from: url)
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

    private func matchedRemoteArea(for query: String) async -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 3 else { return nil }
        let areas = (try? await areas()) ?? []
        if let exact = areas.first(where: { $0.lowercased() == trimmed }) {
            return exact
        }
        // Prefer demonyms / country names that start with the query ("ghan" → Ghanaian).
        return areas.first(where: { $0.lowercased().hasPrefix(trimmed) })
            ?? areas.first(where: { $0.lowercased().contains(trimmed) })
    }

    private static func merging(local: [DiscoveredRecipeSummary], remote: [DiscoveredRecipeSummary]) -> [DiscoveredRecipeSummary] {
        var seen = Set<String>()
        var merged: [DiscoveredRecipeSummary] = []
        for item in local + remote {
            let key = item.name.lowercased()
            guard seen.insert(key).inserted else { continue }
            merged.append(item)
        }
        return merged
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

