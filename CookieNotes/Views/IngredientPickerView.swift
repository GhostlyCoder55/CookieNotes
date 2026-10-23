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

    private var filteredIcons: [String] {
        let base: [String]
        if let selectedCategory, let cat = catalog.categories.first(where: { $0.id == selectedCategory }) {
            base = cat.icons
        } else {
            base = IngredientCatalog.allIcons.filter { !$0.hasPrefix("cat_") && !$0.hasPrefix("extra_") }
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            IngredientCatalog.displayName(for: $0).localizedCaseInsensitiveContains(trimmed)
                || $0.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: AppTheme.paddingMedium) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ColorChip(title: "All", selected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(catalog.categories) { category in
                                ColorChip(
                                    title: category.title,
                                    selected: selectedCategory == category.id
                                ) {
                                    selectedCategory = category.id
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.paddingMedium)
                    }

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredIcons, id: \.self) { icon in
                                Button {
                                    onPick(IngredientCatalog.displayName(for: icon), icon)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        FoodIconView(iconID: icon, size: 64)
                                            .padding(6)
                                            .background(AppTheme.parchment)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        Text(IngredientCatalog.displayName(for: icon))
                                            .font(AppTheme.smallCaption.weight(.semibold))
                                            .foregroundStyle(AppTheme.primaryText)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(AppTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                                    .shadow(color: AppTheme.cardShadow, radius: 6, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppTheme.paddingMedium)
                        .padding(.bottom, AppTheme.paddingLarge)
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
}
