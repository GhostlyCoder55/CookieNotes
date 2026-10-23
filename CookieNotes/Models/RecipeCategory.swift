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
    case snack
    case drinks
    case sides

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uncategorized: "General"
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .dessert: "Dessert"
        case .snack: "Snack"
        case .drinks: "Drinks"
        case .sides: "Sides"
        }
    }

    var color: Color {
        switch self {
        case .uncategorized: AppTheme.goldenYellow
        case .breakfast: AppTheme.brightOrange
        case .lunch: AppTheme.leafGreen
        case .dinner: AppTheme.burntOrange
        case .dessert: AppTheme.warmBrown
        case .snack: AppTheme.goldenYellow
        case .drinks: AppTheme.brightOrange
        case .sides: AppTheme.warmBrown
        }
    }

    var iconName: String {
        switch self {
        case .uncategorized: "veggie_plate"
        case .breakfast: "pancakes"
        case .lunch: "salad_bowl"
        // Multi-element dish covers (plate / bowl compositions, not a single item)
        case .dinner: "plated_meal"
        case .dessert: "berries_bowl"
        case .snack: "candy_bowl"
        case .drinks: "berry_smoothie"
        case .sides: "rice_bowl"
        }
    }

    /// Icons arranged back → front when the category cover should read as a full dish.
    var coverElements: [String] {
        switch self {
        case .dinner:
            // Complete meat meal: steak, seafood, and roast chicken.
            return ["steak", "salmon_steak", "roast_chicken"]
        case .dessert:
            return ["strawberry", "ice_cream", "cupcake"]
        case .snack:
            return ["chips", "donut", "cookie"]
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
        case "starter", "side", "sides":
            return .sides
        case "drink", "drinks", "beverage", "beverages":
            return .drinks
        case "snack", "snacks":
            return .snack
        case "vegetarian", "vegan":
            return .lunch
        case "chicken", "beef", "pork", "lamb", "goat", "seafood", "pasta", "miscellaneous":
            return .dinner
        default:
            return .uncategorized
        }
    }
}
