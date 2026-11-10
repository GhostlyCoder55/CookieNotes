//
//  CookieNotesTests.swift
//  CookieNotesTests
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import CookieNotes

struct LibraryFixture: RecipeSearchable {
    var name: String
    var ingredients: [String]
    var instructions: [String]
    var notes: String
    var source: String
    var prepTime: Int
    var cookTime: Int
    var dateCreated: Date
    var dateModified: Date
    var hasPhotos: Bool
    var isSample: Bool = false
    var isFavorite: Bool = false
    var categoryRaw: String = RecipeCategory.uncategorized.rawValue
}

@Suite("Recipe library", .serialized)
struct RecipeLibraryTests {
    private let soup = LibraryFixture(
        name: "Tomato Soup",
        ingredients: ["tomatoes", "basil"],
        instructions: ["Simmer until sweet"],
        notes: "Freeze the extra",
        source: "family card",
        prepTime: 10,
        cookTime: 20,
        dateCreated: Date(timeIntervalSince1970: 200),
        dateModified: Date(timeIntervalSince1970: 200),
        hasPhotos: false,
        categoryRaw: RecipeCategory.lunch.rawValue
    )
    private let cake = LibraryFixture(
        name: "Banana Cake",
        ingredients: ["bananas", "flour"],
        instructions: ["Bake"],
        notes: "",
        source: "",
        prepTime: 15,
        cookTime: 40,
        dateCreated: Date(timeIntervalSince1970: 100),
        dateModified: Date(timeIntervalSince1970: 100),
        hasPhotos: true,
        categoryRaw: RecipeCategory.dessert.rawValue
    )

    @Test func searchMatchesNotesInstructionsAndIngredients() {
        let recipes = [soup, cake]
        #expect(RecipeLibrary.prepare(recipes, query: "freeze").map(\.name) == ["Tomato Soup"])
        #expect(RecipeLibrary.prepare(recipes, query: "SIMMER").map(\.name) == ["Tomato Soup"])
        #expect(RecipeLibrary.prepare(recipes, query: "flour").map(\.name) == ["Banana Cake"])
        #expect(RecipeLibrary.prepare(recipes, query: "missing").isEmpty)
    }

    @Test func filterAndSort() {
        let recipes = [soup, cake]
        #expect(RecipeLibrary.prepare(recipes, filter: .lunch).map(\.name) == ["Tomato Soup"])
        #expect(RecipeLibrary.prepare(recipes, filter: .dessert).map(\.name) == ["Banana Cake"])
        #expect(RecipeLibrary.prepare(recipes, filter: .breakfast).isEmpty)
        #expect(RecipeLibrary.prepare(recipes, filter: .all).map(\.name).count == 2)
        #expect(RecipeLibrary.prepare(recipes, sort: .name).map(\.name) == ["Banana Cake", "Tomato Soup"])
        #expect(RecipeLibrary.prepare(recipes, sort: .newest).map(\.name) == ["Tomato Soup", "Banana Cake"])
    }

    @Test func sideIsNoLongerARecipeCategoryOrFilter() {
        #expect(!RecipeCategory.allCases.contains { $0.rawValue == "sides" })
        #expect(!RecipeFilter.allCases.contains { $0.rawValue == "sides" })
        #expect(RecipeCategory.inferred(fromMealDB: "Side") == .uncategorized)
        #expect(RecipeCategory.inferred(fromMealDB: "Starter") == .uncategorized)
        #expect(LocalMealCatalog.shared.allSatisfy {
            !["side", "sides"].contains($0.category.lowercased())
        })
        #expect(LibraryFixture(
            name: "Legacy side",
            ingredients: [],
            instructions: [],
            notes: "",
            source: "",
            prepTime: 0,
            cookTime: 0,
            dateCreated: .distantPast,
            dateModified: .distantPast,
            hasPhotos: false,
            categoryRaw: "sides"
        ).category == .uncategorized)
    }

    @Test func snackIsNoLongerARecipeCategoryOrFilter() {
        #expect(!RecipeCategory.allCases.contains { $0.rawValue == "snack" })
        #expect(!RecipeCategory.allCases.contains { $0.rawValue == "snacks" })
        #expect(!RecipeFilter.allCases.contains { $0.rawValue == "snack" })
        #expect(RecipeCategory.inferred(fromMealDB: "Snack") == .uncategorized)
        #expect(RecipeCategory.inferred(fromMealDB: "Snacks") == .uncategorized)
        #expect(LocalMealCatalog.shared.allSatisfy {
            !["snack", "snacks"].contains($0.category.lowercased())
        })
        #expect(LibraryFixture(
            name: "Legacy snack",
            ingredients: [],
            instructions: [],
            notes: "",
            source: "",
            prepTime: 0,
            cookTime: 0,
            dateCreated: .distantPast,
            dateModified: .distantPast,
            hasPhotos: false,
            categoryRaw: "snack"
        ).category == .uncategorized)
    }

    @Test func hidesSampleRecipesFromLibrary() {
        var sample = soup
        sample.isSample = true
        #expect(RecipeLibrary.prepare([sample, cake], filter: .all).map(\.name) == ["Banana Cake"])
    }
}

@Suite("Shared recipes")
struct SharedRecipeTests {
    @Test func parsesHeadingsAndListMarkers() {
        let parsed = RecipeTextParser.parse(
            """
            Sunday Stew

            Ingredients
            - beef
            • carrots

            Directions
            1. Brown the beef
            2) Add the carrots

            Notes
            Better the next day
            """
        )
        #expect(parsed.name == "Sunday Stew")
        #expect(parsed.ingredients == ["beef", "carrots"])
        #expect(parsed.instructions == ["Brown the beef", "Add the carrots"])
        #expect(parsed.notes == "Better the next day")
        #expect(parsed.hasStructuredContent)
    }

