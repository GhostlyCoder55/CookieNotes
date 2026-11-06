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

struct CuisineArea: Hashable, Identifiable {
    let name: String
    let country: String

    var id: String { name }
    var region: CuisineRegion? { CuisineTaxonomy.region(forArea: name, country: country) }
}

private struct MealAreaResults: Sendable {
    let recipes: [DiscoveredRecipeSummary]
    let failed: Bool
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

    private var cachedCuisineAreas: [CuisineArea]?
    private var cachedCategories: [String]?
    private var cachedIngredients: [String]?
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
    static func listKey(region: CuisineRegion) -> String { "r:\(region.rawValue.lowercased())" }
    static func listKey(search: String) -> String {
        "s:\(search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func alphabeticallySorted(_ recipes: [DiscoveredRecipeSummary]) -> [DiscoveredRecipeSummary] {
        recipes.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
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

        let local = LocalMealCatalog.search(query: trimmed)
        let url = try endpoint("search.php", queryItems: [URLQueryItem(name: "s", value: trimmed)])
        var matches = local
        var nameSearchError: Error?
        do {
            let meals = try await fetchMeals(url: url)
            // search.php returns full meals — seed the detail cache so opening one is instant.
            for meal in meals {
                let detail = meal.asDetail
                detailCache[detail.id] = detail
            }
            matches += meals.map(\.asSummary)
        } catch {
            nameSearchError = error
            AppLog.storage.error("MealDB name search failed; showing local matches")
        }

        var matchedArea = LocalMealCatalog.resolvedArea(for: trimmed)
        if matchedArea == nil {
            matchedArea = await matchedRemoteArea(for: trimmed)
        }
        if let area = matchedArea {
            do {
                matches += try await filter(area: area)
            } catch {
                AppLog.storage.error("MealDB cuisine search failed")
            }
        }
        if let category = await matchedRemoteCategory(for: trimmed) {
            do {
                matches += try await filter(category: category)
            } catch {
                AppLog.storage.error("MealDB category search failed")
            }
        }
        if let ingredient = await matchedRemoteIngredient(for: trimmed) {
            do {
                matches += try await filter(ingredient: ingredient)
            } catch {
                AppLog.storage.error("MealDB ingredient search failed")
            }
        }

        if matches.isEmpty, let nameSearchError { throw nameSearchError }
        let results = Self.merging(local: [], remote: matches)
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
        listCache[key] = results
        return results
    }

