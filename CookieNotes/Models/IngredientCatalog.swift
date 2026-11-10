//
//  IngredientCatalog.swift
//  CookieNotes
//

import Foundation
import SwiftUI

struct IngredientCatalogCategory: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let color: String
    let icons: [String]

    var swiftColor: Color {
        Color(hex: color) ?? AppTheme.accent
    }
}

struct IngredientCatalogFile: Codable {
    let categories: [IngredientCatalogCategory]
    let displayNames: [String: String]
    let aliases: [String: String]
}

enum IngredientCatalog {
    private static let englishCatalog: IngredientCatalogFile = load(named: "IngredientCatalog")
    private static let frenchCatalog: IngredientCatalogFile = load(named: "IngredientCatalog_fr")

    static var shared: IngredientCatalogFile {
        AppLanguageManager.shared.activeLanguage == .french ? frenchCatalog : englishCatalog
    }

    private static func load(named name: String) -> IngredientCatalogFile {
        let urls: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: "json"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Resources")
        ]
        for case let url? in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                let decoded = try JSONDecoder().decode(IngredientCatalogFile.self, from: data)
                // Drop empty categories so chips never open onto a blank grid.
                let cleaned = IngredientCatalogFile(
                    categories: decoded.categories.filter { !$0.icons.isEmpty },
                    displayNames: decoded.displayNames,
                    aliases: decoded.aliases
                )
                return cleaned
            } catch {
                assertionFailure("\(name).json failed to decode: \(error)")
            }
        }
        assertionFailure("\(name).json missing from app bundle")
        return IngredientCatalogFile(categories: [], displayNames: [:], aliases: [:])
    }

    static func displayName(for iconID: String) -> String {
        shared.displayNames[iconID] ?? englishCatalog.displayNames[iconID] ?? iconID.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func iconID(matching text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let isFrench = AppLanguageManager.shared.activeLanguage == .french
        let cacheKey = "\(isFrench ? "fr" : "en")|\(trimmed)"
        if let cached = matchCache.value(for: cacheKey) { return cached.isEmpty ? nil : cached }

        let primaryCatalog = isFrench ? frenchCatalog : englishCatalog
        let primaryAliases = isFrench ? frenchAliasesByLength : englishAliasesByLength
        let primaryNames = isFrench ? frenchNamesByLength : englishNamesByLength

        let secondaryCatalog = isFrench ? englishCatalog : frenchCatalog
        let secondaryAliases = isFrench ? englishAliasesByLength : frenchAliasesByLength
        let secondaryNames = isFrench ? englishNamesByLength : frenchNamesByLength

        let folded = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let match = matchIn(catalog: primaryCatalog, aliases: primaryAliases, names: primaryNames, term: trimmed)
            ?? (folded != trimmed ? matchIn(catalog: primaryCatalog, aliases: primaryAliases, names: primaryNames, term: folded) : nil)
            ?? matchIn(catalog: secondaryCatalog, aliases: secondaryAliases, names: secondaryNames, term: trimmed)
            ?? (folded != trimmed ? matchIn(catalog: secondaryCatalog, aliases: secondaryAliases, names: secondaryNames, term: folded) : nil)

        matchCache.set(match ?? "", for: cacheKey)
        return match
    }

    private static func matchIn(
        catalog: IngredientCatalogFile,
        aliases: [(key: String, icon: String)],
        names: [(key: String, icon: String)],
        term: String
    ) -> String? {
        catalog.aliases[term]
            ?? aliases.first { term.contains($0.key) }?.icon
            ?? names.first { term.contains($0.key) }?.icon
    }

    private static func sortedAliases(from dict: [String: String]) -> [(key: String, icon: String)] {
        dict
            .map { (key: $0.key.lowercased(), icon: $0.value) }
            .filter { !$0.key.isEmpty }
            .sorted { $0.key.count != $1.key.count ? $0.key.count > $1.key.count : $0.key < $1.key }
    }

    private static func sortedNames(from dict: [String: String]) -> [(key: String, icon: String)] {
        dict
            .map { (key: $0.value.lowercased(), icon: $0.key) }
            .filter { !$0.key.isEmpty }
            .sorted { $0.key.count != $1.key.count ? $0.key.count > $1.key.count : $0.key < $1.key }
    }

    private static let englishAliasesByLength: [(key: String, icon: String)] = sortedAliases(from: englishCatalog.aliases)
    private static let englishNamesByLength: [(key: String, icon: String)] = sortedNames(from: englishCatalog.displayNames)

    private static let frenchAliasesByLength: [(key: String, icon: String)] = sortedAliases(from: frenchCatalog.aliases)
    private static let frenchNamesByLength: [(key: String, icon: String)] = sortedNames(from: frenchCatalog.displayNames)

    private static let matchCache = LockedCache<String, String>()

    static let allIcons: [String] = Array(Set(englishCatalog.categories.flatMap(\.icons))).sorted()
}

final class LockedCache<Key: Hashable, Value>: @unchecked Sendable {
    private var storage: [Key: Value] = [:]
    private let lock = NSLock()

    func value(for key: Key) -> Value? {
        lock.withLock { storage[key] }
    }

    func set(_ value: Value, for key: Key) {
        lock.withLock { storage[key] = value }
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = UInt64(value, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
