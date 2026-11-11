//
//  DiscoverView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @State private var query = ""
    @State private var results: [DiscoveredRecipeSummary] = []
    @State private var selectedRegion: CuisineRegion? = .african
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var path = NavigationPath()
    @State private var searchGeneration = 0
    @State private var didLoadDefaultBrowse = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                        header
                        browseByRegion
                        content
                    }
                    .padding(AppTheme.paddingMedium)
                }
            }
            // Inside NavigationStack + searchable → sits directly under the search bar.
            .overlay(alignment: .top) {
                InAppToastOverlay()
            }
            .navigationTitle(String.localized("Discover"))
            .navigationBarTitleDisplayMode(.large)
            // Keep the search field visible after tab switches (same reliability as Library).
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String.localized("Search recipes or countries")
            )
            .onSubmit(of: .search) { Task { await runSearch(fromTyping: false) } }
            .onChange(of: query) { _, newValue in
                scheduleLiveSearch(for: newValue)
            }
            .onChange(of: languageManager.currentLanguage) { _, _ in
                Task {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await runBrowse()
                    } else {
                        await runSearch(fromTyping: false)
                    }
                }
            }
            .navigationDestination(for: String.self) { mealID in
                DiscoverDetailView(mealID: mealID) { outcome in
                    // Pop first so the Discover search bar is back, then toast under it.
                    path = NavigationPath()
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(320))
                        switch outcome {
                        case .inserted:
                            InAppToast.shared.showRecipeAdded()
                        case .updatedExisting:
                            InAppToast.shared.show(String.localized("Already in Library"))
                        }
                    }
                }
            }
            .task {
                await loadDefaultBrowseIfNeeded()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        TitleSubtitleBlock(
            title: String.localized("Find something delicious"),
            style: .page,
            alignment: .leading
        )
    }

    private var browseByRegion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String.localized("Browse by Region"))
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CuisineTaxonomy.regions) { region in
                        ColorChip(title: region.title, selected: selectedRegion == region) {
                            selectedRegion = region
                            query = ""
                            Task { await runBrowse() }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(String.localized("Searching…"))
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let errorMessage {
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: String.localized("Couldn’t load recipes"),
                message: errorMessage,
                illustration: "soup_bowl",
                actionTitle: String.localized("Try again"),
                action: { Task { await retry() } }
            )
            .frame(minHeight: 280)
        } else if results.isEmpty {
            EmptyState(
                systemImage: "magnifyingglass",
                title: String.localized("Search the web of food"),
                message: "",
                illustration: "pepperoni_pizza"
            )
            .frame(minHeight: 280)
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(results) { recipe in
                    Button {
                        path.append(recipe.id)
                    } label: {
                        DiscoverCard(recipe: recipe)
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
        }
    }

    private func retry() async {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await runSearch(fromTyping: false)
        } else {
            await runBrowse()
        }
    }

    private func loadDefaultBrowseIfNeeded() async {
        guard !didLoadDefaultBrowse else { return }
        didLoadDefaultBrowse = true
        await runBrowse()
    }

    private func scheduleLiveSearch(for raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        searchGeneration += 1
        let generation = searchGeneration

        if trimmed.isEmpty {
            if selectedRegion == nil {
                Task {
                    guard generation == searchGeneration else { return }
                    selectedRegion = .african
                    await runBrowse()
                }
            }
            return
        }

        // Suggest as the user types (debounced) — includes dish names and countries.
        Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard generation == searchGeneration else { return }
            await runSearch(fromTyping: true)
        }
    }

    private func runSearch(fromTyping: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let generation = searchGeneration
        selectedRegion = nil
        errorMessage = nil
        let langSuffix = AppLanguageManager.shared.activeLanguage == .french ? "_fr" : "_en"
        if let cached = await MealDBClient.shared.cachedList(forKey: MealDBClient.listKey(search: trimmed) + langSuffix) {
            guard generation == searchGeneration else { return }
            results = cached
            isLoading = false
            return
        }
        if !fromTyping || results.isEmpty {
            isLoading = true
        }
        defer {
            if generation == searchGeneration {
                isLoading = false
            }
        }
        do {
            let found = try await MealDBClient.shared.search(query: trimmed)
            guard generation == searchGeneration else { return }
            results = found
        } catch {
            guard generation == searchGeneration else { return }
            errorMessage = error.localizedDescription
            results = []
        }
    }

    private func runBrowse() async {
        guard let selectedRegion else { return }
        searchGeneration += 1
        let generation = searchGeneration
        errorMessage = nil
        isLoading = true
        defer {
            if generation == searchGeneration { isLoading = false }
        }
        do {
            let found = try await MealDBClient.shared.filter(region: selectedRegion)
            // A newer chip tap or search owns the grid now.
            guard generation == searchGeneration else { return }
            results = found
        } catch {
            guard generation == searchGeneration else { return }
            errorMessage = error.localizedDescription
            results = []
        }
    }
}

