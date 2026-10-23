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
        let draft = SharedRecipeBuilder.draft(from: SharedRecipePayload(
            title: "",
            url: "https://example.com/stew",
            text: "https://example.com/stew",
            imageData: nil,
            receivedAt: Date(timeIntervalSince1970: 1)
        ))
        #expect(draft.name == "example.com")
        #expect(draft.source == "https://example.com/stew")
        #expect(draft.notes.contains("Saved from the web"))

        let unsafe = SharedRecipeBuilder.draft(from: SharedRecipePayload(
            title: "Card",
            url: "javascript:alert(1)",
            text: "",
            imageData: nil,
            receivedAt: Date(timeIntervalSince1970: 1)
        ))
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
        #expect(AdConsentStore.choice(defaults: defaults) == .unknown)
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
        let samples = try context.fetch(FetchDescriptor<Recipe>()).filter(\.isSample)
        #expect(samples.count == 1)
        #expect(samples[0].name == "Weeknight Fried Rice")
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