    @Test func builderUsesThePageHostAndRejectsUnsafeLinks() {
        let suite = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("en", forKey: "cookienotes.appLanguage")

        let draft = SharedRecipeBuilder.draft(from: SharedRecipePayload(
            title: "",
            url: "https://example.com/stew",
            text: "https://example.com/stew",
            imageData: nil,
            receivedAt: Date(timeIntervalSince1970: 1)
        ), defaults: defaults)
        #expect(draft.name == "example.com")
        #expect(draft.source == "https://example.com/stew")
        #expect(draft.notes.contains("Saved from the web"))

        let unsafe = SharedRecipeBuilder.draft(from: SharedRecipePayload(
            title: "Card",
            url: "javascript:alert(1)",
            text: "",
            imageData: nil,
            receivedAt: Date(timeIntervalSince1970: 1)
        ), defaults: defaults)
        #expect(unsafe.source.isEmpty)
        #expect(unsafe.name == "Card")
    }

    @Test func sanitizerLimitsText() {
        let cleaned = RecipeSanitizer.clean(
            RecipeDraft(
                name: String(repeating: "a", count: 300),
                ingredients: ["  salt  ", ""],
                instructions: ["\nBake\n"],
                notes: "  note  ",
                source: "Grandma"
            )
        )
        #expect(cleaned.name.count == RecipeInputLimits.name)
        #expect(cleaned.ingredients == ["salt"])
        #expect(cleaned.instructions == ["Bake"])
        #expect(cleaned.notes == "note")
        #expect(cleaned.source == "Grandma")
        #expect(RecipeSanitizer.minutes(-4) == 0)
        #expect(RecipeSanitizer.minutes(10_000) == RecipeInputLimits.maxMinutes)
    }

    @Test func instructionFormattingRemovesDuplicateMarkersAndHeadings() {
        let cleaned = RecipeSanitizer.cleanInstructions([
            "STEP 1",
            "0. Marinate the beef.",
            "1. Heat the pan.",
            "1 Put the fennel and aubergine in a roasting tray.",
            "STEP 2: Add broth.",
            "ÉTAPE 3",
            "Étape 4 : Incorporer la sauce.",
            "Préparation :",
            "1",
            "2",
            "3",
            "4.",
            "Steps:",
            "□",
            "☐ Serve with sauce.",
            "◻",
            "7) Let rest before serving."
        ])

        #expect(cleaned == [
            "Marinate the beef.",
            "Heat the pan.",
            "Put the fennel and aubergine in a roasting tray.",
            "Add broth.",
            "Incorporer la sauce.",
            "Serve with sauce.",
            "Let rest before serving."
        ])
    }

    @Test func karbonaderPlaceholderRowsAreReplacedWithMissingDirections() {
        let name = "Karbonader (Lean Beef Patties) with Caramelized Onions"
        let instructions = [
            "Grate half an onion and set aside. Slice the rest of the onions and fry in butter on low/medium heat until caramelized.",
            "☐",
            "In a bowl, mix together ground beef, grated onion, salt, pepper, nutmeg, potato/corn starch, and water.",
            "□",
            "Form into a sausage and cut 6 patties. Using a knife make a light grid pattern in each patty.",
            "☐",
            "Brown both sides of the karbonader in butter on high heat, then turn down to low heat and fry for another 2-3 minutes.",
            "☐",
            "Serve the karbonader and onions with potatoes, stewed peas, and brown sauce for dinner."
        ]

        let cleaned = RecipeSanitizer.cleanInstructions(instructions, recipeName: name)
        #expect(cleaned.count == 9)
        #expect(cleaned[1].contains("Transfer the caramelized onions"))
        #expect(cleaned[3].contains("Mix gently"))
        #expect(cleaned[5].contains("even thickness"))
        #expect(cleaned[7].contains("160°F"))
        #expect(RecipeSanitizer.cleanInstructions(cleaned, recipeName: name) == cleaned)
    }

    @Test func bundledDiscoveryRecipesHaveNoNumberedInstructionPrefixes() {
        for meal in LocalMealCatalog.shared {
            let cleaned = RecipeSanitizer.cleanInstructions(meal.instructions)
            #expect(cleaned == meal.instructions)
        }
    }

    @Test func cuisineAliasesResolveCountryAndDemonymVariations() {
        #expect(LocalMealCatalog.resolvedArea(for: "Japan") == "Japanese")
        #expect(LocalMealCatalog.resolvedArea(for: "Japanese") == "Japanese")
        #expect(LocalMealCatalog.resolvedArea(for: "Vietnam") == "Vietnamese")
        #expect(LocalMealCatalog.resolvedArea(for: "Vietnamese") == "Vietnamese")
        #expect(LocalMealCatalog.resolvedArea(for: "Yemen") == "Yemeni")
        #expect(LocalMealCatalog.resolvedArea(for: "Yemeni") == "Yemeni")
    }

    @Test func localSearchScansRecipeTextAndCuisineMetadata() throws {
        let jollof = try #require(LocalMealCatalog.shared.first { $0.id == "local-jollof-rice" })
        #expect(jollof.matches(search: "rice"))
        #expect(jollof.matches(search: "Nigeria"))
        #expect(jollof.matches(search: "African"))
        #expect(!jollof.matches(search: "Japanese"))
    }

    @Test func everyBundledCuisineOriginHasOneGeographicRegion() throws {
        for area in Set(LocalMealCatalog.shared.map(\.area)) {
            #expect(CuisineTaxonomy.region(forArea: area) != nil)
        }
        #expect(CuisineTaxonomy.region(forArea: "Japanese", country: "Japan") == .asian)
        #expect(CuisineTaxonomy.region(forArea: "Yemeni", country: "Yemen") == .middleEastern)
        #expect(LocalMealCatalog.filter(region: .african).contains { $0.area == "Nigerian" })
        #expect(CuisineTaxonomy.regions == [
            .african, .asian, .caribbean, .european, .middleEastern, .northAmerican, .oceania, .southAmerican
        ])

        let french = try #require(LocalMealCatalog.shared.first { $0.area == "French" })
        let frenchDetail = try #require(LocalMealCatalog.detail(id: french.id))
        #expect(frenchDetail.tags.contains("European"))
        #expect(!frenchDetail.tags.contains("African"))
    }

    @Test func regionalRecipesAreAlphabeticalByMealName() {
        let recipes = [
            DiscoveredRecipeSummary(id: "3", name: "Jollof Rice", thumbnailURL: nil, category: nil, area: nil),
            DiscoveredRecipeSummary(id: "1", name: "Apple Pie", thumbnailURL: nil, category: nil, area: nil),
            DiscoveredRecipeSummary(id: "2", name: "Beef Stew", thumbnailURL: nil, category: nil, area: nil)
        ]
        #expect(MealDBClient.alphabeticallySorted(recipes).map(\.name) == [
            "Apple Pie", "Beef Stew", "Jollof Rice"
        ])
    }

    @Test func inboxRoundTripUsesTheProvidedFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let payload = SharedRecipePayload(
            title: "Stew",
            url: "https://example.com",
            text: "Simmer",
            imageData: nil,
            receivedAt: Date(timeIntervalSince1970: 20)
        )
        try PendingImportStore.enqueue(payload, inbox: folder)
        let drained = try PendingImportStore.drain(inbox: folder)
        #expect(drained == [payload])
        #expect(try PendingImportStore.drain(inbox: folder).isEmpty)
    }
}

