//
//  IngredientPickerView.swift
//  CookieNotes
//

import SwiftUI

struct IngredientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedCategory: String?
    var onPick: (String, String) -> Void

    private var catalog: IngredientCatalogFile { IngredientCatalog.shared }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    /// Search always spans every section; the chip only scopes browsing.
    private var activeCategory: String? { isSearching ? nil : selectedCategory }

    private static let pickableIcons: [String] = IngredientCatalog.allIcons.filter {
        !$0.hasPrefix("cat_") && !$0.hasPrefix("extra_")
    }

    private var filteredIcons: [String] {
        let allPickable = Self.pickableIcons

        let matched: [String]
        if isSearching {
            let trimmed = trimmedQuery
            let pickable = Set(allPickable)
            let lowered = trimmed.lowercased()
            let aliasHits: Set<String> = lowered.count < 3 ? [] : Set(
                catalog.aliases
                    .filter { $0.key.hasPrefix(lowered) }
                    .map(\.value)
            ).intersection(pickable)
            let hits = allPickable.filter {
                IngredientCatalog.displayName(for: $0).localizedCaseInsensitiveContains(trimmed)
                    || $0.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(trimmed)
                    || aliasHits.contains($0)
            }
            matched = hits.sorted { lhs, rhs in
                let l = IngredientCatalog.displayName(for: lhs).lowercased()
                let r = IngredientCatalog.displayName(for: rhs).lowercased()
                let lRank = l == lowered ? 0 : (l.hasPrefix(lowered) ? 1 : 2)
                let rRank = r == lowered ? 0 : (r.hasPrefix(lowered) ? 1 : 2)
                return lRank != rRank ? lRank < rRank : l < r
            }
        } else if let selectedCategory,
                  let cat = catalog.categories.first(where: { $0.id == selectedCategory }) {
            // Keep catalog order; drop blank ids so a bad entry can't blank the grid.
            matched = cat.icons.filter { !$0.isEmpty }
        } else {
            // Unknown/missing category falls back to All instead of an empty screen.
            matched = allPickable
        }

        // One card per display name so search never shows duplicates like two "Baking soda"s.
        var seenNames = Set<String>()
        return matched.filter { icon in
            let key = IngredientCatalog.displayName(for: icon).lowercased()
            return seenNames.insert(key).inserted
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var gridIdentity: String {
        "\(activeCategory ?? "all")|\(trimmedQuery.lowercased())"
    }

    var body: some View {
        let filteredIcons = filteredIcons

        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: AppTheme.paddingMedium) {
                    categoryChips

                    ScrollViewReader { proxy in
                        ScrollView {
                            Color.clear.frame(height: 0).id("ingredients-top")

                            if filteredIcons.isEmpty {
                                emptyResults
                                    .padding(.top, 48)
                                    .padding(.horizontal, AppTheme.paddingMedium)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filteredIcons, id: \.self) { icon in
                                        ingredientCard(icon)
                                    }
                                }
                                .padding(.horizontal, AppTheme.paddingMedium)
                                .padding(.bottom, AppTheme.paddingLarge)
                                .id(gridIdentity)
                            }
                        }
                        .onChange(of: gridIdentity) { _, _ in
                            proxy.scrollTo("ingredients-top", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search ingredients")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ColorChip(title: "All", selected: activeCategory == nil) {
                    selectCategory(nil)
                }
                ForEach(catalog.categories) { category in
                    ColorChip(
                        title: category.title,
                        selected: activeCategory == category.id
                    ) {
                        selectCategory(category.id)
                    }
                }
            }
            .padding(.horizontal, AppTheme.paddingMedium)
        }
    }

    private var emptyResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.tertiaryText)
            Text(emptyTitle)
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)
            if isSearching {
                Button("Clear search") {
                    query = ""
                }
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(AppTheme.burntOrange)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyTitle: String {
        if isSearching {
            return "No ingredients match “\(trimmedQuery)”"
        }
        if let selectedCategory,
           let title = catalog.categories.first(where: { $0.id == selectedCategory })?.title {
            return "No ingredients in \(title)"
        }
        return "No ingredients found"
    }

    private func selectCategory(_ id: String?) {
        selectedCategory = id
        // Stale search text is the usual reason a category looks empty.
        query = ""
    }

    private func ingredientCard(_ icon: String) -> some View {
        Button {
            onPick(IngredientCatalog.displayName(for: icon), icon)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    AppTheme.parchment
                    FoodIconView(iconID: icon, size: 64)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(IngredientCatalog.displayName(for: icon))
                    .font(AppTheme.smallCaption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(10)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(IngredientCatalog.displayName(for: icon))
    }
}
