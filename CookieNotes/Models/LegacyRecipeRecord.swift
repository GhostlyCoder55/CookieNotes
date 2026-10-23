//
//  LegacyRecipeRecord.swift
//  CookieNotes
//

import Foundation

/// The recipe shape previously archived in UserDefaults.
struct LegacyRecipeRecord: Decodable, Equatable {
    var id: UUID
    var name: String
    var ingredients: [String]
    var instructions: [String]
    var prepTime: Int
    var cookTime: Int
    var photos: [Data]
    var dateCreated: Date
    var dateModified: Date

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        instructions = try container.decodeIfPresent([String].self, forKey: .instructions) ?? []
        prepTime = try container.decodeIfPresent(Int.self, forKey: .prepTime) ?? 0
        cookTime = try container.decodeIfPresent(Int.self, forKey: .cookTime) ?? 0
        photos = try container.decodeIfPresent([Data].self, forKey: .photos) ?? []
        dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        dateModified = try container.decodeIfPresent(Date.self, forKey: .dateModified) ?? dateCreated
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, ingredients, instructions, prepTime, cookTime, photos, dateCreated, dateModified
    }
}