@Suite("Advertising policy")
struct AdvertisingPolicyTests {
    @Test func debugUsesSampleAdsUnlessProductionIsForced() {
        let debug = AdConfiguration.resolve(
            isDebugBuild: true,
            forceProductionAds: false,
            applicationID: "ca-app-pub-1234567890123456~1234567890",
            bannerAdUnitID: "ca-app-pub-1234567890123456/1234567890",
            privacyPolicyURLString: "https://example.com/privacy",
            cloudKitFlag: "NO"
        )
        #expect(debug.mode == .test)
        #expect(debug.bannerAdUnitID == AdConfiguration.googleTestBannerID)
        #expect(debug.privacyPolicyURL?.host() == "example.com")
    }

    @Test func releaseRejectsBlankSampleAndMismatchedIDs() {
        let blank = AdConfiguration.resolve(
            isDebugBuild: false,
            forceProductionAds: false,
            applicationID: "",
            bannerAdUnitID: "",
            privacyPolicyURLString: "",
            cloudKitFlag: "YES"
        )
        #expect(blank.mode == .disabled)
        #expect(blank.bannerAdUnitID.isEmpty)
        #expect(blank.applicationID == AdConfiguration.googleTestApplicationID)
        #expect(blank.cloudKitEnabled)
        #expect(blank.privacyPolicyURL == nil)

        let sample = AdConfiguration.resolve(
            isDebugBuild: false,
            forceProductionAds: true,
            applicationID: AdConfiguration.googleTestApplicationID,
            bannerAdUnitID: AdConfiguration.googleTestBannerID,
            privacyPolicyURLString: "javascript:alert(1)",
            cloudKitFlag: "NO"
        )
        #expect(sample.mode == .disabled)

        let mismatched = AdConfiguration.resolve(
            isDebugBuild: false,
            forceProductionAds: false,
            applicationID: "ca-app-pub-1234567890123456~1234567890",
            bannerAdUnitID: "ca-app-pub-9999999999999999/1234567890",
            privacyPolicyURLString: "",
            cloudKitFlag: "NO"
        )
        #expect(mismatched.mode == .disabled)
    }

    @Test func releaseAcceptsAMatchingPublisherPair() {
        let settings = AdConfiguration.resolve(
            isDebugBuild: false,
            forceProductionAds: false,
            applicationID: "ca-app-pub-1234567890123456~1234567890",
            bannerAdUnitID: "ca-app-pub-1234567890123456/0987654321",
            privacyPolicyURLString: "https://example.com/privacy",
            cloudKitFlag: "NO"
        )
        #expect(settings.mode == .production)
        #expect(settings.applicationID.hasPrefix("ca-app-pub-1234567890123456"))
    }

    @Test func privacyPolicyURLRequiresHTTPS() {
        let httpOnly = AdConfiguration.resolve(
            isDebugBuild: false,
            forceProductionAds: false,
            applicationID: "ca-app-pub-1234567890123456~1234567890",
            bannerAdUnitID: "ca-app-pub-1234567890123456/0987654321",
            privacyPolicyURLString: "http://example.com/privacy",
            cloudKitFlag: "NO"
        )
        #expect(httpOnly.privacyPolicyURL == nil)

        let https = AdConfiguration.resolve(
            isDebugBuild: false,
            forceProductionAds: false,
            applicationID: "ca-app-pub-1234567890123456~1234567890",
            bannerAdUnitID: "ca-app-pub-1234567890123456/0987654321",
            privacyPolicyURLString: "https://example.com/privacy",
            cloudKitFlag: "NO"
        )
        #expect(https.privacyPolicyURL?.scheme == "https")
    }

