//
//  RecipeMigration.swift
//  CookieNotes
//

import Foundation
import SwiftData

enum RecipeMigrationError: Error {
    case undecodableLibrary
}

@MainActor
enum RecipeMigration {
    static func importLegacy(_ data: Data, into context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        guard let records = try? decoder.decode([LegacyRecipeRecord].self, from: data) else {
            throw RecipeMigrationError.undecodableLibrary
        }

        for record in records {
            let draft = RecipeSanitizer.clean(
                RecipeDraft(
                    name: record.name.isEmpty ? "Untitled recipe" : record.name,
                    ingredients: record.ingredients,
                    instructions: record.instructions,
                    notes: "",
                    source: ""
                )
            )
            let recipe = Recipe(
                recipeID: record.id,
                name: draft.name,
                ingredients: draft.ingredients,
                instructions: draft.instructions,
                prepTime: RecipeSanitizer.minutes(record.prepTime),
                cookTime: RecipeSanitizer.minutes(record.cookTime),
                isSample: false,
                isImported: false,
                dateCreated: record.dateCreated,
                dateModified: record.dateModified
            )
            context.insert(recipe)

            for (index, photoData) in record.photos.enumerated() {
                guard let stored = PhotoProcessing.makeStoredPhoto(from: photoData) else { continue }
                let photo = RecipePhoto(
                    sortIndex: index,
                    imageData: stored.imageData,
                    thumbnailData: stored.thumbnailData
                )
                photo.recipe = recipe
                context.insert(photo)
            }
        }

        try context.save()
        return records.count
    }

    static func insertSample(into context: ModelContext) {
        for recipe in sampleRecipes() {
            context.insert(recipe)
        }
        for ingredient in sampleLibraryIngredients() {
            context.insert(ingredient)
        }
    }

    /// Single showcase recipe used for previews and first-run library demos.
    static func sampleRecipes() -> [Recipe] {
        [showcaseFriedRice(isSample: true)]
    }

    static func showcaseFriedRice(isSample: Bool = false) -> Recipe {
        Recipe(
            name: "Weeknight Fried Rice",
            ingredients: [
                "3 cups cold cooked rice",
                "2 eggs, beaten",
                "1 cup frozen peas and carrots",
                "½ yellow onion, diced",
                "3 cloves garlic, minced",
                "1 tbsp fresh ginger, grated",
                "3 green onions, sliced",
                "2 tbsp soy sauce",
                "1 tbsp sesame oil",
                "2 tbsp cooking oil",
                "Optional: cooked shrimp or chicken"
            ],
            instructions: [
                "Warm a large skillet or wok over medium high heat with the cooking oil.",
                "Scramble the eggs until just set, then slide them onto a plate.",
                "Sauté onion until translucent, then add garlic and ginger for 30 seconds.",
                "Add peas and carrots; cook until hot and bright.",
                "Add the cold rice and press it into the pan so grains toast for a minute.",
                "Return the eggs, pour in soy sauce and sesame oil, and toss until glossy.",
                "Fold in green onions (and shrimp or chicken if using). Taste and adjust soy.",
                "Serve right away. Open Cook Mode to step through while you stir."
            ],
            notes: "Cold leftover rice fries best. Tap any ingredient to swap illustrations, favorite this card, filter Dinner in Library, or start Cook Mode for hands free steps.",
            prepTime: 12,
            cookTime: 15,
            servings: 4,
            isSample: isSample,
            isFavorite: true,
            categoryRaw: RecipeCategory.dinner.rawValue,
            ingredientIconIDs: [
                "fried_rice_bowl",
                "eggs",
                "peas",
                "onion",
                "garlic",
                "ginger",
                "lettuce",
                "soy_sauce",
                "olive_oil",
                "vegetable_oil",
                "shrimp"
            ],
            coverIconID: "fried_rice_bowl"
        )
    }

    static func sampleLibraryIngredients() -> [LibraryIngredient] {
        [
            LibraryIngredient(name: "soy sauce", detail: "2 tbsp"),
            LibraryIngredient(name: "garlic", detail: "3 cloves"),
            LibraryIngredient(name: "ginger", detail: "1 tbsp"),
            LibraryIngredient(name: "eggs", detail: "2"),
            LibraryIngredient(name: "cooked rice", detail: "3 cups"),
            LibraryIngredient(name: "sesame oil", detail: "1 tbsp")
        ]
    }
}
