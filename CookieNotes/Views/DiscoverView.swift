//
//  DiscoverView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var query = ""
    @State private var results: [DiscoveredRecipeSummary] = []
    @State private var categories: [String] = ["Seafood", "Chicken", "Dessert", "Vegetarian", "Pasta", "Breakfast"]
    @State private var selectedCategory: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var path = NavigationPath()
    @State private var saveNotice: String?

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
                        categoryRow
                        if let saveNotice {
                            NoticeBanner(message: saveNotice, systemImage: "checkmark.circle.fill") {
                                self.saveNotice = nil
                            }
                        }
                        content
                    }
                    .padding(AppTheme.paddingMedium)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search online recipes")
            .onSubmit(of: .search) { Task { await runSearch() } }
            .onChange(of: query) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   selectedCategory == nil {
                    results = []
                }
            }
            .navigationDestination(for: String.self) { mealID in
                DiscoverDetailView(mealID: mealID) { notice in
                    saveNotice = notice
                    path = NavigationPath()
                }
            }
            .task { await loadCategories() }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find something delicious")
                .font(AppTheme.title)
                .foregroundStyle(AppTheme.primaryText)
            Text("Search the meal, preview a recipe, then save it to your journal.")
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    ColorChip(
                        title: category,
                        selected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        query = ""
                        Task { await runCategory(category) }
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
        if let selectedCategory {
            await runCategory(selectedCategory)
        } else {
            await runSearch()
        }
    }

    private func loadCategories() async {
        do {
            let remote = try await MealDBClient.shared.categories()
            if !remote.isEmpty {
                categories = Array(remote.prefix(10))
            }
        } catch {
            // Keep curated defaults.
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedCategory = nil
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await MealDBClient.shared.search(query: trimmed)
            if results.isEmpty { errorMessage = nil }
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }

    private func runCategory(_ category: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await MealDBClient.shared.filter(category: category)
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
            AsyncImage(url: recipe.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    AppTheme.blush
                default:
                    AppTheme.blush.overlay(ProgressView())
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

            Text(recipe.category ?? " ")
                .font(AppTheme.smallCaption.weight(.semibold))
                .foregroundStyle(AppTheme.accentAction)
                .lineLimit(1)
                .opacity(recipe.category == nil ? 0 : 1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct DiscoverDetailView: View {
    let mealID: String
    var onSaved: (String) -> Void

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
                        AsyncImage(url: detail.thumbnailURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                AppTheme.blush.frame(height: 220)
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
            onSaved("Saved “\(detail.name)” to your library.")
        } catch {
            errorMessage = "Couldn’t save this recipe. Try again."
        }
    }
}