    @Test func browsingAndSearchKeepAdsAwayFromEmptyResults() {
        #expect(AdPlacement.browsingSlots(itemCount: 0, adsEnabled: true).isEmpty)
        #expect(AdPlacement.searchSlots(itemCount: 0, adsEnabled: true).isEmpty)

        let shortList = AdPlacement.browsingSlots(itemCount: 3, adsEnabled: true)
        #expect(shortList.filter { if case .advertisement = $0 { return true }; return false }.count == 1)
        #expect(shortList.last == .advertisement(0))

        let longList = AdPlacement.browsingSlots(itemCount: 13, adsEnabled: true)
        let ads = longList.filter { if case .advertisement = $0 { return true }; return false }
        #expect(ads.count == 2)

        let search = AdPlacement.searchSlots(itemCount: 2, adsEnabled: true)
        #expect(search == [.item(0), .item(1), .advertisement(0)])
        #expect(!AdPlacement.showsContentBanner(adsEnabled: true, hasContent: false))
    }

    @Test func consentDefaultsToNoAds() {
        #expect(AdConsentChoice.unknown.allowsAds == false)
        #expect(AdConsentChoice.declined.allowsAds == false)
        #expect(AdConsentChoice.allowed.allowsAds)

        let suite = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        #expect(AdConsentStore.choice(defaults: defaults) == .allowed)
        AdConsentStore.set(.declined, defaults: defaults)
        #expect(AdConsentStore.choice(defaults: defaults) == .declined)
        AdConsentStore.set(.allowed, defaults: defaults)
        #expect(AdConsentStore.choice(defaults: defaults) == .allowed)

        defaults.set("personalized", forKey: AdConsentStore.key)
        #expect(AdConsentStore.choice(defaults: defaults) == .allowed)
        defaults.set("nonPersonalized", forKey: AdConsentStore.key)
        #expect(AdConsentStore.choice(defaults: defaults) == .allowed)
    }

    @Test func welcomePromptWaitsSevenDays() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(NotificationManager.shouldPrompt(lastLogin: nil, now: now, interval: NotificationManager.promptInterval) == false)
        #expect(NotificationManager.shouldPrompt(lastLogin: now.addingTimeInterval(-6 * 24 * 60 * 60), now: now, interval: NotificationManager.promptInterval) == false)
        #expect(NotificationManager.shouldPrompt(lastLogin: now.addingTimeInterval(-8 * 24 * 60 * 60), now: now, interval: NotificationManager.promptInterval))
    }
}

@Suite("Storage", .serialized)
@MainActor
struct StorageTests {
    @Test func compressesPhotosBeforeStorage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }
        let data = try #require(image.jpegData(compressionQuality: 0.95))
        let stored = try #require(PhotoProcessing.makeStoredPhoto(from: data))
        let thumbnail = try #require(UIImage(data: stored.thumbnailData))
        let full = try #require(UIImage(data: stored.imageData))
        #expect(max(thumbnail.size.width, thumbnail.size.height) <= PhotoProcessing.thumbnailMaxPixel)
        #expect(max(full.size.width, full.size.height) <= PhotoProcessing.fullMaxPixel)
        #expect(PhotoProcessing.makeStoredPhoto(from: Data()) == nil)
    }

    @Test func migratesTheOldUserDefaultsLibraryOnce() throws {
        let defaults = makeDefaults()
        let recipeID = UUID()
        let photo = try sampleJPEG()
        let payload = try JSONEncoder().encode([
            LegacyFixture(
                id: recipeID,
                name: "  Old Chili  ",
                ingredients: ["beans"],
                instructions: ["Simmer"],
                prepTime: 5,
                cookTime: 40,
                photos: [photo],
                dateCreated: Date(timeIntervalSince1970: 50),
                dateModified: Date(timeIntervalSince1970: 60)
            )
        ])
        defaults.set(payload, forKey: PersistenceController.legacyRecipesKey)

        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try PersistenceController.prepareLibrary(context: context, defaults: defaults, seedSamples: true)

        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(recipes.count == 1)
        #expect(recipes[0].recipeID == recipeID)
        #expect(recipes[0].name == "Old Chili")
        #expect(recipes[0].hasPhotos)
        #expect(defaults.data(forKey: PersistenceController.legacyRecipesKey) == nil)
        #expect(defaults.bool(forKey: PersistenceController.initialSetupKey))

        try PersistenceController.prepareLibrary(context: context, defaults: defaults, seedSamples: true)
        #expect(try context.fetch(FetchDescriptor<Recipe>()).count == 1)
    }

    @Test func startsWithEmptyLibraryOnFirstLaunch() throws {
        let defaults = makeDefaults()
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try PersistenceController.prepareLibrary(context: context, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<Recipe>()).isEmpty)
        #expect(defaults.bool(forKey: PersistenceController.initialSetupKey))

        try PersistenceController.prepareLibrary(context: context, defaults: makeDefaults(), seedSamples: true)
        let samples = try context.fetch(
            FetchDescriptor<Recipe>(predicate: #Predicate { $0.isSample == true })
        )
        #expect(samples.count == 1)
        #expect(samples[0].name == "Weeknight Fried Rice" || samples[0].name == "Riz frit de semaine")
    }

    @Test func removesPreviouslySeededExamples() throws {
        let defaults = makeDefaults()
        defaults.set(true, forKey: PersistenceController.initialSetupKey)
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        RecipeMigration.insertSample(into: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Recipe>()).count == 1)

        try PersistenceController.prepareLibrary(context: context, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<Recipe>()).isEmpty)
    }

    @Test func purgesLegacyDemoRecipesIncludingCambodianWaffles() throws {
        let defaults = makeDefaults()
        defaults.set(true, forKey: PersistenceController.initialSetupKey)
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(Recipe(name: "Chocolate Chip Cookies", ingredients: ["flour"], instructions: ["Bake"]))
        context.insert(RecipeMigration.showcaseFriedRice(isSample: false))
        context.insert(Recipe(name: "Cambodian Waffles (Num Poum)", ingredients: ["rice flour"], instructions: ["Cook"]))
        context.insert(Recipe(name: "Keep Me", ingredients: ["salt"], instructions: ["Season"]))
        try context.save()

        try PersistenceController.prepareLibrary(context: context, defaults: defaults)
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(recipes.count == 1)
        #expect(recipes[0].name == "Keep Me")
    }

    @Test func corruptLegacyDataIsKept() throws {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: PersistenceController.legacyRecipesKey)
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        #expect(throws: RecipeMigrationError.self) {
            try PersistenceController.prepareLibrary(context: context, defaults: defaults)
        }
        #expect(defaults.data(forKey: PersistenceController.legacyRecipesKey) != nil)
        #expect(defaults.bool(forKey: PersistenceController.initialSetupKey) == false)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func sampleJPEG() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10))
        let image = renderer.image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        }
        return try #require(image.jpegData(compressionQuality: 0.8))
    }
}

