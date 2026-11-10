//
//  TheMealDBCatalog.swift
//  CookieNotes
//
//  Pre-translated French recipes for TheMealDB catalog.
//

import Foundation

struct TheMealDBRecord: Codable, Sendable {
    let id: String
    let name: String
    let ingredients: [String]
    let instructions: [String]
    let category: String?
    let area: String?
    var thumbnailURL: String? = nil

    var summary: DiscoveredRecipeSummary {
        DiscoveredRecipeSummary(
            id: id,
            name: name,
            thumbnailURL: thumbnailURL.flatMap(URL.init(string:)),
            category: category,
            area: area
        )
    }

    func matches(searchTerms terms: [String]) -> Bool {
        let areaLabel = area.map { String.localized($0, defaultValue: $0) } ?? ""
        let categoryLabel = category.map { String.localized($0, defaultValue: $0) } ?? ""
        let searchableWords = (
            [name, category ?? "", categoryLabel, area ?? "", areaLabel]
                + ingredients
        )
        .map(CuisineTaxonomy.normalized)
        .joined(separator: " ")
        .split(separator: " ")
        .map(String.init)

        return terms.allSatisfy { queryTerm in
            searchableWords.contains { $0 == queryTerm || $0.hasPrefix(queryTerm) }
        }
    }
}

enum TheMealDBCatalog {
    private static let lock = NSLock()
    private static var isLoaded = false
    private static var records: [String: TheMealDBRecord] = [:]

    private static func ensureLoaded() {
        lock.lock()
        defer { lock.unlock() }
        guard !isLoaded else { return }
        isLoaded = true

        let urls: [URL?] = [
            Bundle.main.url(forResource: "TheMealDB_fr", withExtension: "json"),
            Bundle.main.url(forResource: "TheMealDB_fr", withExtension: "json", subdirectory: "Resources")
        ]
        for case let url? in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let decoded = try? JSONDecoder().decode([String: TheMealDBRecord].self, from: data) {
                records = decoded
                return
            }
        }
    }

    static func record(for id: String) -> TheMealDBRecord? {
        guard !MealDBClient.isExcluded(id: id, name: nil) else { return nil }
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return records[id]
    }

    static func translatedName(for id: String) -> String? {
        record(for: id)?.name
    }

    static func search(query: String) -> [DiscoveredRecipeSummary] {
        let terms = CuisineTaxonomy.normalized(query)
            .split(separator: " ")
            .map(String.init)
        guard !terms.isEmpty else { return [] }
        ensureLoaded()
        let snapshot = lock.withLock { Array(records.values) }
        let matched = snapshot.filter { record in
            !MealDBClient.isExcluded(id: record.id, name: record.name) && record.matches(searchTerms: terms)
        }
        return MealDBClient.alphabeticallySorted(matched.map(\.summary))
    }
}