struct DiscoverCard: View {
    let recipe: DiscoveredRecipeSummary
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @State private var times: RecipeTimeEstimate?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CachedRemoteImage(url: recipe.cardThumbnailURL, maxPointSize: 200) {
                AppTheme.blush.overlay(ProgressView())
            } failure: {
                illustrationFallback
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(recipe.name)
                .font(AppTheme.headline)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                // Reserved width/line so the card doesn't jump when the time arrives.
                Label(times.map { RecipeTimeFormat.short($0.total) } ?? "– min", systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .font(AppTheme.smallCaption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentAction)
                    .lineLimit(1)
                    .redacted(reason: times == nil ? .placeholder : [])
                Spacer(minLength: 4)
                let rawSubtitle = recipe.area ?? recipe.category
                let subtitle = rawSubtitle.map { String.localized($0, defaultValue: $0) }
                Text(subtitle ?? " ")
                    .font(AppTheme.smallCaption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
                    .opacity(subtitle == nil ? 0 : 1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .task(id: "\(recipe.id)_\(languageManager.currentLanguage.code)") {
            times = await MealDBClient.shared.timeEstimate(id: recipe.id)
        }
    }

    private var illustrationFallback: some View {
        AppTheme.blush
            .overlay {
                FoodIconView(iconID: recipe.illustrationIconID ?? "salad_bowl", size: 72)
            }
    }
}

struct DiscoverDetailView: View {
    let mealID: String
    var onSaved: (PersistenceController.DiscoveredRecipeSaveResult) -> Void

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @State private var detail: DiscoveredRecipeDetail?
    @State private var times = RecipeTimeEstimate(prep: 0, cook: 0)
    @State private var ingredientIcons: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var alreadySaved = false
    @State private var savedTrigger = false

    private struct IndexedRow: Identifiable {
        let id: String
        let index: Int
        let text: String
    }

    private var ingredientRows: [IndexedRow] {
        guard let detail else { return [] }
        return detail.ingredients.enumerated().map { idx, line in
            IndexedRow(id: "ing-\(idx)-\(line)", index: idx, text: line)
        }
    }

    private var instructionRows: [IndexedRow] {
        guard let detail else { return [] }
        return RecipeSanitizer.cleanInstructions(detail.instructions).enumerated().map { idx, step in
            IndexedRow(id: "step-\(idx)-\(step.prefix(24))", index: idx, text: step)
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if isLoading {
                ProgressView(String.localized("Loading recipe…"))
            } else if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                        CachedRemoteImage(url: detail.thumbnailURL, maxPointSize: 440) {
                            AppTheme.blush.overlay(ProgressView())
                        } failure: {
                            AppTheme.blush.overlay {
                                FoodIconView(iconID: detail.illustrationIconID ?? "salad_bowl", size: 100)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                        .accessibilityHidden(true)

                        Text(detail.name)
                            .font(AppTheme.largeTitle)
                            .foregroundStyle(AppTheme.primaryText)
                            .accessibilityAddTraits(.isHeader)

                        Text(detail.attribution)
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.secondaryText)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                TimeInfoView(title: String.localized("Prep"), time: times.prep)
                                TimeInfoView(title: String.localized("Cook"), time: times.cook)
                                TimeInfoView(title: String.localized("Total"), time: times.total)
                            }
                            Text(String.localized("Estimated from the recipe steps"))
                                .font(AppTheme.smallCaption)
                                .foregroundStyle(AppTheme.tertiaryText)
                        }

                        section(title: String.localized("Ingredients")) {
                            ForEach(ingredientRows) { row in
                                HStack(spacing: 10) {
                                    FoodIconView(
                                        iconID: ingredientIcons.indices.contains(row.index) ? ingredientIcons[row.index] : "",
                                        size: 36
                                    )
                                    .accessibilityHidden(true)
                                    Text(row.text)
                                        .font(AppTheme.body)
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                            }
                        }

                        section(title: String.localized("Instructions")) {
                            ForEach(instructionRows) { row in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(verbatim: "\(row.index + 1)")
                                        .font(AppTheme.smallCaption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(AppTheme.coral)
                                        .clipShape(Circle())
                                    Text(row.text)
                                        .font(AppTheme.body)
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }

                        Button {
                            Task { await save(detail) }
                        } label: {
                            let labelTitle: String = {
                                if isSaving { return String.localized("Saving…") }
                                if alreadySaved { return String.localized("Saved in My Recipes") }
                                return String.localized("Save to My Recipes")
                            }()
                            Label(labelTitle, systemImage: alreadySaved ? "checkmark.circle.fill" : "bookmark.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isSaving)
                    }
                    .padding(AppTheme.paddingMedium)
                }
            } else {
                EmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: String.localized("Recipe unavailable"),
                    message: errorMessage ?? String.localized("Try another result."),
                    illustration: "soup_bowl"
                )
            }
        }
        .navigationTitle(String.localized("Preview"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: languageManager.currentLanguage) { _, _ in
            Task { await load() }
        }
        .sensoryFeedback(.success, trigger: savedTrigger)
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.accent)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .sectionSurface()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await MealDBClient.shared.lookup(id: mealID)
            times = loaded.timeEstimate
            ingredientIcons = loaded.ingredients.map { IngredientCatalog.iconID(matching: $0) ?? "" }
            alreadySaved = PersistenceController.existingCatalogRecipe(forID: loaded.id, in: modelContext) != nil
            detail = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ detail: DiscoveredRecipeDetail) async {
        isSaving = true
        defer { isSaving = false }
        let icons = ingredientIcons.count == detail.ingredients.count
            ? ingredientIcons
            : detail.ingredients.map { IngredientCatalog.iconID(matching: $0) ?? "" }

        let existing = PersistenceController.existingCatalogRecipe(forID: detail.id, in: modelContext)
        let shouldDownloadPhoto = existing?.hasPhotos != true
        var photoData: Data?
        if shouldDownloadPhoto,
           let url = detail.thumbnailURL,
           let (data, response) = try? await URLSession.shared.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            photoData = data
        }

        let englishCounterpart = AppLanguageManager.shared.activeLanguage == .french
            ? await MealDBClient.shared.cachedEnglishDetail(id: detail.id)
            : nil

        do {
            let outcome = try PersistenceController.saveDiscoveredRecipe(
                detail,
                englishDetail: englishCounterpart,
                ingredientIcons: icons,
                photoData: photoData,
                into: modelContext
            )
            alreadySaved = true
            savedTrigger.toggle()
            NotificationManager.shared.markUserAsActive()
            onSaved(outcome)
        } catch {
            errorMessage = String.localized("Couldn’t save this recipe. Try again.")
        }
    }
}
