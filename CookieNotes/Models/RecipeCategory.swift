//
//  RecipeCategory.swift
//  CookieNotes
//

import SwiftUI

enum RecipeCategory: String, CaseIterable, Identifiable, Codable {
    case uncategorized
    case breakfast
    case lunch
    case dinner
    case dessert
    case drinks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uncategorized: String.localized("General")
        case .breakfast: String.localized("Breakfast")
        case .lunch: String.localized("Lunch")
        case .dinner: String.localized("Dinner")
        case .dessert: String.localized("Dessert")
        case .drinks: String.localized("Drinks")
        }
    }

    var color: Color {
        switch self {
        case .uncategorized: AppTheme.goldenYellow
        case .breakfast: AppTheme.brightOrange
        case .lunch: AppTheme.leafGreen
        case .dinner: AppTheme.burntOrange
        case .dessert: AppTheme.warmBrown
        case .drinks: AppTheme.brightOrange
        }
    }

    var iconName: String {
        switch self {
        case .uncategorized: "veggie_plate"
        case .breakfast: "pancakes"
        case .lunch: "salad_bowl"
        case .dinner: "soup_bowl"
        case .dessert: "berries_bowl"
        case .drinks: "berry_smoothie"
        }
    }

    /// Icons arranged back → front when the category cover should read as a full dish.
    var coverElements: [String] {
        switch self {
        case .dinner:
            return ["soup_bowl"]
        case .dessert:
            return ["strawberry", "ice_cream", "cupcake"]
        default:
            return [iconName]
        }
    }

    /// Cover asset written onto a recipe when this category is selected.
    var preferredCoverIconID: String { iconName }

    /// Maps TheMealDB category strings onto CookieNotes meal categories.
    static func inferred(fromMealDB category: String?) -> RecipeCategory {
        guard let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return .uncategorized
        }
        switch raw {
        case "breakfast":
            return .breakfast
        case "dessert":
            return .dessert
        case "drink", "drinks", "beverage", "beverages":
            return .drinks
        case "vegetarian", "vegan":
            return .lunch
        case "chicken", "beef", "pork", "lamb", "goat", "seafood", "pasta", "miscellaneous":
            return .dinner
        default:
            return .uncategorized
        }
    }
}
