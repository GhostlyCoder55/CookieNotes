//
//  CookieNotesUITests.swift
//  CookieNotesUITests
//

import XCTest

final class CookieNotesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-CookieNotesSkipTutorial",
            "-CookieNotesSkipConsent",
            "-CookieNotesSkipWelcome",
            "-CookieNotesSkipUpdateCheck",
            "-cookienotes.appLanguage", language,
            "-cookienotes.hasSelectedInitialLanguage", "YES"
        ]
        app.launch()
        return app
    }

    @MainActor
    func testEmptyLibraryShowsAddPrompt() throws {
        let app = launchApp(language: "en")
        let libraryButton = app.tabBars.buttons["Library"].exists ? app.tabBars.buttons["Library"] : app.tabBars.buttons["Bibliothèque"]
        XCTAssertTrue(libraryButton.waitForExistence(timeout: 8))
        let emptyText = app.staticTexts["Your journal is empty"].exists
            ? app.staticTexts["Your journal is empty"]
            : app.staticTexts["Votre carnet est vide"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["30 min or less"].exists)
        XCTAssertFalse(app.staticTexts["ADVERTISEMENT"].exists)
    }

    @MainActor
    func testDiscoverTabOpens() throws {
        let app = launchApp(language: "en")
        let discoverButton = app.tabBars.buttons["Discover"].exists ? app.tabBars.buttons["Discover"] : app.tabBars.buttons["Découvrir"]
        XCTAssertTrue(discoverButton.waitForExistence(timeout: 8))
        discoverButton.tap()
        let title = app.staticTexts["Find something delicious"].exists
            ? app.staticTexts["Find something delicious"]
            : app.staticTexts["Trouvez quelque chose de délicieux"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddRecipeScreenOpens() throws {
        let app = launchApp(language: "en")
        let addButton = app.buttons["add-recipe-button"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 8))
        addButton.tap()
        let navTitle = app.navigationBars["New Recipe"].exists
            ? app.navigationBars["New Recipe"]
            : app.navigationBars["Nouvelle recette"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ADVERTISEMENT"].exists)
        XCTAssertFalse(app.buttons["Snack"].exists)
        XCTAssertFalse(app.buttons["Collation"].exists)
    }

    @MainActor
    func testAboutTabHasNoCreatorAttributionAndLanguageSwitchWorks() throws {
        let app = launchApp(language: "en")
        let aboutButton = app.tabBars.buttons["About"].exists ? app.tabBars.buttons["About"] : app.tabBars.buttons["À propos"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 8))
        aboutButton.tap()

        XCTAssertFalse(app.staticTexts["Created by Christopher Ogbonnaya"].exists)
        XCTAssertFalse(app.staticTexts["Créé par Christopher Ogbonnaya"].exists)

        // Switch to French
        let frenchButton = app.buttons["Français 🇫🇷"]
        XCTAssertTrue(frenchButton.waitForExistence(timeout: 5))
        frenchButton.tap()

        XCTAssertTrue(app.tabBars.buttons["À propos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Bibliothèque"].exists)
        XCTAssertTrue(app.tabBars.buttons["Découvrir"].exists)
        XCTAssertFalse(app.staticTexts["Créé par Christopher Ogbonnaya"].exists)

        // Switch back to English
        let englishButton = app.buttons["English 🇬🇧"]
        XCTAssertTrue(englishButton.waitForExistence(timeout: 5))
        englishButton.tap()

        XCTAssertTrue(app.tabBars.buttons["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Library"].exists)
        XCTAssertTrue(app.tabBars.buttons["Discover"].exists)
    }

    @MainActor
    func testDiscoverDetailInFrenchTranslatesIngredientsAndSteps() throws {
        let app = launchApp(language: "fr")
        let discoverButton = app.tabBars.buttons["Découvrir"].exists ? app.tabBars.buttons["Découvrir"] : app.tabBars.buttons["Discover"]
        XCTAssertTrue(discoverButton.waitForExistence(timeout: 8))
        discoverButton.tap()

        let title = app.staticTexts["Trouvez quelque chose de délicieux"].exists
            ? app.staticTexts["Trouvez quelque chose de délicieux"]
            : app.staticTexts["Find something delicious"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))

        // Bouzgene bread should never appear
        XCTAssertFalse(app.staticTexts["Pain berbère algérien bouzgène avec sauce aux poivrons rôtis"].exists)

        // Open Algerian Carrots (default African region first item in French)
        let algerianCard = app.staticTexts["Carottes algériennes"]
        XCTAssertTrue(algerianCard.waitForExistence(timeout: 12))
        algerianCard.tap()

        // Verify Aperçu screen
        let previewBar = app.navigationBars["Aperçu"].exists ? app.navigationBars["Aperçu"] : app.navigationBars["Preview"]
        XCTAssertTrue(previewBar.waitForExistence(timeout: 8))

        // Verify Ingrédients and Instructions are in French (not untranslated English)
        XCTAssertTrue(app.staticTexts["Ingrédients"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Instructions"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'carottes'")).firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'panier vapeur'")).firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Place a steamer'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Lemon Juice'")).firstMatch.exists)

        // Verify Algerian area is translated in French attribution
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Algerian'")).firstMatch.exists)

        // Verify Save button
        let saveButton = app.buttons["Enregistrer dans mes recettes"].exists
            ? app.buttons["Enregistrer dans mes recettes"]
            : app.buttons["Save to My Recipes"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8))
    }

    @MainActor
    func testAddRecipeLibraryLifecycleInFrench() throws {
        let app = launchApp(language: "fr")
        let addButton = app.buttons["add-recipe-button"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 8))
        addButton.tap()

        XCTAssertTrue(app.navigationBars["Nouvelle recette"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Snack"].exists)
        XCTAssertFalse(app.buttons["Collation"].exists)

        let nameField = app.textFields["Chili de semaine, pain aux bananes…"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Tarte aux pommes")

        let ingredientView = app.textViews.matching(NSPredicate(format: "value CONTAINS 'Ingrédient' OR placeholderValue == 'Ingrédient'")).firstMatch
        let ingredientField = app.textFields.matching(NSPredicate(format: "value CONTAINS 'Ingrédient' OR placeholderValue == 'Ingrédient'")).firstMatch
        if ingredientView.waitForExistence(timeout: 3) {
            ingredientView.tap()
            ingredientView.typeText("2 pommes")
        } else {
            XCTAssertTrue(ingredientField.waitForExistence(timeout: 5))
            ingredientField.tap()
            ingredientField.typeText("2 pommes")
        }

        let saveButton = app.navigationBars["Nouvelle recette"].buttons["Enregistrer"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        let card = app.buttons["recipe-card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Collation"].exists)
        XCTAssertFalse(app.buttons["Snack"].exists)

        card.tap()
        XCTAssertTrue(app.staticTexts["Tarte aux pommes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ingrédients"].exists)
        XCTAssertTrue(app.staticTexts["2 pommes"].exists)

        let moreButton = app.buttons["Plus d'options"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
        moreButton.tap()

        let deleteMenuButton = app.buttons["Supprimer"]
        XCTAssertTrue(deleteMenuButton.waitForExistence(timeout: 5))
        deleteMenuButton.tap()

        let confirmDelete = app.alerts["Supprimer la recette"].buttons["Supprimer"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()

        XCTAssertTrue(app.staticTexts["Votre carnet est vide"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testFirstLaunchLanguageSelectionShowsAndPersistsChoice() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-CookieNotesSkipConsent",
            "-CookieNotesSkipWelcome",
            "-CookieNotesSkipUpdateCheck",
            "-cookienotes.didCompleteFirstRunTips", "NO",
            "-cookienotes.appLanguage", "en",
            "-cookienotes.hasSelectedInitialLanguage", "NO"
        ]
        app.launch()

        // Page 1 of Tips: Choose your language (no Welcome headline, no AppLogo, subtitle present)
        let titlePredicate = NSPredicate(format: "label ==[c] 'Choose your language'")
        XCTAssertTrue(app.staticTexts.matching(titlePredicate).firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["You can change the language anytime."].exists)
        XCTAssertFalse(app.images["AppLogo"].exists)
        XCTAssertFalse(app.staticTexts["Welcome to CookieNotes"].exists)
        XCTAssertFalse(app.staticTexts["Choose your preferred language to get started."].exists)

        let englishCard = app.buttons["language-option-en"]
        let frenchCard = app.buttons["language-option-fr"]
        XCTAssertTrue(englishCard.exists)
        XCTAssertTrue(frenchCard.exists)

        // Verify horizontal side-by-side layout and square boxes
        let enFrame = englishCard.frame
        let frFrame = frenchCard.frame
        XCTAssertLessThan(abs(enFrame.midY - frFrame.midY), 2.0)
        XCTAssertLessThan(enFrame.maxX, frFrame.minX)
        XCTAssertLessThan(abs(enFrame.width - enFrame.height), 2.0)
        XCTAssertLessThan(abs(frFrame.width - frFrame.height), 2.0)

        frenchCard.tap()

        let frenchTitle = app.staticTexts["Choisissez votre langue"]
        let frenchSubtitle = app.staticTexts["Vous pouvez changer la langue en tout temps."]
        XCTAssertTrue(frenchTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(frenchSubtitle.exists)

        // Verify French title & subtitle stay compact single-line horizontal and centered closely above the cards
        XCTAssertLessThan(frenchTitle.frame.height, 36.0)
        XCTAssertLessThan(frenchSubtitle.frame.height, 26.0)
        let cardCenterX = (enFrame.minX + frFrame.maxX) / 2.0
        XCTAssertLessThan(abs(frenchTitle.frame.midX - cardCenterX), 4.0)
        XCTAssertLessThan(abs(frenchSubtitle.frame.midX - cardCenterX), 4.0)
        XCTAssertLessThan(enFrame.minY - frenchSubtitle.frame.maxY, 45.0)
        XCTAssertGreaterThan(enFrame.minY - frenchSubtitle.frame.maxY, 15.0)

        let continueButton = app.buttons["Continuer"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // Tapping Continue slides to the second page of Tips: Welcome to CookieNotes
        let welcomeTitle = app.staticTexts["Bienvenue sur CookieNotes"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5))
        let welcomeSettled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in abs(welcomeTitle.frame.midX - cardCenterX) < 6.0 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [welcomeSettled], timeout: 3), .completed)
        XCTAssertLessThan(welcomeTitle.frame.height, 36.0)

        let baselineTitleMinY = welcomeTitle.frame.minY
        let expectedTipTitles = [
            "Bibliothèque",
            "Découvrir",
            "Illustrations d'ingrédients",
            "Vous êtes prêt !"
        ]
        for expectedTitle in expectedTipTitles {
            continueButton.tap()
            let pageTitle = app.staticTexts[expectedTitle]
            XCTAssertTrue(pageTitle.waitForExistence(timeout: 5))
            // Wait briefly for page transition to settle on-screen
            let predicate = NSPredicate { _, _ in
                abs(pageTitle.frame.midX - cardCenterX) < 6.0
            }
            let settled = XCTNSPredicateExpectation(predicate: predicate, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
            XCTAssertLessThan(pageTitle.frame.height, 36.0)
            XCTAssertLessThan(abs(pageTitle.frame.minY - baselineTitleMinY), 2.5)
        }

        let getStartedButton = app.buttons["Commencer"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        getStartedButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Bibliothèque"].waitForExistence(timeout: 8))

        // Relaunch without language overrides: choice should persist and first-launch screens must not reappear
        app.terminate()
        app.launchArguments = [
            "-CookieNotesSkipConsent",
            "-CookieNotesSkipWelcome",
            "-CookieNotesSkipUpdateCheck"
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Bibliothèque"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Choose your language"].exists)
        XCTAssertFalse(app.staticTexts["Choose your Language"].exists)
        XCTAssertFalse(app.staticTexts["Choisissez votre langue"].exists)
        XCTAssertFalse(app.buttons["language-option-en"].exists)
        XCTAssertFalse(app.buttons["language-option-fr"].exists)
    }

    @MainActor
    func testOptionalUpdatePromptCanBeDismissed() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-CookieNotesSkipTutorial",
            "-CookieNotesSkipConsent",
            "-CookieNotesSkipWelcome",
            "-CookieNotesResetUpdateDismissal",
            "-CookieNotesMockUpdateAvailable", "1.2.0",
            "-cookienotes.appLanguage", "en",
            "-cookienotes.hasSelectedInitialLanguage", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Update Available"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Update Now"].exists)
        let maybeLater = app.buttons["Maybe Later"]
        XCTAssertTrue(maybeLater.exists)

        maybeLater.tap()

        XCTAssertFalse(app.staticTexts["Update Available"].exists)
    }

    @MainActor
    func testMandatoryUpdatePromptCannotBeDismissed() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-CookieNotesSkipTutorial",
            "-CookieNotesSkipConsent",
            "-CookieNotesSkipWelcome",
            "-CookieNotesMockMandatoryUpdate", "2.0.0",
            "-cookienotes.appLanguage", "fr",
            "-cookienotes.hasSelectedInitialLanguage", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Mise à jour essentielle requise"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Mettre à jour"].exists)
        XCTAssertFalse(app.buttons["Plus tard"].exists)
        XCTAssertFalse(app.buttons["Maybe Later"].exists)
    }

    @MainActor
    func testDiscoverFrenchRegionsHaveNoDuplicateCards() throws {
        let app = launchApp(language: "fr")
        let discoverButton = app.tabBars.buttons["Découvrir"].exists ? app.tabBars.buttons["Découvrir"] : app.tabBars.buttons["Discover"]
        XCTAssertTrue(discoverButton.waitForExistence(timeout: 8))
        discoverButton.tap()

        XCTAssertTrue(app.staticTexts["Trouvez quelque chose de délicieux"].waitForExistence(timeout: 8))

        // 1. Caribbean region in French: verify single canonical entries and zero legacy duplicates
        let caribbeanChip = app.buttons["Caribéenne"]
        XCTAssertTrue(caribbeanChip.waitForExistence(timeout: 5))
        if !caribbeanChip.isHittable {
            app.buttons["Africaine"].swipeLeft()
        }
        caribbeanChip.tap()

        XCTAssertTrue(app.staticTexts["Boules de tamarin des Caraïbes"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Callaloo et poisson salé"].exists)
        XCTAssertFalse(app.staticTexts["Boules de tamarin antillaises"].exists)
        XCTAssertFalse(app.staticTexts["Callaloo et morue salée"].exists)
        XCTAssertFalse(app.staticTexts["Poisson escovitch jamaïcain"].exists)

        // 2. Scroll the horizontal chip bar to reveal North American, then verify no chili/BeaverTails dupes
        let northAmericanChip = app.buttons["Nord-américaine"]
        XCTAssertTrue(northAmericanChip.waitForExistence(timeout: 5))
        let chipBarY = caribbeanChip.frame.midY
        for _ in 0..<4 where northAmericanChip.frame.maxX > app.frame.maxX - 16 {
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width - 40, dy: chipBarY))
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: chipBarY))
            start.press(forDuration: 0.02, thenDragTo: end)
        }
        northAmericanChip.tap()

        XCTAssertTrue(app.staticTexts["Barres de Nanaimo"].waitForExistence(timeout: 15))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Chili au bœuf braisé"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Chili de bœuf braisé au chorizo"].exists)
        XCTAssertFalse(app.staticTexts["Queues de castor (BeaverTails)"].exists)

        // 3. Search "Queues de castor" directly to verify exactly 1 card appears
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Queues de castor\n")
        XCTAssertTrue(app.staticTexts["Queues de castor"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.staticTexts["Queues de castor (BeaverTails)"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == 'Queues de castor'")).count, 1)
    }

    @MainActor
    func testSaveDiscoverRecipeThenSwitchLanguagePreservesSingleSyncedRecipe() throws {
        let app = launchApp(language: "fr")
        let discoverButton = app.tabBars.buttons["Découvrir"]
        XCTAssertTrue(discoverButton.waitForExistence(timeout: 8))
        discoverButton.tap()

        let algerianCardFR = app.staticTexts["Carottes algériennes"]
        XCTAssertTrue(algerianCardFR.waitForExistence(timeout: 15))
        algerianCardFR.tap()

        let saveButtonFR = app.buttons["Enregistrer dans mes recettes"]
        XCTAssertTrue(saveButtonFR.waitForExistence(timeout: 10))
        saveButtonFR.tap()

        // Saving returns to Discover feed
        XCTAssertTrue(app.staticTexts["Trouvez quelque chose de délicieux"].waitForExistence(timeout: 10))

        // Check Library (Bibliothèque) has 1 French recipe
        let libraryTabFR = app.tabBars.buttons["Bibliothèque"]
        XCTAssertTrue(libraryTabFR.exists)
        libraryTabFR.tap()
        XCTAssertTrue(app.staticTexts["Carottes algériennes"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier == 'recipe-card'")).count, 1)

        // Switch language to English in À propos
        app.tabBars.buttons["À propos"].tap()
        let englishButton = app.buttons["English 🇬🇧"]
        XCTAssertTrue(englishButton.waitForExistence(timeout: 5))
        englishButton.tap()

        // Library still has 1 recipe, now cleanly displayed in English
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["Algerian Carrots"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Carottes algériennes"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier == 'recipe-card'")).count, 1)

        // Opening it shows English content
        app.staticTexts["Algerian Carrots"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Carrots'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'panier vapeur'")).firstMatch.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'recipe-card'")).firstMatch.waitForExistence(timeout: 5))

        // Check Discover in English shows "Saved in My Recipes" and does not duplicate on tap
        app.tabBars.buttons["Discover"].tap()
        let algerianCardEN = app.staticTexts["Algerian Carrots"]
        XCTAssertTrue(algerianCardEN.waitForExistence(timeout: 15))
        algerianCardEN.tap()
        let alreadySavedButton = app.buttons["Saved in My Recipes"]
        XCTAssertTrue(alreadySavedButton.waitForExistence(timeout: 10))
        alreadySavedButton.tap()

        XCTAssertTrue(app.staticTexts["Find something delicious"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Library"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier == 'recipe-card'")).count, 1)

        // Clean up the test recipe so persistent UI-test store remains empty for other UI tests
        app.buttons["recipe-card"].firstMatch.tap()
        let moreButton = app.buttons["More options"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
        moreButton.tap()
        let deleteMenuButton = app.buttons["Delete"]
        XCTAssertTrue(deleteMenuButton.waitForExistence(timeout: 5))
        deleteMenuButton.tap()
        let confirmDelete = app.alerts["Delete Recipe"].buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()
        XCTAssertTrue(app.staticTexts["Your journal is empty"].waitForExistence(timeout: 8))
    }
}