    func filter(region: CuisineRegion) async throws -> [DiscoveredRecipeSummary] {
        let key = Self.listKey(region: region)
        if let cached = listCache[key] { return cached }

        let local = LocalMealCatalog.filter(region: region)
        let areas = try await cuisineAreas()
            .filter { $0.region == region }
            .map(\.name)
        guard !areas.isEmpty else {
            let sorted = Self.alphabeticallySorted(local)
            listCache[key] = sorted
            return sorted
        }

        var nextAreaIndex = 0
        var failedAreaCount = 0
        var remote: [DiscoveredRecipeSummary] = []
        await withTaskGroup(of: MealAreaResults.self) { group in
            for _ in 0..<min(6, areas.count) {
                let area = areas[nextAreaIndex]
                nextAreaIndex += 1
                group.addTask {
                    do {
                        return MealAreaResults(recipes: try await self.filter(area: area), failed: false)
                    } catch {
                        AppLog.storage.error("MealDB region lookup failed for \(area)")
                        return MealAreaResults(recipes: [], failed: true)
                    }
                }
            }

            while let areaResults = await group.next() {
                remote += areaResults.recipes
                if areaResults.failed {
                    failedAreaCount += 1
                }
                if nextAreaIndex < areas.count {
                    let area = areas[nextAreaIndex]
                    nextAreaIndex += 1
                    group.addTask {
                        do {
                            return MealAreaResults(recipes: try await self.filter(area: area), failed: false)
                        } catch {
                            AppLog.storage.error("MealDB region lookup failed for \(area)")
                            return MealAreaResults(recipes: [], failed: true)
                        }
                    }
                }
            }
        }

        if failedAreaCount == areas.count && local.isEmpty {
            throw MealDBError.badResponse
        }
        let results = Self.alphabeticallySorted(Self.merging(local: local, remote: remote))
        if failedAreaCount == 0 {
            listCache[key] = results
        }
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

    func cuisineAreas() async throws -> [CuisineArea] {
        if let cachedCuisineAreas { return cachedCuisineAreas }
        let url = try endpoint("list.php", queryItems: [URLQueryItem(name: "a", value: "list")])
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MealDBError.badResponse
        }
        struct ListEnvelope: Decodable {
            struct Item: Decodable {
                let strArea: String?
                let strCountry: String?
            }
            let meals: [Item]?
        }
        let decoded = try JSONDecoder().decode(ListEnvelope.self, from: data)
        let catalog = (decoded.meals ?? []).compactMap { item -> CuisineArea? in
            guard let name = item.strArea, !name.isEmpty else { return nil }
            return CuisineArea(name: name, country: item.strCountry ?? "")
        }
        cachedCuisineAreas = catalog
        return catalog
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

    private func filter(ingredient: String) async throws -> [DiscoveredRecipeSummary] {
        let url = try endpoint("filter.php", queryItems: [URLQueryItem(name: "i", value: ingredient)])
        return try await fetchMeals(url: url).map { $0.asSummary }
    }

    private func ingredients() async throws -> [String] {
        if let cachedIngredients { return cachedIngredients }
        let url = try endpoint("list.php", queryItems: [URLQueryItem(name: "i", value: "list")])
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MealDBError.badResponse
        }
        struct ListEnvelope: Decodable {
            struct Item: Decodable { let strIngredient: String? }
            let meals: [Item]?
        }
        let decoded = try JSONDecoder().decode(ListEnvelope.self, from: data)
        let list = (decoded.meals ?? []).compactMap(\.strIngredient).filter { !$0.isEmpty }
        cachedIngredients = list
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
        let normalized = CuisineTaxonomy.normalized(query)
        guard normalized.count >= 3 else { return nil }
        let catalog: [CuisineArea]
        do {
            catalog = try await cuisineAreas()
        } catch {
            AppLog.storage.error("MealDB cuisine index failed")
            return nil
        }
        if let exact = catalog.first(where: {
            CuisineTaxonomy.normalized($0.name) == normalized
                || CuisineTaxonomy.normalized($0.country) == normalized
        }) {
            return exact.name
        }
        return catalog.first(where: {
            CuisineTaxonomy.normalized($0.name).hasPrefix(normalized)
                || CuisineTaxonomy.normalized($0.country).hasPrefix(normalized)
        })?.name
    }

    private func matchedRemoteCategory(for query: String) async -> String? {
        let normalized = CuisineTaxonomy.normalized(query)
        guard normalized.count >= 3 else { return nil }
        let list: [String]
        do {
            list = try await categories()
        } catch {
            AppLog.storage.error("MealDB category index failed")
            return nil
        }
        return list.first { CuisineTaxonomy.normalized($0) == normalized }
    }

    private func matchedRemoteIngredient(for query: String) async -> String? {
        let normalizedTerms = CuisineTaxonomy.normalized(query)
            .split(separator: " ")
            .map(String.init)
        guard !normalizedTerms.isEmpty,
              normalizedTerms.count <= 2,
              normalizedTerms.joined().count >= 4 else { return nil }
        let list: [String]
        do {
            list = try await ingredients()
        } catch {
            AppLog.storage.error("MealDB ingredient index failed")
            return nil
        }
        return list.first { ingredient in
            let candidateTerms = CuisineTaxonomy.normalized(ingredient)
                .split(separator: " ")
                .map(String.init)
            return normalizedTerms.allSatisfy { term in candidateTerms.contains { $0.hasPrefix(term) } }
        }
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