private struct LegacyFixture: Encodable {
    var id: UUID
    var name: String
    var ingredients: [String]
    var instructions: [String]
    var prepTime: Int
    var cookTime: Int
    var photos: [Data]
    var dateCreated: Date
    var dateModified: Date
}

@Suite("Localization and French Translation", .serialized)
struct LocalizationTests {
    @Test func languageSelectionAndPersistence() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage

        await manager.setLanguage(.french)
        #expect(manager.activeLanguage == .french)
        #expect(manager.currentLanguage == .french)

        await manager.setLanguage(.english)
        #expect(manager.activeLanguage == .english)
        #expect(manager.currentLanguage == .english)

        // Restore original
        await manager.setLanguage(original)
    }

    @Test func ingredientIconMatchingInBothLanguages() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage

        // In French:
        await manager.setLanguage(.french)
        #expect(IngredientCatalog.iconID(matching: "pomme") == "apple")
        #expect(IngredientCatalog.iconID(matching: "oignon") == "onion")
        #expect(IngredientCatalog.iconID(matching: "ail") == "garlic")
        #expect(IngredientCatalog.iconID(matching: "carotte") == "carrot")
        #expect(IngredientCatalog.iconID(matching: "poulet") == "whole_raw_chicken")

        // Accent tolerance in French:
        #expect(IngredientCatalog.iconID(matching: "échalote") == "shallot")
        #expect(IngredientCatalog.iconID(matching: "echalote") == "shallot")

        // In English:
        await manager.setLanguage(.english)
        #expect(IngredientCatalog.iconID(matching: "apple") == "apple")
        #expect(IngredientCatalog.iconID(matching: "onion") == "onion")
        #expect(IngredientCatalog.iconID(matching: "garlic") == "garlic")
        #expect(IngredientCatalog.iconID(matching: "carrot") == "carrot")
        #expect(IngredientCatalog.iconID(matching: "chicken") == "whole_raw_chicken")

        // Exact 1-to-1 equivalence between translated ingredients and original icons:
        #expect(IngredientCatalog.iconID(matching: "apple") == IngredientCatalog.iconID(matching: "pomme"))
        #expect(IngredientCatalog.iconID(matching: "onion") == IngredientCatalog.iconID(matching: "oignon"))
        #expect(IngredientCatalog.iconID(matching: "garlic") == IngredientCatalog.iconID(matching: "ail"))
        #expect(IngredientCatalog.iconID(matching: "chicken") == IngredientCatalog.iconID(matching: "poulet"))
        #expect(IngredientCatalog.iconID(matching: "carrot") == IngredientCatalog.iconID(matching: "carotte"))

        await manager.setLanguage(original)
    }

    @Test func ingredientDisplayNamesInBothLanguages() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage

        await manager.setLanguage(.french)
        #expect(IngredientCatalog.displayName(for: "apple") == "Pomme")
        #expect(IngredientCatalog.displayName(for: "garlic") == "Ail")
        #expect(IngredientCatalog.displayName(for: "onion") == "Oignon")
        #expect(IngredientCatalog.displayName(for: "carrot") == "Carotte")

        await manager.setLanguage(.english)
        #expect(IngredientCatalog.displayName(for: "apple") == "Apple")
        #expect(IngredientCatalog.displayName(for: "garlic") == "Garlic")
        #expect(IngredientCatalog.displayName(for: "onion") == "Onion")
        #expect(IngredientCatalog.displayName(for: "carrot") == "Carrot")

        await manager.setLanguage(original)
    }

    @Test func recipeCategoriesLocalization() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage

        await manager.setLanguage(.french)
        #expect(RecipeCategory.dinner.title == "Souper")
        #expect(RecipeCategory.breakfast.title == "Déjeuner")
        #expect(RecipeCategory.lunch.title == "Dîner")
        #expect(RecipeCategory.dessert.title == "Dessert")
        #expect(RecipeCategory.drinks.title == "Boissons")
        #expect(RecipeCategory.uncategorized.title == "Général")
        #expect(String.localized("Algerian") == "Algérienne")

        await manager.setLanguage(.english)
        #expect(RecipeCategory.dinner.title == "Dinner")
        #expect(RecipeCategory.breakfast.title == "Breakfast")
        #expect(RecipeCategory.lunch.title == "Lunch")
        #expect(RecipeCategory.dessert.title == "Dessert")
        #expect(RecipeCategory.drinks.title == "Drinks")
        #expect(RecipeCategory.uncategorized.title == "General")

        await manager.setLanguage(original)
    }

    @Test func recipeTimeFormattingInBothLanguages() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage

        await manager.setLanguage(.french)
        #expect(RecipeTimeFormat.short(45) == "45 min")
        #expect(RecipeTimeFormat.short(60) == "1 h")
        #expect(RecipeTimeFormat.short(75) == "1 h 15 min")

        await manager.setLanguage(.english)
        #expect(RecipeTimeFormat.short(45) == "45 min")
        #expect(RecipeTimeFormat.short(60) == "1 hr")
        #expect(RecipeTimeFormat.short(75) == "1 hr 15 min")

        await manager.setLanguage(original)
    }

    @Test func localMealCatalogProvidesLocalizedMeals() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage

        await manager.setLanguage(.french)
        let frMeals = LocalMealCatalog.shared
        #expect(frMeals.count == 59)
        if let jollof = frMeals.first(where: { $0.id == "local-west-african-jollof-rice" }) {
            #expect(jollof.name == "Riz jollof ouest-africain")
            #expect(jollof.ingredients.contains { $0.contains("riz") })
        }

        await manager.setLanguage(.english)
        let enMeals = LocalMealCatalog.shared
        #expect(enMeals.count == 59)
        if let jollof = enMeals.first(where: { $0.id == "local-west-african-jollof-rice" }) {
            #expect(jollof.name == "West African Jollof Rice")
            #expect(jollof.ingredients.contains { $0.contains("rice") })
        }

        await manager.setLanguage(original)
    }

    @Test func cuisineTaxonomyFrenchAliases() {
        #expect(CuisineTaxonomy.canonicalArea(for: "mexicain") == "Mexican")
        #expect(CuisineTaxonomy.canonicalArea(for: "francais") == "French")
        #expect(CuisineTaxonomy.canonicalArea(for: "française") == "French")
        #expect(CuisineTaxonomy.canonicalArea(for: "canadien") == "Canadian")
        #expect(CuisineTaxonomy.canonicalArea(for: "japonais") == "Japanese")
        #expect(CuisineTaxonomy.canonicalArea(for: "italien") == "Italian")
    }

    @MainActor
    @Test func showcaseSampleRecipeLocalization() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage

        manager.setLanguage(.french)
        let frFriedRice = RecipeMigration.showcaseFriedRice()
        #expect(frFriedRice.name == "Riz frit de semaine")
        #expect(frFriedRice.ingredients.first?.contains("tasses") == true)
        #expect(frFriedRice.ingredientIconIDs == [
            "fried_rice_bowl", "eggs", "peas", "onion", "garlic",
            "ginger", "lettuce", "soy_sauce", "olive_oil", "vegetable_oil", "shrimp"
        ])

        manager.setLanguage(.english)
        let enFriedRice = RecipeMigration.showcaseFriedRice()
        #expect(enFriedRice.name == "Weeknight Fried Rice")
        #expect(enFriedRice.ingredients.first?.contains("cups") == true)

        manager.setLanguage(original)
    }

    @Test func recipeTranslatorIngredientsAndIcons() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage
        await manager.setLanguage(.french)

        let thymeTrans = RecipeTranslator.translateIngredient("1/2 teaspoon Thyme")
        #expect(thymeTrans.contains("c. à thé"))
        #expect(thymeTrans.contains("thym"))
        #expect(IngredientCatalog.iconID(matching: thymeTrans) == "thyme")

        let bayTrans = RecipeTranslator.translateIngredient("1 Bay Leaf")
        #expect(bayTrans.contains("feuille de laurier") || bayTrans.contains("laurier"))
        #expect(IngredientCatalog.iconID(matching: bayTrans) == "dried_bay_leaves")

        let lemonTrans = RecipeTranslator.translateIngredient("1 tsp Lemon Juice")
        #expect(lemonTrans.contains("c. à thé"))
        #expect(lemonTrans.contains("jus de citron"))
        #expect(IngredientCatalog.iconID(matching: lemonTrans) == "lemon")

        let waterTrans = RecipeTranslator.translateIngredient("1 1/2 cup Water")
        #expect(waterTrans.contains("tasse"))
        #expect(waterTrans.contains("d'eau") || waterTrans.contains("eau"))

        let oilTrans = RecipeTranslator.translateIngredient("5 tablespoons Olive Oil")
        #expect(oilTrans.contains("c. à soupe"))
        #expect(oilTrans.contains("huile d'olive"))
        #expect(IngredientCatalog.iconID(matching: oilTrans) == "olive_oil")

        let garlicTrans = RecipeTranslator.translateIngredient("3 Cloves Crushed Garlic")
        #expect(garlicTrans.contains("gousse"))
        #expect(garlicTrans.contains("ail"))
        #expect(IngredientCatalog.iconID(matching: garlicTrans) == "garlic")

        await manager.setLanguage(original)
    }

    @Test func theMealDBCatalogTranslation() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage
        await manager.setLanguage(.french)

        if let record = TheMealDBCatalog.record(for: "53282") {
            #expect(record.name == "Carottes algériennes")
            #expect(record.ingredients.contains { $0.contains("thym") })
            #expect(record.ingredients.contains { $0.contains("feuille de laurier") })
            #expect(record.ingredients.contains { $0.contains("jus de citron") })
            #expect(record.instructions.first?.contains("vapeur") == true)
        }

        // Verify MealDBClient.lookup returns translated French detail
        do {
            let detail = try await MealDBClient.shared.lookup(id: "53282")
            #expect(detail.name == "Carottes algériennes")
            #expect(detail.ingredients.contains { $0.contains("thym") })
            #expect(detail.ingredients.contains { $0.contains("feuille de laurier") })
            #expect(detail.ingredients.contains { $0.contains("jus de citron") })
            #expect(detail.instructions.first?.contains("vapeur") == true)

            // Test ingredient icon resolution for all ingredients in Algerian Carrots
            let icons = detail.ingredients.map { IngredientCatalog.iconID(matching: $0) ?? "" }
            #expect(icons.contains("thyme"))
            #expect(icons.contains("dried_bay_leaves"))
            #expect(icons.contains("lemon"))
            #expect(icons.contains("carrot"))
            #expect(icons.contains("olive_oil"))
            #expect(icons.contains("salt_bowl"))
            #expect(icons.contains("garlic"))
        } catch {
            Issue.record("MealDBClient lookup failed: \(error)")
        }

        await manager.setLanguage(original)
    }

    @Test func bouzgeneRecipeIsExcludedFromApp() async {
        #expect(MealDBClient.isExcluded(id: "53284", name: nil))
        #expect(MealDBClient.isExcluded(id: nil, name: "Pain berbère algérien bouzgène avec sauce aux poivrons rôtis"))
        #expect(MealDBClient.isExcluded(id: nil, name: "Algerian Bouzgene Berber Bread with Roasted Pepper Sauce"))
        #expect(TheMealDBCatalog.record(for: "53284") == nil)
        await #expect(throws: Error.self) {
            try await MealDBClient.shared.lookup(id: "53284")
        }
    }

    @Test func frenchTimeEstimatorHandlesFrenchDurations() {
        let estimate = RecipeTimeEstimator.estimate(
            instructions: [
                "Laisser mariner toute la nuit au réfrigérateur.",
                "Faire cuire au four pendant 1 heure et 15 minutes jusqu'à coloration dorée."
            ],
            ingredientCount: 6,
            category: "Beef"
        )
        #expect(estimate.prep >= 8 * 60)
        #expect(estimate.cook >= 75)

        let simple = RecipeTimeEstimator.estimate(
            instructions: ["Faire mijoter 20 minutes à feu doux."],
            ingredientCount: 4,
            category: "Soup"
        )
        #expect(simple.cook == 20)
    }

    @Test func allBundledFrenchCatalogRecordsAreValidAndClean() throws {
        let url = try #require(
            Bundle.main.url(forResource: "TheMealDB_fr", withExtension: "json")
                ?? Bundle.main.url(forResource: "TheMealDB_fr", withExtension: "json", subdirectory: "Resources")
        )
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([String: TheMealDBRecord].self, from: data)
        #expect(records.count == 790)
        #expect(records["53284"] == nil)

        for (id, record) in records {
            #expect(!MealDBClient.isExcluded(id: id, name: record.name))
            #expect(!record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!record.ingredients.isEmpty)
            #expect(!record.instructions.isEmpty)
            #expect(record.thumbnailURL?.isEmpty == false)
            for ingredient in record.ingredients {
                #expect(!ingredient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            for step in record.instructions {
                #expect(!step.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(!step.contains("\u{200B}"))
                #expect(step != "□" && step != "☐" && step != "◻")
            }
        }
    }

    @Test func frenchCatalogSearchFindsMatchingDishesWithThumbnails() async {
        let manager = AppLanguageManager.shared
        let original = manager.activeLanguage
        await manager.setLanguage(.french)

        let chickenResults = TheMealDBCatalog.search(query: "poulet")
        #expect(!chickenResults.isEmpty)
        #expect(chickenResults.allSatisfy { $0.id != "53284" })
        #expect(chickenResults.allSatisfy { $0.thumbnailURL != nil })

        let carrotResults = TheMealDBCatalog.search(query: "carottes algériennes")
        #expect(carrotResults.contains { $0.id == "53282" && $0.name == "Carottes algériennes" && $0.thumbnailURL != nil })

        await manager.setLanguage(original)
    }

    @Test func frenchSharedTextAndBuilderLocalization() {
        let parsed = RecipeTextParser.parse(
            """
            Soupe du dimanche

            Ingrédients :
            - 2 carottes
            • 1 oignon

            Préparation :
            1. Couper les légumes.
            2) Faire mijoter 20 minutes.

            Astuces :
            Encore meilleur le lendemain.
            """
        )
        #expect(parsed.name == "Soupe du dimanche")
        #expect(parsed.ingredients == ["2 carottes", "1 oignon"])
        #expect(parsed.instructions == ["Couper les légumes.", "Faire mijoter 20 minutes."])
        #expect(parsed.notes == "Encore meilleur le lendemain.")
        #expect(parsed.hasStructuredContent)

        let suite = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("fr", forKey: "cookienotes.appLanguage")

        let draft = SharedRecipeBuilder.draft(from: SharedRecipePayload(
            title: "",
            url: "https://example.com/soupe",
            text: "",
            imageData: nil,
            receivedAt: Date(timeIntervalSince1970: 1)
        ), defaults: defaults)
        #expect(draft.name == "example.com")
        #expect(draft.notes.contains("Enregistrée depuis le Web"))

        let untitledDraft = SharedRecipeBuilder.draft(from: SharedRecipePayload(
            title: "",
            url: "",
            text: "",
            imageData: nil,
            receivedAt: Date(timeIntervalSince1970: 1)
        ), defaults: defaults)
        #expect(untitledDraft.name == "Recette enregistrée")
    }

    @MainActor
    @Test func persistencePurgesBouzgeneAndMigratesSnackRecipes() throws {
        let suite = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: PersistenceController.initialSetupKey)
        defaults.set("snack", forKey: "cookienotes.recipeFilter")

        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(Recipe(name: "Algerian Bouzgene Berber Bread", categoryRaw: "sides"))
        context.insert(Recipe(name: "Grandma Granola", categoryRaw: "snack"))
        try context.save()

        try PersistenceController.prepareLibrary(context: context, defaults: defaults)
        let remaining = try context.fetch(FetchDescriptor<Recipe>())
        #expect(remaining.count == 1)
        #expect(remaining[0].name == "Grandma Granola")
        #expect(remaining[0].category == .uncategorized)
        #expect(defaults.string(forKey: "cookienotes.recipeFilter") == RecipeFilter.all.rawValue)
    }
}

