//
//  SearchView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI

struct SearchView: View {
    var adsActive: Bool

    @Query(sort: \Recipe.dateCreated, order: .reverse) private var recipes: [Recipe]
    @ObservedObject private var ads = AdMobController.shared
    @State private var searchText = ""
    @State private var path = NavigationPath()

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Recipe] {
        guard !trimmedQuery.isEmpty else { return [] }
        return RecipeLibrary.prepare(recipes, query: trimmedQuery)
    }

    private var showAds: Bool {
        adsActive && path.isEmpty && ads.canPresentAds && !results.isEmpty
    }

    private var slots: [AdSlot] {
        AdPlacement.searchSlots(itemCount: results.count, adsEnabled: showAds && !results.isEmpty)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if results.isEmpty {
                    EmptySearchView(searchText: searchText, libraryIsEmpty: recipes.isEmpty)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                                switch slot {
                                case .item(let index):
                                    let recipe = results[index]
                                    NavigationLink(value: recipe.recipeID) {
                                        SearchResultRow(recipe: recipe)
                                    }
                                    .buttonStyle(.plain)

                                    if shouldShowDivider(after: index, slots: slots) {
                                        Divider()
                                            .background(AppTheme.separator.opacity(0.45))
                                            .padding(.leading, 72)
                                    }
                                case .advertisement:
                                    AdvertisementSlot(placementID: "search")
                                        .padding(.vertical, AppTheme.paddingMedium)
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.paddingMedium)
                        .padding(.vertical, AppTheme.paddingSmall)
                        .frame(maxWidth: 800)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Recipes, ingredients, notes"
            )
            .navigationDestination(for: UUID.self) { recipeID in
                if let recipe = recipes.first(where: { $0.recipeID == recipeID }) {
                    RecipeDetailView(recipe: recipe)
                } else {
                    MissingRecipeView()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func shouldShowDivider(after index: Int, slots: [AdSlot]) -> Bool {
        guard let currentOffset = slots.firstIndex(where: {
            if case .item(let i) = $0 { return i == index }
            return false
        }) else { return false }
        let next = currentOffset + 1
        guard next < slots.count else { return false }
        if case .item = slots[next] { return true }
        return false
    }
}

struct SearchResultRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: AppTheme.paddingMedium) {
            RecipeThumbnail(
                data: recipe.cardThumbnail,
                iconID: recipe.resolvedCoverIcon,
                iconIDs: recipe.resolvedCoverElements
            )
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(recipe.formattedTotalTime)
                        .foregroundStyle(AppTheme.accentYellow)
                    if !recipe.ingredients.isEmpty {
                        Text("·")
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("\(recipe.ingredients.count) ingredients")
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
                .font(AppTheme.smallCaption)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.tertiaryText.opacity(0.7))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.accessibilitySummary)
        .accessibilityHint("Opens the recipe")
    }
}

struct EmptySearchView: View {
    let searchText: String
    let libraryIsEmpty: Bool

    var body: some View {
        EmptyState(
            systemImage: searchText.isEmpty ? "magnifyingglass" : "text.magnifyingglass",
            title: title,
            message: message
        )
        .padding(AppTheme.paddingLarge)
    }

    private var title: String {
        if libraryIsEmpty { return "No Recipes Yet" }
        return searchText.isEmpty ? "Search Your Library" : "No Results"
    }

    private var message: String {
        if libraryIsEmpty {
            return "Recipes you add will show up here. Search looks through names, ingredients, steps, and notes."
        }
        if searchText.isEmpty {
            return "Find a recipe by its name, an ingredient, a step, or a note."
        }
        return "Try a different word, or check the spelling."
    }
}

#Preview {
    SearchView(adsActive: false)
        .modelContainer(PersistenceController.preview)
        .preferredColorScheme(.dark)
}
