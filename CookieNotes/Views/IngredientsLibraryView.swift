//
//  IngredientsLibraryView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI
import UIKit

struct IngredientsLibraryView: View {
    @Query(sort: \LibraryIngredient.name) private var ingredients: [LibraryIngredient]
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditor = false
    @State private var editingIngredient: LibraryIngredient?
    @State private var copyNotice: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if ingredients.isEmpty {
                    EmptyState(
                        systemImage: "carrot",
                        title: "No Saved Ingredients",
                        message: "Save ingredients you use often, then copy them into any recipe.",
                        actionTitle: "Add Ingredient",
                        action: { showingEditor = true }
                    )
                    .padding(AppTheme.paddingLarge)
                } else {
                    List {
                        Section {
                            Text("Reuse these when you write a recipe. Copy one line or the whole list.")
                                .font(AppTheme.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(ingredients, id: \.ingredientID) { item in
                                ingredientRow(item)
                            }
                            .onDelete(perform: delete)
                        } header: {
                            Text("Library")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingIngredient = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryBrown)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Add ingredient")
                }
                if !ingredients.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            copyAll()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(AppTheme.secondaryBrown)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Copy all ingredients")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                IngredientEditorSheet(ingredient: editingIngredient) { name, detail in
                    save(name: name, detail: detail, existing: editingIngredient)
                }
            }
            .overlay(alignment: .bottom) {
                if let copyNotice {
                    Text(copyNotice)
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, AppTheme.paddingMedium)
                        .padding(.vertical, AppTheme.paddingSmall)
                        .background(AppTheme.surfaceBackground)
                        .clipShape(Capsule())
                        .padding(.bottom, AppTheme.paddingLarge)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func ingredientRow(_ item: LibraryIngredient) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.paddingMedium) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(AppTheme.smallCaption)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            Spacer(minLength: 8)
            Button {
                copyLine(item.displayLine)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(AppTheme.secondaryBrown)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(item.name)")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingIngredient = item
            showingEditor = true
        }
        .listRowBackground(AppTheme.cardBackground)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(ingredients[index])
        }
        try? modelContext.save()
    }

    private func save(name: String, detail: String, existing: LibraryIngredient?) {
        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(RecipeInputLimits.libraryIngredientName))
        let cleanDetail = String(detail.trimmingCharacters(in: .whitespacesAndNewlines).prefix(RecipeInputLimits.libraryIngredientDetail))
        guard !cleanName.isEmpty else { return }

        if let existing {
            existing.name = cleanName
            existing.detail = cleanDetail
            existing.dateModified = Date()
        } else {
            modelContext.insert(LibraryIngredient(name: cleanName, detail: cleanDetail))
        }
        try? modelContext.save()
        editingIngredient = nil
    }

    private func copyLine(_ text: String) {
        UIPasteboard.general.string = text
        flashNotice("Copied")
    }

    private func copyAll() {
        let text = ingredients.map(\.displayLine).joined(separator: "\n")
        UIPasteboard.general.string = text
        flashNotice("Copied \(ingredients.count) ingredients")
    }

    private func flashNotice(_ message: String) {
        withAnimation {
            copyNotice = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation { copyNotice = nil }
            }
        }
    }
}

struct IngredientEditorSheet: View {
    let ingredient: LibraryIngredient?
    var onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                    RecipeFormSection(title: "Ingredient") {
                        TextField("Flour, garlic, olive oil…", text: $name)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textInputAutocapitalization(.never)
                    }
                    RecipeFormSection(title: "Amount or note (optional)") {
                        TextField("1 cup, 2 cloves, to taste…", text: $detail)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textInputAutocapitalization(.never)
                    }
                    Spacer()
                }
                .padding(AppTheme.paddingMedium)
            }
            .navigationTitle(ingredient == nil ? "New Ingredient" : "Edit Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, detail)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.tertiaryText : AppTheme.secondaryBrown)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = ingredient?.name ?? ""
                detail = ingredient?.detail ?? ""
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Sheet to pick library ingredients and append them to a recipe draft.
struct IngredientPickerSheet: View {
    @Query(sort: \LibraryIngredient.name) private var ingredients: [LibraryIngredient]
    @Environment(\.dismiss) private var dismiss
    var onPick: ([String]) -> Void

    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if ingredients.isEmpty {
                    EmptyState(
                        systemImage: "carrot",
                        title: "Library is empty",
                        message: "Add ingredients in the Ingredients tab first."
                    )
                } else {
                    List(ingredients, id: \.ingredientID) { item in
                        Button {
                            if selected.contains(item.ingredientID) {
                                selected.remove(item.ingredientID)
                            } else {
                                selected.insert(item.ingredientID)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayLine)
                                        .font(AppTheme.body)
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                                Spacer()
                                if selected.contains(item.ingredientID) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.secondaryBrown)
                                }
                            }
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("From library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let lines = ingredients
                            .filter { selected.contains($0.ingredientID) }
                            .map(\.displayLine)
                        onPick(lines)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(selected.isEmpty ? AppTheme.tertiaryText : AppTheme.secondaryBrown)
                    .disabled(selected.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    IngredientsLibraryView()
        .modelContainer(PersistenceController.preview)
}
