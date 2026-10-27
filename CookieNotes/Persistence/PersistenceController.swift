//
//  PersistenceController.swift
//  CookieNotes
//

import Foundation
import SwiftData

@MainActor
enum PersistenceController {
    static let legacyRecipesKey = "saved_recipes"
    static let initialSetupKey = "cookienotes.didFinishInitialLibrarySetup"
    static let cloudKitInfoKey = "CookieNotesCloudKitEnabled"

    private(set) static var lastErrorMessage: String?

    private static var schema: Schema {
        Schema([Recipe.self, RecipePhoto.self, LibraryIngredient.self])
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: configuration)
        }

        if cloudKitRequested() {
            do {
                let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                lastErrorMessage = "iCloud sync couldn't start. Recipes are still saved on this device."
                AppLog.storage.error("CloudKit store was unavailable")
            }
        }

        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func makeFallbackContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("CookieNotes could not create a temporary recipe store.")
        }
    }

    private static let purgedDemoRecipesKey = "cookienotes.didPurgeDemoRecipes"

    static func prepareLibrary(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        seedSamples: Bool = false
    ) throws {
        try removeSampleRecipes(from: context)
        try removeLegacyDemoRecipes(from: context, defaults: defaults)

        if defaults.bool(forKey: initialSetupKey) {
            return
        }

        context.autosaveEnabled = false

        if let data = defaults.data(forKey: legacyRecipesKey) {
            do {
                _ = try RecipeMigration.importLegacy(data, into: context)
                defaults.removeObject(forKey: legacyRecipesKey)
                defaults.set(true, forKey: initialSetupKey)
            } catch {
                lastErrorMessage = "Saved recipes could not be moved into the new library. Your previous copy was left untouched."
                AppLog.storage.error("Legacy recipe migration failed")
                throw error
            }
            return
        }

        // Fresh installs start with an empty library — no seeded examples.
        if seedSamples {
            RecipeMigration.insertSample(into: context)
            try context.save()
        }
        defaults.set(true, forKey: initialSetupKey)
        defaults.set(true, forKey: purgedDemoRecipesKey)
    }

    /// Drops seeded example recipes so the library only shows the user's own notes.
    private static func removeSampleRecipes(from context: ModelContext) throws {
        let samples = try context.fetch(
            FetchDescriptor<Recipe>(predicate: #Predicate { $0.isSample == true })
        )
        guard !samples.isEmpty else { return }
        for recipe in samples {
            context.delete(recipe)
        }
        try context.save()
    }

    /// One-time cleanup of earlier demo recipes (fried rice showcase, Cambodian waffles, cookies).
    private static func removeLegacyDemoRecipes(from context: ModelContext, defaults: UserDefaults) throws {
        guard !defaults.bool(forKey: purgedDemoRecipesKey) else { return }

        // Bound string values — SwiftData compiles these into parameterized predicates.
        let friedRice = "Weeknight Fried Rice"
        let cookies = "Chocolate Chip Cookies"
        let cambodian = "Cambodian Waffles"
        let numPoum = "Num Poum"
        let demos = try context.fetch(
            FetchDescriptor<Recipe>(
                predicate: #Predicate { recipe in
                    recipe.name == friedRice
                        || recipe.name == cookies
                        || recipe.name.localizedStandardContains(cambodian)
                        || recipe.name.localizedStandardContains(numPoum)
                }
            )
        )
        for recipe in demos {
            context.delete(recipe)
        }
        if !demos.isEmpty {
            try context.save()
        }
        defaults.set(true, forKey: purgedDemoRecipesKey)
    }

    static let preview: ModelContainer = {
        do {
            let container = try makeContainer(inMemory: true)
            let context = ModelContext(container)
            // Previews may still use the fried-rice fixture for layout checks.
            context.insert(RecipeMigration.showcaseFriedRice(isSample: false))
            try context.save()
            return container
        } catch {
            fatalError("CookieNotes could not create the preview library.")
        }
    }()

    private static func cloudKitRequested() -> Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: cloudKitInfoKey)
        if let flag = value as? Bool {
            return flag
        }
        if let text = value as? String {
            return text == "YES"
        }
        return false
    }
}
