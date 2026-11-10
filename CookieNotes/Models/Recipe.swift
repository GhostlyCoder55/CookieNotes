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
    /// Stable, language-independent catalog identifier (e.g. "local-jollof-rice" or "52928").
    /// Empty for user-created recipes.
    var catalogRecipeID: String = ""
    /// True while this saved recipe mirrors bundled/catalog text in the active language.
    /// Set to false when the user edits the recipe title, ingredients, or instructions.
    var isCatalogSynced: Bool = false
    /// English master snapshot captured when saving a remote catalog recipe while in French.
    var syncedEnglishName: String = ""
    var syncedEnglishIngredients: [String] = []
    var syncedEnglishInstructions: [String] = []
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
        catalogRecipeID: String = "",
        isCatalogSynced: Bool = false,
        syncedEnglishName: String = "",
        syncedEnglishIngredients: [String] = [],
        syncedEnglishInstructions: [String] = [],
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
        self.catalogRecipeID = catalogRecipeID
        self.isCatalogSynced = isCatalogSynced
        self.syncedEnglishName = syncedEnglishName
        self.syncedEnglishIngredients = syncedEnglishIngredients
        self.syncedEnglishInstructions = syncedEnglishInstructions
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

    /// One or more icons for the cover — dinner/dessert use a small dish cluster.
    var resolvedCoverElements: [String] {
        let dishCategories: Set<RecipeCategory> = [.dinner, .dessert]
        let legacySingles: [RecipeCategory: Set<String>] = [
            .dinner: ["roast_chicken", "spaghetti_bowl", "plated_meal", "steak", "salmon_steak", "ribeye_steak", "soup_bowl"],
            .dessert: ["cupcake"]
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

    var hasPhotos: Bool {
        !(photos ?? []).isEmpty
    }

    var formattedTotalTime: String {
        totalTime == 0 ? String.localized("Instant") : String.localized("%@ total", RecipeTimeFormat.short(totalTime))
    }

    var formattedServings: String? {
        guard servings > 0 else { return nil }
        return servings == 1 ? String.localized("1 serving") : String.localized("%lld servings", servings)
    }

    private var resolvedCatalogContent: (name: String, ingredients: [String], instructions: [String])? {
        guard isCatalogSynced, !catalogRecipeID.isEmpty else { return nil }
        let canonicalID = MealDBClient.canonicalRecipeID(for: catalogRecipeID)
        let activeLanguage = AppLanguageManager.shared.activeLanguage

        if let localRecord = LocalMealCatalog.record(id: canonicalID, language: activeLanguage) {
            return (
                localRecord.name,
                localRecord.ingredients,
                RecipeSanitizer.cleanInstructions(localRecord.instructions, recipeName: localRecord.name)
            )
        }

        if activeLanguage == .french, let mdbRecord = TheMealDBCatalog.record(for: canonicalID) {
            return (
                mdbRecord.name,
                mdbRecord.ingredients,
                RecipeSanitizer.cleanInstructions(mdbRecord.instructions, recipeName: mdbRecord.name)
            )
        }

        if activeLanguage == .english, !syncedEnglishName.isEmpty {
            return (
                syncedEnglishName,
                syncedEnglishIngredients,
                RecipeSanitizer.cleanInstructions(syncedEnglishInstructions, recipeName: syncedEnglishName)
            )
        }

        return nil
    }

    var localizedName: String {
        resolvedCatalogContent?.name ?? name
    }

    var localizedIngredients: [String] {
        resolvedCatalogContent?.ingredients ?? ingredients
    }

    var localizedInstructions: [String] {
        resolvedCatalogContent?.instructions ?? RecipeSanitizer.cleanInstructions(instructions, recipeName: name)
    }

    var accessibilitySummary: String {
        var parts = [localizedName, formattedTotalTime]
        if let formattedServings {
            parts.append(formattedServings)
        }
        if !localizedIngredients.isEmpty {
            parts.append(String.localized("%lld ingredients", localizedIngredients.count))
        }
        if isSample {
            parts.append(String.localized("example"))
        }
        if isFavorite {
            parts.append(String.localized("favorite"))
        }
        if hasPhotos {
            parts.append(String.localized("has photos"))
        }
        return parts.joined(separator: ", ")
    }

    var shareText: String {
        let displayTitle = localizedName
        let displayIngredients = localizedIngredients
        let cleanInstructions = localizedInstructions
        var lines: [String] = [displayTitle, ""]
        var meta: [String] = []
        if totalTime > 0 {
            meta.append(String.localized("Prep %lld min · Cook %lld min", prepTime, cookTime))
        }
        if let formattedServings {
            meta.append(formattedServings)
        }
        if !meta.isEmpty {
            lines.append(meta.joined(separator: " · "))
            lines.append("")
        }
        if !displayIngredients.isEmpty {
            lines.append(String.localized("Ingredients"))
            lines.append(contentsOf: displayIngredients.map { "• \($0)" })
            lines.append("")
        }
        if !cleanInstructions.isEmpty {
            lines.append(String.localized("Instructions"))
            for (index, step) in cleanInstructions.enumerated() {
                lines.append("\(index + 1). \(step)")
            }
            lines.append("")
        }
        if !notes.isEmpty {
            lines.append(String.localized("Notes"))
            lines.append(notes)
            lines.append("")
        }
        if !source.isEmpty {
            lines.append(String.localized("Source: %@", source))
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

extension Recipe: RecipeSearchable {
    var searchableName: String { localizedName }
    var searchableIngredients: [String] { localizedIngredients }
    var searchableInstructions: [String] { localizedInstructions }
}