// MARK: - App Update Checker Tests

final class MockUpdateURLProtocol: URLProtocol, @unchecked Sendable {
    static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockUpdateURLProtocol.mockHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("App update checker", .serialized)
struct AppUpdateCheckerTests {

    @Test func semanticVersionParsingAndComparisons() {
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("   ") == nil)
        #expect(SemanticVersion("abc") == nil)

        let v1 = SemanticVersion("1.0")!
        let v10 = SemanticVersion("1.0.0")!
        let v100 = SemanticVersion("1.0.0.0")!
        #expect(v1 == v10)
        #expect(v10 == v100)

        let v101 = SemanticVersion("1.0.1")!
        #expect(v1 < v101)
        #expect(v101 > v10)

        let v19 = SemanticVersion("1.9.9")!
        let v110 = SemanticVersion("1.10.0")!
        #expect(v19 < v110)

        let v2 = SemanticVersion("2.0.0-beta.1")!
        #expect(v2.components == [2, 0, 0])
        #expect(v2 > v110)
    }

    @Test func remoteConfigDecodingAndLocalization() throws {
        let json = """
        {
            "latestVersion": "1.2.0",
            "minimumRequiredVersion": "1.1.0",
            "isMandatory": true,
            "appStoreURL": "https://apps.apple.com/app/cookienotes/id123456789",
            "title": {
                "en": "Major Update Available",
                "fr": "Mise à jour majeure disponible"
            },
            "message": {
                "en": "Please update to access new features.",
                "fr": "Veuillez mettre à jour pour accéder aux nouveautés."
            },
            "releaseNotes": "• Better performance\\n• New French translations"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(RemoteUpdateConfig.self, from: json)
        #expect(config.latestVersion == "1.2.0")
        #expect(config.minimumRequiredVersion == "1.1.0")
        #expect(config.isMandatory == true)
        #expect(config.appStoreURL == "https://apps.apple.com/app/cookienotes/id123456789")

        #expect(config.title?.resolve(languageCode: "en") == "Major Update Available")
        #expect(config.title?.resolve(languageCode: "fr") == "Mise à jour majeure disponible")
        #expect(config.message?.resolve(languageCode: "fr") == "Veuillez mettre à jour pour accéder aux nouveautés.")
        #expect(config.releaseNotes?.resolve(languageCode: "en")?.contains("Better performance") == true)
    }

    @MainActor
    @Test func mandatoryUpdateTriggeredWhenBelowMinimumVersion() async throws {
        let suite = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockUpdateURLProtocol.self]
        let session = URLSession(configuration: config)

        let remoteJSON = """
        {
            "latestVersion": "2.0.0",
            "minimumRequiredVersion": "1.5.0",
            "isMandatory": false
        }
        """.data(using: .utf8)!

        MockUpdateURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, remoteJSON)
        }

        let manager = AppUpdateManager(
            session: session,
            userDefaults: defaults,
            bundle: .main // installed is 1.0
        )
        manager.remoteConfigURL = URL(string: "https://localhost/update.json")

        await manager.checkForUpdates(force: true)

        let info = try #require(manager.updateInfo)
        #expect(info.version == "2.0.0")
        #expect(info.isMandatory == true) // Since installed 1.0 < minRequired 1.5.0
    }

    @MainActor
    @Test func optionalUpdateDismissalIsRespectedUntilNewerVersion() async throws {
        let suite = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockUpdateURLProtocol.self]
        let session = URLSession(configuration: config)

        var returnedVersion = "1.1.0"
        MockUpdateURLProtocol.mockHandler = { request in
            let json = """
            {
                "latestVersion": "\(returnedVersion)",
                "minimumRequiredVersion": "1.0.0",
                "isMandatory": false
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, json)
        }

