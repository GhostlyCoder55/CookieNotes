//
//  Recipe.swift
//  CookieNotes
//

import Foundation
import SwiftData

@Model
final class Recipe {
    var recipeID: UUID = UUID()
    var name: String = ""
    var ingredients: [String] = []
    var instructions: [String] = []
    var notes: String = ""
    var source: String = ""
    var prepTime: Int = 0
    var cookTime: Int = 0
    /// 0 means servings are not set.
    var servings: Int = 0
    /// Seeded example recipe shown with an “Example” badge.
    var isSample: Bool = false
    /// Saved from share extension or online discovery.
    var isImported: Bool = false
    var isFavorite: Bool = false
    /// `RecipeCategory.rawValue`; empty means general/uncategorized.
    var categoryRaw: String = RecipeCategory.uncategorized.rawValue
    /// Parallel to `ingredients`; empty string means no illustration.
    var ingredientIconIDs: [String] = []
    /// Optional cover illustration asset name when no photo exists.
    var coverIconID: String = ""
    /// When true, library/detail covers use category art instead of Discover photos.
    var usesCategoryCover: Bool = false
    var dateCreated: Date = Date()
    var dateModified: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \RecipePhoto.recipe)
    var photos: [RecipePhoto]? = []

    init(
        recipeID: UUID = UUID(),
        name: String,
        ingredients: [String] = [],
        instructions: [String] = [],
        notes: String = "",
        source: String = "",
        prepTime: Int = 0,
        cookTime: Int = 0,
        servings: Int = 0,
        isSample: Bool = false,
        isImported: Bool = false,
        isFavorite: Bool = false,
        categoryRaw: String = RecipeCategory.uncategorized.rawValue,
        ingredientIconIDs: [String] = [],
        coverIconID: String = "",
        usesCategoryCover: Bool = false,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.recipeID = recipeID
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.notes = notes
        self.source = source
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.isSample = isSample
        self.isImported = isImported
        self.isFavorite = isFavorite
        self.categoryRaw = categoryRaw
        self.ingredientIconIDs = ingredientIconIDs
        self.coverIconID = coverIconID
        self.usesCategoryCover = usesCategoryCover
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.photos = []
    }

    var category: RecipeCategory {
        get { RecipeCategory(rawValue: categoryRaw) ?? .uncategorized }
        set { categoryRaw = newValue.rawValue }
    }

    func iconID(forIngredientIndex index: Int) -> String {
        guard ingredientIconIDs.indices.contains(index) else { return "" }
        return ingredientIconIDs[index]
    }

    func syncIngredientIcons(from lines: [EditableLine]) {
        ingredientIconIDs = lines.map(\.iconID)
    }

    var resolvedCoverIcon: String {
        resolvedCoverElements.first ?? category.iconName
    }

    /// One or more icons for the cover — dinner/dessert/snack use a small dish cluster.
    var resolvedCoverElements: [String] {
        let dishCategories: Set<RecipeCategory> = [.dinner, .dessert, .snack]
        let legacySingles: [RecipeCategory: Set<String>] = [
            .dinner: ["roast_chicken", "spaghetti_bowl", "plated_meal", "steak", "salmon_steak", "ribeye_steak", "soup_bowl"],
            .dessert: ["cupcake"],
            .snack: ["cookie"]
        ]

        if coverIconID.isEmpty {
            if let first = ingredientIconIDs.first(where: { !$0.isEmpty }) {
                return [first]
            }
            return category.coverElements
        }

        if dishCategories.contains(category),
           coverIconID == category.preferredCoverIconID
            || coverIconID == category.iconName
            || legacySingles[category]?.contains(coverIconID) == true {
            return category.coverElements
        }

        return [coverIconID]
    }

    var totalTime: Int {
        prepTime + cookTime
    }

    var sortedPhotos: [RecipePhoto] {
        (photos ?? []).sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            return lhs.photoID.uuidString < rhs.photoID.uuidString
        }
    }

    /// Library/detail cover: first photo when present; illustration only as a fallback.
    var cardThumbnail: Data? {
        sortedPhotos.first?.thumbnailData
    }

    /// Applies a meal category and its default cover illustration (used when there are no photos).
    func applyCategoryCover(_ newCategory: RecipeCategory) {
        category = newCategory
        coverIconID = newCategory.preferredCoverIconID
        usesCategoryCover = true
    }

    var hasPhotos: Bool {
        !(photos ?? []).isEmpty
    }

    var formattedPrepTime: String {
        prepTime == 0 ? "No prep" : "\(prepTime) min prep"
    }

    var formattedCookTime: String {
        cookTime == 0 ? "No cook" : "\(cookTime) min cook"
    }

    var formattedTotalTime: String {
        totalTime == 0 ? "Instant" : "\(RecipeTimeFormat.short(totalTime)) total"
    }

    var formattedServings: String? {
        guard servings > 0 else { return nil }
        return servings == 1 ? "1 serving" : "\(servings) servings"
    }

    var accessibilitySummary: String {
        var parts = [name, formattedTotalTime]
        if let formattedServings {
            parts.append(formattedServings)
        }
        if !ingredients.isEmpty {
            parts.append("\(ingredients.count) ingredients")
        }
        if isSample {
            parts.append("example")
        }
        if isFavorite {
            parts.append("favorite")
        }
        if hasPhotos {
            parts.append("has photos")
        }
        return parts.joined(separator: ", ")
    }

    var shareText: String {
        var lines: [String] = [name, ""]
        var meta: [String] = []
        if totalTime > 0 {
            meta.append("Prep \(prepTime) min · Cook \(cookTime) min")
        }
        if let formattedServings {
            meta.append(formattedServings)
        }
        if !meta.isEmpty {
            lines.append(meta.joined(separator: " · "))
            lines.append("")
        }
        if !ingredients.isEmpty {
            lines.append("Ingredients")
            lines.append(contentsOf: ingredients.map { "• \($0)" })
            lines.append("")
        }
        if !instructions.isEmpty {
            lines.append("Instructions")
            for (index, step) in instructions.enumerated() {
                lines.append("\(index + 1). \(step)")
            }
            lines.append("")
        }
        if !notes.isEmpty {
            lines.append("Notes")
            lines.append(notes)
            lines.append("")
        }
        if !source.isEmpty {
            lines.append("Source: \(source)")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class RecipePhoto {
    var photoID: UUID = UUID()
    var sortIndex: Int = 0
    @Attribute(.externalStorage) var imageData: Data = Data()
    var thumbnailData: Data = Data()
    var recipe: Recipe?

    init(photoID: UUID = UUID(), sortIndex: Int, imageData: Data, thumbnailData: Data) {
        self.photoID = photoID
        self.sortIndex = sortIndex
        self.imageData = imageData
        self.thumbnailData = thumbnailData
    }
}

/// Reusable ingredient for the Ingredients tab (not tied to one recipe).
@Model
final class LibraryIngredient {
    var ingredientID: UUID = UUID()
    var name: String = ""
    /// Optional amount or note, e.g. "1 cup" or "to taste".
    var detail: String = ""
    var dateCreated: Date = Date()
    var dateModified: Date = Date()

    init(
        ingredientID: UUID = UUID(),
        name: String,
        detail: String = "",
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.ingredientID = ingredientID
        self.name = name
        self.detail = detail
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    var displayLine: String {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDetail.isEmpty { return trimmedName }
        if trimmedName.isEmpty { return trimmedDetail }
        return "\(trimmedDetail) \(trimmedName)"
    }
}

extension Recipe: RecipeSearchable {}
