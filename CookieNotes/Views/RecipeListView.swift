//
//  RecipeListView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI

struct RecipeListView: View {
    var adsActive: Bool
    var storageWarning: String?

    @Query(sort: \Recipe.dateCreated, order: .reverse) private var recipes: [Recipe]
    @ObservedObject private var ads = AdMobController.shared
    @ObservedObject private var imports = ImportCoordinator.shared
    @AppStorage("cookienotes.recipeSort") private var sortRaw = RecipeSort.newest.rawValue
    @AppStorage("cookienotes.recipeFilter") private var filterRaw = RecipeFilter.all.rawValue
    @State private var showingAddRecipe = false
    @State private var searchText = ""
    @State private var path = NavigationPath()

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.paddingMedium),
        GridItem(.flexible(), spacing: AppTheme.paddingMedium)
    ]

    private var sort: RecipeSort { RecipeSort(rawValue: sortRaw) ?? .newest }
    private var filter: RecipeFilter { RecipeFilter(rawValue: filterRaw) ?? .all }

    private var displayed: [Recipe] {
        RecipeLibrary.prepare(recipes, query: searchText, filter: filter, sort: sort)
    }

    private var showAds: Bool {
        adsActive && path.isEmpty && !showingAddRecipe && ads.canPresentAds
    }

    private var libraryRecipes: [Recipe] {
        displayed
    }

    private var libraryIsEmpty: Bool {
        libraryRecipes.isEmpty && searchText.isEmpty && filter == .all
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if libraryIsEmpty {
                    EmptyStateView(onAdd: { showingAddRecipe = true })
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
                            hero
                            notices
                            filterBar
                            if libraryRecipes.isEmpty {
                                FilterEmptyView {
                                    filterRaw = RecipeFilter.all.rawValue
                                    searchText = ""
                                }
                            } else {
                                feed(items: libraryRecipes)
                            }
                        }
                        .padding(.horizontal, AppTheme.paddingMedium)
                        .padding(.vertical, AppTheme.paddingMedium)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search your recipes"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sortRaw) {
                            ForEach(RecipeSort.allCases) { item in
                                Text(item.title).tag(item.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Sort recipes")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddRecipe = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.burntOrange)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Add recipe")
                    .accessibilityIdentifier("add-recipe-button")
                }
            }
            .navigationDestination(for: UUID.self) { recipeID in
                if let recipe = recipes.first(where: { $0.recipeID == recipeID }) {
                    RecipeDetailView(recipe: recipe)
                } else {
                    MissingRecipeView()
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                AddRecipeView()
            }
            .onChange(of: recipes.count) { _, count in
                if count == 0 {
                    path = NavigationPath()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        HStack(spacing: 20) {
            FoodIconView(iconID: "salad_bowl", size: 72)
                .frame(width: 72, height: 72)
            Text("Your cookbook")
                .font(AppTheme.title)
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.paddingLarge)
        .padding(.horizontal, AppTheme.paddingMedium)
        .background(
            LinearGradient(colors: [AppTheme.parchment, AppTheme.cream], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    @ViewBuilder
    private var notices: some View {
        if let storageWarning, !storageWarning.isEmpty {
            NoticeBanner(message: storageWarning, systemImage: "externaldrive.badge.exclamationmark")
        }
        if let message = imports.bannerMessage {
            NoticeBanner(message: message, systemImage: "square.and.arrow.down") {
                Task { @MainActor in
                    imports.bannerMessage = nil
                }
            }
        }
        if let message = ads.availabilityMessage {
            NoticeBanner(message: message)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecipeFilter.allCases) { item in
                    ColorChip(
                        title: item.title,
                        selected: filter == item
                    ) {
                        filterRaw = item.rawValue
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func feed(items: [Recipe]) -> some View {
        // Snapshot recipes for this render so ad indices can't outlive a delete.
        let blocks = AdPlacement.blocks(
            from: AdPlacement.browsingSlots(itemCount: items.count, adsEnabled: showAds)
        )
        LazyVStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
            ForEach(blocks) { block in
                switch block.kind {
                case .items(let indices):
                    let recipes = indices.compactMap { items.indices.contains($0) ? items[$0] : nil }
                    LazyVGrid(columns: columns, spacing: AppTheme.paddingMedium) {
                        ForEach(recipes, id: \.recipeID) { recipe in
                            NavigationLink(value: recipe.recipeID) {
                                RecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("recipe-card")
                        }
                    }
                    .id("recipes-grid-\(items.count)-\(block.id)")
                case .advertisement:
                    AdvertisementSlot(placementID: "recipes-\(items.count)-\(block.id)")
                }
            }
        }
        .id("library-feed-\(items.count)")
    }
}

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RecipeThumbnail(
                    data: recipe.cardThumbnail,
                    iconID: recipe.resolvedCoverIcon,
                    iconIDs: recipe.resolvedCoverElements
                )
                .frame(maxWidth: .infinity)
                .frame(height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if recipe.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppTheme.burntOrange)
                        .padding(8)
                        .background(Circle().fill(AppTheme.elevatedHighlight.opacity(0.95)))
                        .padding(8)
                }
            }

            Text(recipe.name)
                .font(AppTheme.headline)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(recipe.formattedTotalTime)
                    .font(AppTheme.smallCaption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentAction)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(recipe.category.title)
                    .font(AppTheme.smallCaption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(tint: recipe.category.color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.accessibilitySummary)
        .accessibilityHint("Opens the recipe")
    }
}

struct EmptyStateView: View {
    var onAdd: () -> Void

    var body: some View {
        EmptyState(
            systemImage: "book.closed",
            title: "Your journal is empty",
            message: "Add a recipe you love, or discover one online and save it here.",
            illustration: "veggie_plate",
            actionTitle: "Add Recipe",
            action: onAdd
        )
        .padding(AppTheme.paddingLarge)
    }
}

struct FilterEmptyView: View {
    let reset: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.paddingMedium) {
            TitleSubtitleBlock(
                title: "Nothing matches",
                subtitle: "Try another meal type, or show everything in your library.",
                style: .page,
                alignment: .center
            )
            Button("Show all recipes", action: reset)
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.paddingXLarge)
    }
}

struct MissingRecipeView: View {
    var body: some View {
        EmptyState(
            systemImage: "book.closed",
            title: "Recipe unavailable",
            message: "This recipe is no longer in your library.",
            illustration: "soup_bowl"
        )
        .background(AppTheme.background)
    }
}

#Preview {
    RecipeListView(adsActive: false, storageWarning: nil)
        .modelContainer(PersistenceController.preview)
}
