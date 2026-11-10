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
                lastErrorMessage = String.localized("iCloud sync couldn't start. Recipes are still saved on this device.")
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
    private static let purgedExcludedV1Key = "cookienotes.didPurgeExcludedAndMigrateSnackV1"
    private static let migratedCatalogIdentityV1Key = "cookienotes.didMigrateCatalogIdentityV1"

    enum DiscoveredRecipeSaveResult: Equatable {
        case inserted
        case updatedExisting
    }

    static func prepareLibrary(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        seedSamples: Bool = false
    ) throws {
        try removeSampleRecipes(from: context)
        try removeLegacyDemoRecipes(from: context, defaults: defaults)
        try purgeExcludedRecipesAndMigrateSnacks(from: context, defaults: defaults)
        try deduplicateCatalogRecipesIfNeeded(from: context, defaults: defaults)

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
                lastErrorMessage = String.localized("Saved recipes could not be moved into the new library. Your previous copy was left untouched.")
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
        let friedRiceFr = "Riz frit de semaine"
        let cookies = "Chocolate Chip Cookies"
        let cambodian = "Cambodian Waffles"
        let numPoum = "Num Poum"
        let demos = try context.fetch(
            FetchDescriptor<Recipe>(
                predicate: #Predicate { recipe in
                    recipe.name == friedRice
                        || recipe.name == friedRiceFr
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

    /// Removes excluded Bouzgene recipes and migrates any legacy Snack category recipes to General.
    private static func purgeExcludedRecipesAndMigrateSnacks(from context: ModelContext, defaults: UserDefaults) throws {
        guard !defaults.bool(forKey: purgedExcludedV1Key) else { return }

        let allRecipes = try context.fetch(FetchDescriptor<Recipe>())
        var changed = false
        for recipe in allRecipes {
            let folded = recipe.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            if folded.contains("bouzgene") || recipe.source.contains("53284") {
                context.delete(recipe)
                changed = true
            } else if recipe.categoryRaw.lowercased() == "snack" || recipe.categoryRaw.lowercased() == "snacks" {
                recipe.categoryRaw = RecipeCategory.uncategorized.rawValue
                changed = true
            }
        }
        if defaults.string(forKey: "cookienotes.recipeFilter") == "snack" {
            defaults.set(RecipeFilter.all.rawValue, forKey: "cookienotes.recipeFilter")
        }
        if changed {
            try context.save()
        }
        defaults.set(true, forKey: purgedExcludedV1Key)
    }

    // MARK: - Canonical Catalog Identity & Idempotent Save

    private struct LegacyCatalogSignature {
        let canonicalID: String
        let sourceURL: String
        let englishTitle: String
        let frenchTitle: String
    }

    /// The 18 `local-mdb-*` duplicates removed from `LocalMealCatalog*.json` alongside their legacy
    /// paraphrased French titles so pre-existing user saves can merge safely into their canonical ID.
    private static let legacyRemovedLocalMDBSignatures: [LegacyCatalogSignature] = [
        LegacyCatalogSignature(canonicalID: "52928", sourceURL: "https://www.tastemade.com/videos/beavertails", englishTitle: "BeaverTails", frenchTitle: "Queues de castor (BeaverTails)"),
        LegacyCatalogSignature(canonicalID: "52965", sourceURL: "http://www.vodkaandbiscuits.com/2014/03/06/bangin-breakfast-potatoes/", englishTitle: "Breakfast Potatoes", frenchTitle: "Pommes de terre déjeuner au bacon et sirop d'érable"),
        LegacyCatalogSignature(canonicalID: "52923", sourceURL: "https://www.bbcgoodfood.com/recipes/1837/canadian-butter-tarts", englishTitle: "Canadian Butter Tarts", frenchTitle: "Tartelettes au beurre canadiennes"),
        LegacyCatalogSignature(canonicalID: "53343", sourceURL: "https://canadianfoodfocus.org/recipes/classic-canadian-dish-classic-tourtiere/", englishTitle: "Classic Tourtière", frenchTitle: "Tourtière classique québécoise"),
        LegacyCatalogSignature(canonicalID: "53338", sourceURL: "https://canadianfoodfocus.org/recipes/classic-canadian-dishes-date-squares/", englishTitle: "Date squares", frenchTitle: "Carrés aux dattes"),
        LegacyCatalogSignature(canonicalID: "53342", sourceURL: "https://canadianfoodfocus.org/recipes/classic-canadian-dish-figgy-duff/", englishTitle: "Figgy Duff", frenchTitle: "Figgy duff de Terre-Neuve"),
        LegacyCatalogSignature(canonicalID: "52826", sourceURL: "http://www.telegraph.co.uk/food-and-drink/recipes/braised-beef-chilli-con-carne/", englishTitle: "Braised Beef Chilli", frenchTitle: "Chili de bœuf braisé au chorizo"),
        LegacyCatalogSignature(canonicalID: "52819", sourceURL: "https://realfood.tesco.com/recipes/cajun-spiced-fish-tacos.html", englishTitle: "Cajun spiced fish tacos", frenchTitle: "Tacos de poisson aux épices cajuns"),
        LegacyCatalogSignature(canonicalID: "52765", sourceURL: "https://www.themealdb.com/meal/52765", englishTitle: "Chicken Enchilada Casserole", frenchTitle: "Casserole d'enchiladas au poulet"),
        LegacyCatalogSignature(canonicalID: "52870", sourceURL: "https://www.bbcgoodfood.com/recipes/chickpea-fajitas", englishTitle: "Chickpea Fajitas", frenchTitle: "Fajitas aux pois chiches"),
        LegacyCatalogSignature(canonicalID: "52830", sourceURL: "http://www.nobiggie.net/crock-pot-chicken-baked-tacos/", englishTitle: "Crock Pot Chicken Baked Tacos", frenchTitle: "Tacos au poulet à la mijoteuse"),
        LegacyCatalogSignature(canonicalID: "53067", sourceURL: "https://www.themealdb.com/meal/53067", englishTitle: "Stuffed Bell Peppers with Quinoa and Black Beans", frenchTitle: "Poivrons farcis au quinoa et haricots noirs"),
        LegacyCatalogSignature(canonicalID: "52940", sourceURL: "http://www.geniuskitchen.com/recipe/authentic-jamaican-brown-stew-chicken-347996", englishTitle: "Brown Stew Chicken", frenchTitle: "Poulet mijoté à la jamaïcaine (brown stew chicken)"),
        LegacyCatalogSignature(canonicalID: "53361", sourceURL: "https://www.myforkinglife.com/callaloo-and-saltfish/#recipe", englishTitle: "Callaloo and SaltFish", frenchTitle: "Callaloo et morue salée"),
        LegacyCatalogSignature(canonicalID: "52944", sourceURL: "https://www.africanbites.com/jamaican-escovitched-fish/", englishTitle: "Escovitch Fish", frenchTitle: "Poisson escovitch jamaïcain"),
        LegacyCatalogSignature(canonicalID: "52939", sourceURL: "https://www.africanbites.com/callaloo-jamaican-style/", englishTitle: "Callaloo Jamaican Style", frenchTitle: "Callaloo à la jamaïcaine"),
        LegacyCatalogSignature(canonicalID: "53360", sourceURL: "https://www.myforkinglife.com/tamarind-balls/#recipe", englishTitle: "Caribbean Tamarind balls", frenchTitle: "Boules de tamarin antillaises"),
        LegacyCatalogSignature(canonicalID: "53350", sourceURL: "https://www.myforkinglife.com/corned-beef-and-cabbage-jamaican-style/#recipe", englishTitle: "Corned Beef and Cabbage – Jamaican Style", frenchTitle: "Bœuf salé et chou à la jamaïcaine")
    ]

    static func existingCatalogRecipe(forID rawID: String, in context: ModelContext) -> Recipe? {
        let canonicalID = MealDBClient.canonicalRecipeID(for: rawID)
        guard !canonicalID.isEmpty else { return nil }
        guard let recipes = try? context.fetch(
            FetchDescriptor<Recipe>(predicate: #Predicate { $0.isSample == false })
        ) else {
            return nil
        }
        if let direct = recipes.first(where: {
            !$0.catalogRecipeID.isEmpty && MealDBClient.canonicalRecipeID(for: $0.catalogRecipeID) == canonicalID
        }) {
            return direct
        }
        return recipes.first {
            $0.catalogRecipeID.isEmpty && $0.isImported && inferredLegacyCatalogID(for: $0) == canonicalID
        }
    }

    @discardableResult
    static func saveDiscoveredRecipe(
        _ detail: DiscoveredRecipeDetail,
        englishDetail: DiscoveredRecipeDetail? = nil,
        ingredientIcons: [String]? = nil,
        photoData: Data? = nil,
        into context: ModelContext
    ) throws -> DiscoveredRecipeSaveResult {
        let canonicalID = MealDBClient.canonicalRecipeID(for: detail.id)
        let times = detail.timeEstimate
        let cleanedInstructions = RecipeSanitizer.cleanInstructions(detail.instructions, recipeName: detail.name)
        let resolvedIcons = (ingredientIcons?.count == detail.ingredients.count ? ingredientIcons : nil)
            ?? detail.ingredients.map { IngredientCatalog.iconID(matching: $0) ?? "" }
        let mappedCategory = RecipeCategory.inferred(fromMealDB: detail.category)
        let trimmedSource = detail.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedSource = trimmedSource.isEmpty ? detail.attribution : trimmedSource

        let shouldStoreEnglishSnapshot = AppLanguageManager.shared.activeLanguage == .french
            && LocalMealCatalog.record(id: canonicalID, language: .english) == nil
        let snapshotEN = shouldStoreEnglishSnapshot ? englishDetail : nil
        let healingEnglishDetail: DiscoveredRecipeDetail? = {
            guard LocalMealCatalog.record(id: canonicalID, language: .english) == nil else { return nil }
            if AppLanguageManager.shared.activeLanguage == .english {
                return detail
            }
            return englishDetail
        }()

        if let existing = existingCatalogRecipe(forID: canonicalID, in: context) {
            if existing.catalogRecipeID != canonicalID {
                existing.catalogRecipeID = canonicalID
            }
            if existing.isCatalogSynced {
                if existing.syncedEnglishName.isEmpty,
                   let healingEnglishDetail,
                   AppLanguageManager.shared.activeLanguage == .french
                    || CuisineTaxonomy.normalized(existing.name) != CuisineTaxonomy.normalized(healingEnglishDetail.name) {
                    existing.syncedEnglishName = healingEnglishDetail.name
                    existing.syncedEnglishIngredients = healingEnglishDetail.ingredients
                    existing.syncedEnglishInstructions = RecipeSanitizer.cleanInstructions(
                        healingEnglishDetail.instructions,
                        recipeName: healingEnglishDetail.name
                    )
                }
                if existing.prepTime == 0, times.prep > 0 { existing.prepTime = times.prep }
                if existing.cookTime == 0, times.cook > 0 { existing.cookTime = times.cook }
                if existing.source.isEmpty { existing.source = resolvedSource }
                if existing.ingredientIconIDs.isEmpty { existing.ingredientIconIDs = resolvedIcons }
            }
            if !existing.hasPhotos,
               let photoData,
               let stored = PhotoProcessing.makeStoredPhoto(from: photoData) {
                let photo = RecipePhoto(sortIndex: 0, imageData: stored.imageData, thumbnailData: stored.thumbnailData)
                photo.recipe = existing
                context.insert(photo)
            }
            existing.dateModified = Date()
            try context.save()
            return .updatedExisting
        }

        let recipe = Recipe(
            name: detail.name,
            ingredients: detail.ingredients,
            instructions: cleanedInstructions,
            notes: "",
            source: resolvedSource,
            prepTime: times.prep,
            cookTime: times.cook,
            isImported: true,
            categoryRaw: mappedCategory.rawValue,
            ingredientIconIDs: resolvedIcons,
            coverIconID: mappedCategory.preferredCoverIconID,
            catalogRecipeID: canonicalID,
            isCatalogSynced: true,
            syncedEnglishName: snapshotEN?.name ?? "",
            syncedEnglishIngredients: snapshotEN?.ingredients ?? [],
            syncedEnglishInstructions: snapshotEN.map {
                RecipeSanitizer.cleanInstructions($0.instructions, recipeName: $0.name)
            } ?? []
        )
        if let photoData, let stored = PhotoProcessing.makeStoredPhoto(from: photoData) {
            let photo = RecipePhoto(sortIndex: 0, imageData: stored.imageData, thumbnailData: stored.thumbnailData)
            photo.recipe = recipe
            context.insert(photo)
        }
        context.insert(recipe)
        try context.save()
        return .inserted
    }

    private static func deduplicateCatalogRecipesIfNeeded(from context: ModelContext, defaults: UserDefaults) throws {
        guard !defaults.bool(forKey: migratedCatalogIdentityV1Key) else { return }

        let allRecipes = try context.fetch(
            FetchDescriptor<Recipe>(predicate: #Predicate { $0.isSample == false })
        )
        var changed = false

        // 1. Normalize existing catalog IDs and backfill unambiguous legacy imported recipes.
        for recipe in allRecipes {
            if !recipe.catalogRecipeID.isEmpty {
                let normalized = MealDBClient.canonicalRecipeID(for: recipe.catalogRecipeID)
                if normalized != recipe.catalogRecipeID {
                    recipe.catalogRecipeID = normalized
                    changed = true
                }
                continue
            }

            guard recipe.isImported, let inferredID = inferredLegacyCatalogID(for: recipe) else { continue }
            recipe.catalogRecipeID = inferredID
            if matchesExpectedCatalogShape(recipe: recipe, canonicalID: inferredID) {
                recipe.isCatalogSynced = true
            }
            changed = true
        }

        // 2. Collapse true duplicate catalog saves sharing the same canonical ID.
        var groupedByCanonicalID: [String: [Recipe]] = [:]
        for recipe in allRecipes where !recipe.catalogRecipeID.isEmpty {
            groupedByCanonicalID[recipe.catalogRecipeID, default: []].append(recipe)
        }

        for (_, group) in groupedByCanonicalID where group.count > 1 {
            let sorted = group.sorted { lhs, rhs in
                if lhs.hasPhotos != rhs.hasPhotos { return lhs.hasPhotos && !rhs.hasPhotos }
                if lhs.notes.isEmpty != rhs.notes.isEmpty { return !lhs.notes.isEmpty && rhs.notes.isEmpty }
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
                if lhs.dateCreated != rhs.dateCreated { return lhs.dateCreated < rhs.dateCreated }
                return lhs.recipeID.uuidString < rhs.recipeID.uuidString
            }
            let keeper = sorted[0]
            var mergedNotes = keeper.notes.trimmingCharacters(in: .whitespacesAndNewlines)

            for duplicate in sorted.dropFirst() {
                if duplicate.isFavorite {
                    keeper.isFavorite = true
                }
                if duplicate.dateCreated < keeper.dateCreated {
                    keeper.dateCreated = duplicate.dateCreated
                }
                let dupNote = duplicate.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !dupNote.isEmpty, !mergedNotes.localizedCaseInsensitiveContains(dupNote) {
                    mergedNotes = mergedNotes.isEmpty ? dupNote : "\(mergedNotes)\n\n\(dupNote)"
                }
                if keeper.syncedEnglishName.isEmpty {
                    if !duplicate.syncedEnglishName.isEmpty {
                        keeper.syncedEnglishName = duplicate.syncedEnglishName
                        keeper.syncedEnglishIngredients = duplicate.syncedEnglishIngredients
                        keeper.syncedEnglishInstructions = duplicate.syncedEnglishInstructions
                    } else if let englishFallback = LocalMealCatalog.record(id: keeper.catalogRecipeID, language: .english) {
                        keeper.syncedEnglishName = englishFallback.name
                        keeper.syncedEnglishIngredients = englishFallback.ingredients
                        keeper.syncedEnglishInstructions = englishFallback.instructions
                    }
                }
                if !keeper.hasPhotos, let photo = duplicate.sortedPhotos.first {
                    photo.recipe = keeper
                    photo.sortIndex = 0
                }
                context.delete(duplicate)
                changed = true
            }

            if keeper.notes != mergedNotes {
                keeper.notes = mergedNotes
                changed = true
            }
        }

        if changed {
            try context.save()
        }
        defaults.set(true, forKey: migratedCatalogIdentityV1Key)
    }

    private static func inferredLegacyCatalogID(for recipe: Recipe) -> String? {
        let trimmedSource = recipe.source.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSource = trimmedSource.lowercased()
        let normalizedName = CuisineTaxonomy.normalized(recipe.name)

        if let localID = LocalMealCatalog.canonicalID(forSourceURL: trimmedSource) {
            return localID
        }

        if let mealDBID = extractMealDBIDFromURL(normalizedSource) {
            return mealDBID
        }

        for sig in legacyRemovedLocalMDBSignatures {
            if !normalizedSource.isEmpty, normalizedSource == sig.sourceURL.lowercased() {
                return sig.canonicalID
            }
            let matchesTitle = normalizedName == CuisineTaxonomy.normalized(sig.englishTitle)
                || normalizedName == CuisineTaxonomy.normalized(sig.frenchTitle)
            if matchesTitle && isCatalogAttributionSource(normalizedSource) {
                return sig.canonicalID
            }
        }

        if isCookieNotesSource(normalizedSource) {
            let matchingLocal = LocalMealCatalog.allEnglishMeals.filter {
                CuisineTaxonomy.normalized($0.name) == normalizedName
            }
            if matchingLocal.count == 1 { return matchingLocal[0].id }

            let matchingLocalFR = LocalMealCatalog.allFrenchMeals.filter {
                CuisineTaxonomy.normalized($0.name) == normalizedName
            }
            if matchingLocalFR.count == 1 { return matchingLocalFR[0].id }
        }

        if isMealDBAttributionSource(normalizedSource),
           let unambiguousID = TheMealDBCatalog.unambiguousID(matchingTitle: recipe.name) {
            return unambiguousID
        }

        return nil
    }

    private static func matchesExpectedCatalogShape(recipe: Recipe, canonicalID: String) -> Bool {
        if let localEN = LocalMealCatalog.record(id: canonicalID, language: .english),
           recipe.ingredients.count == localEN.ingredients.count {
            return true
        }
        if let mdbFR = TheMealDBCatalog.record(for: canonicalID),
           recipe.ingredients.count == mdbFR.ingredients.count {
            return true
        }
        return false
    }

    private static func extractMealDBIDFromURL(_ sourceLowercased: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"themealdb\.com/meal/(\d+)"#),
              let match = regex.firstMatch(in: sourceLowercased, range: NSRange(sourceLowercased.startIndex..., in: sourceLowercased)),
              let idRange = Range(match.range(at: 1), in: sourceLowercased) else {
            return nil
        }
        return String(sourceLowercased[idRange])
    }

    private static func isCookieNotesSource(_ normalizedSource: String) -> Bool {
        normalizedSource.contains("epicurious.com")
            || normalizedSource.contains("cookienotes kitchen")
            || normalizedSource.contains("cuisine cookienotes")
    }

    private static func isMealDBAttributionSource(_ normalizedSource: String) -> Bool {
        normalizedSource.contains("the meal database")
            || normalizedSource.contains("la base de recettes")
            || normalizedSource.contains("themealdb.com")
    }

    private static func isCatalogAttributionSource(_ normalizedSource: String) -> Bool {
        isCookieNotesSource(normalizedSource) || isMealDBAttributionSource(normalizedSource)
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
