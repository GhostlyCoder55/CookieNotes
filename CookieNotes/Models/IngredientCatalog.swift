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
    static let shared: IngredientCatalogFile = load()

    private static func load() -> IngredientCatalogFile {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "IngredientCatalog", withExtension: "json"),
            Bundle.main.url(forResource: "IngredientCatalog", withExtension: "json", subdirectory: "Resources")
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
                assertionFailure("IngredientCatalog.json failed to decode: \(error)")
            }
        }
        assertionFailure("IngredientCatalog.json missing from app bundle")
        return IngredientCatalogFile(categories: [], displayNames: [:], aliases: [:])
    }

    static func displayName(for iconID: String) -> String {
        shared.displayNames[iconID] ?? iconID.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func iconID(matching text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        if let cached = matchCache.value(for: trimmed) { return cached.isEmpty ? nil : cached }

        let match = shared.aliases[trimmed]
            ?? aliasesByLength.first { trimmed.contains($0.key) }?.icon
            ?? namesByLength.first { trimmed.contains($0.key) }?.icon
        matchCache.set(match ?? "", for: trimmed)
        return match
    }

    /// Longest phrase wins ("beef stock" before "beef") and the result no longer
    /// depends on dictionary iteration order.
    private static let aliasesByLength: [(key: String, icon: String)] = shared.aliases
        .map { (key: $0.key.lowercased(), icon: $0.value) }
        .filter { !$0.key.isEmpty }
        .sorted { $0.key.count != $1.key.count ? $0.key.count > $1.key.count : $0.key < $1.key }

    private static let namesByLength: [(key: String, icon: String)] = shared.displayNames
        .map { (key: $0.value.lowercased(), icon: $0.key) }
        .filter { !$0.key.isEmpty }
        .sorted { $0.key.count != $1.key.count ? $0.key.count > $1.key.count : $0.key < $1.key }

    private static let matchCache = LockedCache<String, String>()

    static let allIcons: [String] = Array(Set(shared.categories.flatMap(\.icons))).sorted()
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
