//
//  DiscoverView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI

private enum DiscoverBrowseChip: Hashable, Identifiable {
    case category(String)
    case area(String)

    var id: String {
        switch self {
        case .category(let name): "c:\(name)"
        case .area(let name): "a:\(name)"
        }
    }

    var title: String {
        switch self {
        case .category(let name), .area(let name): name
        }
    }
}

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var query = ""
    @State private var results: [DiscoveredRecipeSummary] = []
    @State private var categories: [String] = ["Beef", "Breakfast", "Chicken", "Dessert", "Pasta", "Seafood", "Vegetarian"]
    @State private var selectedChip: DiscoverBrowseChip? = .category("Beef")
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var path = NavigationPath()
    @State private var searchGeneration = 0
    @State private var didLoadDefaultBrowse = false

    /// Cuisine chips — local catalog fills West African + curated French / North American / Latino & islands.
    private let cuisineAreas: [String] = [
        // West Africa (local catalog)
        "Nigerian", "Ghanaian", "Senegalese",
        // French & North America
        "French", "American", "Canadian", "Mexican",
        // Latino & islands
        "Jamaican", "Caribbean",
        // Wider Africa
        "Egyptian", "Moroccan", "Tunisian", "Kenyan",
        // Asia (East + Southeast)
        "Chinese", "Japanese", "Thai", "Vietnamese", "Malaysian", "Filipino",
        // Middle East
        "Turkish", "Syrian", "Saudi Arabian"
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var browseChips: [DiscoverBrowseChip] {
        categories.map(DiscoverBrowseChip.category) + cuisineAreas.map(DiscoverBrowseChip.area)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                        header
                        categoryRow
                        content
                    }
                    .padding(AppTheme.paddingMedium)
                }
            }
            // Inside NavigationStack + searchable → sits directly under the search bar.
            .overlay(alignment: .top) {
                InAppToastOverlay()
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            // Keep the search field visible after tab switches (same reliability as Library).
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes or countries"
            )
            .onSubmit(of: .search) { Task { await runSearch(fromTyping: false) } }
            .onChange(of: query) { _, newValue in
                scheduleLiveSearch(for: newValue)
            }
            .navigationDestination(for: String.self) { mealID in
                DiscoverDetailView(mealID: mealID) {
                    // Pop first so the Discover search bar is back, then toast under it.
                    path = NavigationPath()
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(320))
                        InAppToast.shared.showRecipeAdded()
                    }
                }
            }
            .task {
                await loadCategories()
                await loadDefaultBrowseIfNeeded()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        TitleSubtitleBlock(
            title: "Find something delicious",
            subtitle: "Search by dish or country.",
            style: .page,
            alignment: .leading
        )
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(browseChips) { chip in
                    ColorChip(
                        title: chip.title,
                        selected: selectedChip == chip
                    ) {
                        selectedChip = chip
                        query = ""
                        Task { await runChip(chip) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Searching…")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let errorMessage {
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn’t load recipes",
                message: errorMessage,
                illustration: "soup_bowl",
                actionTitle: "Try again",
                action: { Task { await retry() } }
            )
            .frame(minHeight: 280)
        } else if results.isEmpty {
            EmptyState(
                systemImage: "magnifyingglass",
                title: "Search the web of food",
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
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func retry() async {
        if let selectedChip {
            await runChip(selectedChip)
        } else {
            await runSearch(fromTyping: false)
        }
    }

    private func loadCategories() async {
        do {
            let remote = try await MealDBClient.shared.categories()
            if !remote.isEmpty {
                // Prefer a balanced meal-type strip; cuisines are added separately.
                let preferred = ["Beef", "Breakfast", "Chicken", "Dessert", "Pasta", "Seafood", "Vegetarian", "Vegan", "Lamb", "Pork"]
                let ordered = preferred.filter { remote.contains($0) } + remote.filter { !preferred.contains($0) }
                categories = Array(ordered.prefix(8))
                if !categories.contains("Beef") {
                    categories.insert("Beef", at: 0)
                }
            }
        } catch {
            // Keep curated defaults.
        }
    }

    /// Open Discover on Beef with recipes already listed (no empty pizza state).
    private func loadDefaultBrowseIfNeeded() async {
        guard !didLoadDefaultBrowse else { return }
        didLoadDefaultBrowse = true
        await browseDefaultBeef()
    }

    private func browseDefaultBeef() async {
        let beef = DiscoverBrowseChip.category("Beef")
        selectedChip = beef
        query = ""
        await runChip(beef)
    }

    private func scheduleLiveSearch(for raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        searchGeneration += 1
        let generation = searchGeneration

        if trimmed.isEmpty {
            // Clearing a text search restores Beef. Chip taps set selectedChip first, then
            // clear query — don't override those with Beef.
            if selectedChip == nil {
                Task {
                    guard generation == searchGeneration else { return }
                    await browseDefaultBeef()
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
        selectedChip = nil
        errorMessage = nil
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

    private func runChip(_ chip: DiscoverBrowseChip) async {
        searchGeneration += 1
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch chip {
            case .category(let category):
                results = try await MealDBClient.shared.filter(category: category)
            case .area(let area):
                results = try await MealDBClient.shared.filter(area: area)
            }
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }
}

struct DiscoverCard: View {
    let recipe: DiscoveredRecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let url = recipe.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            illustrationFallback
                        default:
                            AppTheme.blush.overlay(ProgressView())
                        }
                    }
                } else {
                    illustrationFallback
                }
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

            Text(recipe.area ?? recipe.category ?? " ")
                .font(AppTheme.smallCaption.weight(.semibold))
                .foregroundStyle(AppTheme.accentAction)
                .lineLimit(1)
                .opacity((recipe.area ?? recipe.category) == nil ? 0 : 1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
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
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var detail: DiscoveredRecipeDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if isLoading {
                ProgressView("Loading recipe…")
            } else if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                        Group {
                            if let url = detail.thumbnailURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        AppTheme.blush.overlay {
                                            FoodIconView(iconID: detail.illustrationIconID ?? "salad_bowl", size: 100)
                                        }
                                    }
                                }
                            } else {
                                AppTheme.blush.overlay {
                                    FoodIconView(iconID: detail.illustrationIconID ?? "salad_bowl", size: 100)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

                        Text(detail.name)
                            .font(AppTheme.largeTitle)
                            .foregroundStyle(AppTheme.primaryText)

                        Text(detail.attribution)
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.secondaryText)

                        section(title: "Ingredients") {
                            ForEach(Array(detail.ingredients.enumerated()), id: \.offset) { index, line in
                                HStack(spacing: 10) {
                                    FoodIconView(iconID: IngredientCatalog.iconID(matching: line) ?? "", size: 36)
                                    Text(line)
                                        .font(AppTheme.body)
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                            }
                        }

                        section(title: "Instructions") {
                            ForEach(Array(detail.instructions.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(AppTheme.smallCaption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(AppTheme.coral)
                                        .clipShape(Circle())
                                    Text(step)
                                        .font(AppTheme.body)
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                            }
                        }

                        Button {
                            Task { await save(detail) }
                        } label: {
                            Label(isSaving ? "Saving…" : "Save to My Recipes", systemImage: "bookmark.fill")
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
                    title: "Recipe unavailable",
                    message: errorMessage ?? "Try another result.",
                    illustration: "soup_bowl"
                )
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.accent)
            content()
        }
        .sectionSurface()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await MealDBClient.shared.lookup(id: mealID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ detail: DiscoveredRecipeDetail) async {
        isSaving = true
        defer { isSaving = false }
        let icons = detail.ingredients.map { IngredientCatalog.iconID(matching: $0) ?? "" }
        let mappedCategory = RecipeCategory.inferred(fromMealDB: detail.category)
        let recipe = Recipe(
            name: detail.name,
            ingredients: detail.ingredients,
            instructions: detail.instructions,
            notes: "",
            source: detail.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (detail.sourceURL ?? detail.attribution)
                : detail.attribution,
            isImported: true,
            categoryRaw: mappedCategory.rawValue,
            ingredientIconIDs: icons,
            coverIconID: mappedCategory.preferredCoverIconID
        )
        if let url = detail.thumbnailURL,
           let (data, _) = try? await URLSession.shared.data(from: url),
           let stored = PhotoProcessing.makeStoredPhoto(from: data) {
            let photo = RecipePhoto(sortIndex: 0, imageData: stored.imageData, thumbnailData: stored.thumbnailData)
            photo.recipe = recipe
            modelContext.insert(photo)
        }
        modelContext.insert(recipe)
        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
            onSaved()
        } catch {
            errorMessage = "Couldn’t save this recipe. Try again."
        }
    }
}