        let manager = AppUpdateManager(
            session: session,
            userDefaults: defaults,
            bundle: .main
        )
        manager.remoteConfigURL = URL(string: "https://localhost/update.json")

        // 1. Initial check presents 1.1.0 update
        await manager.checkForUpdates(force: true)
        #expect(manager.updateInfo?.version == "1.1.0")
        #expect(manager.updateInfo?.isMandatory == false)

        // 2. User taps Maybe Later
        manager.dismissOptionalUpdate()
        #expect(manager.updateInfo == nil)
        #expect(defaults.string(forKey: AppUpdateManager.dismissedVersionKey) == "1.1.0")

        // 3. Subsequent check for same version is suppressed
        await manager.checkForUpdates(force: true)
        #expect(manager.updateInfo == nil)

        // 4. Newer version 1.2.0 is released -> prompt appears again
        returnedVersion = "1.2.0"
        await manager.checkForUpdates(force: true)
        #expect(manager.updateInfo?.version == "1.2.0")
    }

    @MainActor
    @Test func networkErrorsFailSilentlyWithoutThrowingOrInterrupting() async {
        let suite = "CookieNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockUpdateURLProtocol.self]
        let session = URLSession(configuration: config)

        MockUpdateURLProtocol.mockHandler = { _ in
            throw URLError(.timedOut)
        }

        let manager = AppUpdateManager(
            session: session,
            userDefaults: defaults,
            bundle: .main
        )
        manager.remoteConfigURL = URL(string: "https://localhost/update.json")

        await manager.checkForUpdates(force: true)
        #expect(manager.updateInfo == nil)
        #expect(manager.isChecking == false)
    }
}
