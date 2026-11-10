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
    @State private var didSave = false

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

                        RecipeFormSection(title: String.localized("Recipe Name")) {
                            TextField(String.localized("Weeknight chili, banana bread…"), text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textInputAutocapitalization(.words)
                        }

                        categoryPicker
                        RecipeTimeRow(prepTime: $prepTime, cookTime: $cookTime, servings: $servings)

                        RecipeEditableLines(
                            title: String.localized("Ingredients"),
                            addTitle: String.localized("Add"),
                            placeholder: String.localized("Ingredient"),
                            lines: $ingredients,
                            illustrated: true,
                            onPickIllustration: { lineID in
                                illustrationTargetID = lineID
                                showingIngredientPicker = true
                            }
                        )

                        RecipeEditableLines(
                            title: String.localized("Instructions"),
                            addTitle: String.localized("Add Step"),
                            placeholder: String.localized("Write the step…"),
                            lines: $instructions,
                            numbered: true
                        )

                        RecipeFormSection(title: String.localized("Notes")) {
                            NotesEditor(text: $notes)
                        }

                        RecipeFormSection(title: String.localized("Source")) {
                            TextField(String.localized("Optional link or where it came from"), text: $source)
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
            .navigationTitle(String.localized("New Recipe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.localized("Cancel")) { dismiss() }
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.localized("Save")) { saveRecipe() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? AppTheme.burntOrange : AppTheme.tertiaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .disabled(!canSave)
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
            .alert(String.localized("Couldn't save"), isPresented: formAlertPresented) {
                Button(String.localized("OK"), role: .cancel) { formError = nil }
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
        let dish: Set<RecipeCategory> = [.dinner, .dessert]
        if dish.contains(category),
           coverIconID == category.preferredCoverIconID || coverIconID == "veggie_plate" {
            return category.coverElements
        }
        return [coverIconID]
    }

    private var coverPicker: some View {
        let coverImage = photos.first?.thumbnail
        return HStack(spacing: 16) {
            Group {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    FoodIconView(iconIDs: coverPreviewElements, size: 88)
                }
            }
            .frame(width: 104, height: 104)
            .background(AppTheme.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(coverImage == nil ? String.localized("Cover illustration") : String.localized("Cover photo"))
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(
                    coverImage == nil
                        ? String.localized("Shown when you haven’t added photos. Pick a category vibe below.")
                        : String.localized("Your first photo is the cover. Remove all photos to use an illustration instead.")
                )
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .sectionSurface()
    }

    private var categoryPicker: some View {
        RecipeFormSection(title: String.localized("Category")) {
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
        RecipeFormSection(title: String.localized("Photos")) {
            HStack {
                Text(String.localized("%lld of %lld", photos.count, RecipeInputLimits.photoCount))
                    .font(AppTheme.smallCaption)
                    .foregroundStyle(AppTheme.tertiaryText)
                Spacer()
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(String.localized("Add Photo"), systemImage: "plus.circle.fill")
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
                Text(String.localized("Optional dish photos"))
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.tertiaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                    ForEach(photos) { photo in
                        let index = photos.firstIndex(where: { $0.id == photo.id }) ?? 0
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
                            .buttonStyle(CardButtonStyle())
                            .accessibilityLabel(String.localized("View photo %lld", index + 1))

                            Button {
                                photos.removeAll { $0.id == photo.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppTheme.error)
                                    .background(Circle().fill(AppTheme.elevatedHighlight))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(String.localized("Remove photo"))
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
            formError = String.localized("That photo couldn't be read. Try a different one.")
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
            let nonEmptyLines = ingredients.filter {
                !$0.text.replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            }
            var mapped = nonEmptyLines.map { line in
                line.iconID.isEmpty ? (IngredientCatalog.iconID(matching: line.text) ?? "") : line.iconID
            }
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
            didSave.toggle()
            NotificationManager.shared.markUserAsActive()
            dismiss()
            // Show toast after the sheet settles so it doesn’t fight the dismiss animation.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(380))
                InAppToast.shared.showRecipeAdded()
            }
        } catch {
            formError = String.localized("The recipe couldn't be saved. Try again.")
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
