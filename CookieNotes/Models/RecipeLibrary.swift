//
//  RecipeLibrary.swift
//  CookieNotes
//

import Foundation

protocol RecipeSearchable {
    var name: String { get }
    var ingredients: [String] { get }
    var instructions: [String] { get }
    var notes: String { get }
    var source: String { get }
    var prepTime: Int { get }
    var cookTime: Int { get }
    var dateCreated: Date { get }
    var dateModified: Date { get }
    var hasPhotos: Bool { get }
    var isSample: Bool { get }
    var isFavorite: Bool { get }
    var categoryRaw: String { get }
}

extension RecipeSearchable {
    var totalTime: Int { prepTime + cookTime }

    var category: RecipeCategory {
        RecipeCategory(rawValue: categoryRaw) ?? .uncategorized
    }
}

enum RecipeSort: String, CaseIterable, Identifiable {
    case newest
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest"
        case .name: "Name"
        }
    }
}

enum RecipeFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case breakfast
    case lunch
    case dinner
    case dessert
    case snack
    case drinks
    case sides

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .breakfast: RecipeCategory.breakfast.title
        case .lunch: RecipeCategory.lunch.title
        case .dinner: RecipeCategory.dinner.title
        case .dessert: RecipeCategory.dessert.title
        case .snack: RecipeCategory.snack.title
        case .drinks: RecipeCategory.drinks.title
        case .sides: RecipeCategory.sides.title
        }
    }

    /// Matching meal category when this filter is category-based.
    var mealCategory: RecipeCategory? {
        switch self {
        case .all, .favorites: nil
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .dinner: .dinner
        case .dessert: .dessert
        case .snack: .snack
        case .drinks: .drinks
        case .sides: .sides
        }
    }
}

enum RecipeLibrary {
    static func prepare<T: RecipeSearchable>(
        _ recipes: [T],
        query: String = "",
        filter: RecipeFilter = .all,
        sort: RecipeSort = .newest
    ) -> [T] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Cheap category check first so text search only scans recipes that can show.
        let filtered = recipes.filter { recipe in
            matches(recipe, filter: filter) && matches(recipe, query: trimmedQuery)
        }
        return sorted(filtered, by: sort)
    }

    static func matches<T: RecipeSearchable>(_ recipe: T, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if recipe.name.localizedCaseInsensitiveContains(query) { return true }
        if recipe.notes.localizedCaseInsensitiveContains(query) { return true }
        if recipe.source.localizedCaseInsensitiveContains(query) { return true }
        if recipe.ingredients.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        return recipe.instructions.contains(where: { $0.localizedCaseInsensitiveContains(query) })
    }

    static func matches<T: RecipeSearchable>(_ recipe: T, filter: RecipeFilter) -> Bool {
        // Example / seeded recipes are excluded from the personal library.
        guard !recipe.isSample else { return false }
        switch filter {
        case .all:
            return true
        case .favorites:
            return recipe.isFavorite
        case .breakfast, .lunch, .dinner, .dessert, .snack, .drinks, .sides:
            return recipe.category == filter.mealCategory
        }
    }

    static func sorted<T: RecipeSearchable>(_ recipes: [T], by sort: RecipeSort) -> [T] {
        switch sort {
        case .newest:
            return recipes.sorted { lhs, rhs in
                if lhs.dateCreated != rhs.dateCreated {
                    return lhs.dateCreated > rhs.dateCreated
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        case .name:
            return recipes.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }
}
