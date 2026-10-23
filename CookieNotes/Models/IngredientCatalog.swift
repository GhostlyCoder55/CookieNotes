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
        if let url = Bundle.main.url(forResource: "IngredientCatalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(IngredientCatalogFile.self, from: data) {
            return decoded
        }
        return IngredientCatalogFile(categories: [], displayNames: [:], aliases: [:])
    }

    static func displayName(for iconID: String) -> String {
        shared.displayNames[iconID] ?? iconID.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func iconID(matching text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        if let exact = shared.aliases[trimmed] { return exact }
        for (alias, icon) in shared.aliases where trimmed.contains(alias) {
            return icon
        }
        for (icon, name) in shared.displayNames where trimmed.contains(name.lowercased()) {
            return icon
        }
        return nil
    }

    static var allIcons: [String] {
        Array(Set(shared.categories.flatMap(\.icons))).sorted()
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
