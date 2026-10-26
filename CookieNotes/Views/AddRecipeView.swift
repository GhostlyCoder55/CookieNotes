//
//  AddRecipeView.swift
//  CookieNotes
//

import PhotosUI
import SwiftData
import SwiftUI

struct AddRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ingredients = [EditableLine(text: "")]
    @State private var instructions = [EditableLine(text: "")]
    @State private var notes = ""
    @State private var source = ""
    @State private var prepTime = 0
    @State private var cookTime = 0
    @State private var servings = 1
    @State private var category: RecipeCategory = .uncategorized
    @State private var coverIconID = "veggie_plate"
    @State private var usesCategoryCover = false
    @State private var photos: [PendingPhoto] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var viewerData: [Data]?
    @State private var viewerIndex = 0
    @State private var formError: String?
    @State private var showingIngredientPicker = false
    @State private var illustrationTargetID: UUID?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                        coverPicker

                        RecipeFormSection(title: "Recipe Name") {
                            TextField("Weeknight chili, banana bread…", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textInputAutocapitalization(.words)
                        }

                        categoryPicker
                        RecipeTimeRow(prepTime: $prepTime, cookTime: $cookTime, servings: $servings)

                        RecipeEditableLines(
                            title: "Ingredients",
                            addTitle: "Add",
                            placeholder: "Ingredient",
                            lines: $ingredients,
                            illustrated: true,
                            onPickIllustration: { lineID in
                                illustrationTargetID = lineID
                                showingIngredientPicker = true
                            }
                        )

                        RecipeEditableLines(
                            title: "Instructions",
                            addTitle: "Add Step",
                            placeholder: "Write the step…",
                            lines: $instructions,
                            numbered: true
                        )

                        RecipeFormSection(title: "Notes") {
                            NotesEditor(text: $notes)
                        }

                        RecipeFormSection(title: "Source") {
                            TextField("Optional link or where it came from", text: $source)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        photoSection
                    }
                    .padding(AppTheme.paddingMedium)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? AppTheme.burntOrange : AppTheme.tertiaryText)
                        .disabled(!canSave)
                }
            }
            .alert("Couldn't save", isPresented: formAlertPresented) {
                Button("OK", role: .cancel) { formError = nil }
            } message: {
                Text(formError ?? "")
            }
            .sheet(isPresented: $showingIngredientPicker) {
                IngredientPickerView { displayName, iconID in
                    if let target = illustrationTargetID,
                       let index = ingredients.firstIndex(where: { $0.id == target }) {
                        // Picker choice always fills name + illustration for that row.
                        ingredients[index].text = displayName
                        ingredients[index].iconID = iconID
                    } else {
                        ingredients.append(EditableLine(text: displayName, iconID: iconID))
                    }
                    illustrationTargetID = nil
                    if coverIconID.isEmpty || coverIconID == "veggie_plate" {
                        coverIconID = iconID
                    }
                }
            }
            .sheet(isPresented: viewerPresented) {
                PhotoViewerView(photos: viewerData ?? [], selectedIndex: viewerIndex)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var coverPreviewElements: [String] {
        let dish: Set<RecipeCategory> = [.dinner, .dessert, .snack]
        if dish.contains(category),
           coverIconID == category.preferredCoverIconID || coverIconID == "veggie_plate" {
            return category.coverElements
        }
        return [coverIconID]
    }

    private var coverPicker: some View {
        HStack(spacing: 16) {
            FoodIconView(iconIDs: coverPreviewElements, size: 88)
                .padding(8)
                .background(AppTheme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text("Cover illustration")
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("Uses your first illustrated ingredient, or pick a category vibe below.")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .sectionSurface()
    }

    private var categoryPicker: some View {
        RecipeFormSection(title: "Category") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RecipeCategory.allCases) { item in
                        ColorChip(title: item.title, selected: category == item) {
                            category = item
                            coverIconID = item.preferredCoverIconID
                            usesCategoryCover = true
                        }
                    }
                }
            }
        }
    }

    private var formAlertPresented: Binding<Bool> {
        Binding(get: { formError != nil }, set: { if !$0 { formError = nil } })
    }

    private var viewerPresented: Binding<Bool> {
        Binding(get: { viewerData != nil }, set: { if !$0 { viewerData = nil } })
    }

    private var photoSection: some View {
        RecipeFormSection(title: "Photos") {
            HStack {
                Text("\(photos.count) of \(RecipeInputLimits.photoCount)")
                    .font(AppTheme.smallCaption)
                    .foregroundStyle(AppTheme.tertiaryText)
                Spacer()
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Photo", systemImage: "plus.circle.fill")
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(photos.count >= RecipeInputLimits.photoCount ? AppTheme.tertiaryText : AppTheme.burntOrange)
                        .frame(minHeight: 44)
                }
                .disabled(photos.count >= RecipeInputLimits.photoCount)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await addPhoto(newItem) }
                }
            }

            if photos.isEmpty {
                Text("Optional dish photos")
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.tertiaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                viewerIndex = index
                                viewerData = photos.map(\.stored.imageData)
                            } label: {
                                if let image = photo.thumbnail {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                photos.removeAll { $0.id == photo.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppTheme.error)
                                    .background(Circle().fill(AppTheme.elevatedHighlight))
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addPhoto(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }
        guard photos.count < RecipeInputLimits.photoCount else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let stored = PhotoProcessing.makeStoredPhoto(from: data) else {
            formError = "That photo couldn't be read. Try a different one."
            return
        }
        photos.append(PendingPhoto(stored: stored))
    }

    private func saveRecipe() {
        let draft = RecipeSanitizer.clean(
            RecipeDraft(
                name: name,
                ingredients: ingredients.map(\.text),
                instructions: instructions.map(\.text),
                notes: notes,
                source: source
            )
        )
        guard !draft.name.isEmpty else { return }

        let icons: [String] = {
            var mapped = ingredients.map(\.iconID)
            while mapped.count < draft.ingredients.count { mapped.append("") }
            return Array(mapped.prefix(draft.ingredients.count))
        }()

        let recipe = Recipe(
            name: draft.name,
            ingredients: draft.ingredients,
            instructions: draft.instructions,
            notes: draft.notes,
            source: draft.source,
            prepTime: RecipeSanitizer.minutes(prepTime),
            cookTime: RecipeSanitizer.minutes(cookTime),
            servings: RecipeSanitizer.servings(servings),
            categoryRaw: category.rawValue,
            ingredientIconIDs: icons,
            coverIconID: coverIconID,
            usesCategoryCover: usesCategoryCover
        )
        modelContext.insert(recipe)
        for (index, photo) in photos.prefix(RecipeInputLimits.photoCount).enumerated() {
            let stored = RecipePhoto(
                sortIndex: index,
                imageData: photo.stored.imageData,
                thumbnailData: photo.stored.thumbnailData
            )
            stored.recipe = recipe
            modelContext.insert(stored)
        }

        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
            dismiss()
        } catch {
            formError = "The recipe couldn't be saved. Try again."
        }
    }
}

struct PendingPhoto: Identifiable {
    let id = UUID()
    let stored: StoredPhoto
    var thumbnail: UIImage? { UIImage(data: stored.thumbnailData) }
}

#Preview {
    AddRecipeView()
        .modelContainer(PersistenceController.preview)
}
