//
//  SharedRecipePayload.swift
//  CookieNotes
//

import Foundation

/// A recipe handed from the share extension to the app through the App Group inbox.
struct SharedRecipePayload: Codable, Equatable, Sendable {
    var title: String
    var url: String
    var text: String
    var imageData: Data?
    var receivedAt: Date
}

struct RecipeDraft: Equatable, Sendable {
    var name: String
    var ingredients: [String]
    var instructions: [String]
    var notes: String
    var source: String
    var servings: Int = 0
}

enum RecipeInputLimits {
    static let name = 120
    static let ingredient = 200
    static let ingredientCount = 80
    static let instruction = 2_000
    static let instructionCount = 80
    static let notes = 4_000
    static let source = 500
    static let photoCount = 5
    static let maxMinutes = 24 * 60
    static let maxServings = 99
    static let libraryIngredientName = 80
    static let libraryIngredientDetail = 40
    static let sharedText = 20_000
    static let sharedImageBytes = 8_000_000
}
