//
//  RecipeDetailView.swift
//  CookieNotes
//

import PhotosUI
import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ads = AdMobController.shared

    let recipe: Recipe
    @State private var isEditing = false
    @State private var cookMode = false
    @State private var cookStep = 0
    @State private var name = ""
    @State private var ingredients: [EditableLine] = []
    @State private var instructions: [EditableLine] = []
    @State private var notes = ""
    @State private var source = ""
    @State private var prepTime = 0
    @State private var cookTime = 0
    @State private var servings = 0
    @State private var category: RecipeCategory = .uncategorized
    @State private var coverIconID = ""
    @State private var usesCategoryCover = false
    @State private var removedPhotoIDs: Set<UUID> = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var viewerData: [Data]?
    @State private var viewerIndex = 0
    @State private var showingDeleteAlert = false
    @State private var showingIngredientPicker = false
    @State private var illustrationTargetID: UUID?
    @State private var saveError: String?

    init(recipe: Recipe) {
        self.recipe = recipe
        _name = State(initialValue: recipe.name)
        _ingredients = State(initialValue: Self.lines(from: recipe))
        _instructions = State(
            initialValue: RecipeSanitizer.cleanInstructions(recipe.instructions, recipeName: recipe.name)
                .map { EditableLine(text: $0) }
        )
        _notes = State(initialValue: recipe.notes)
        _source = State(initialValue: recipe.source)
        _prepTime = State(initialValue: recipe.prepTime)
        _cookTime = State(initialValue: recipe.cookTime)
        _servings = State(initialValue: recipe.servings)
        _category = State(initialValue: recipe.category)
        _coverIconID = State(initialValue: recipe.coverIconID)
        _usesCategoryCover = State(initialValue: recipe.usesCategoryCover)
    }

    private static func lines(from recipe: Recipe) -> [EditableLine] {
        recipe.ingredients.enumerated().map { index, text in
            EditableLine(text: text, iconID: recipe.iconID(forIngredientIndex: index))
        }
    }

    private var visibleExistingPhotos: [RecipePhoto] {
        recipe.sortedPhotos.filter { !removedPhotoIDs.contains($0.photoID) }
    }

    private var photoCount: Int {
        visibleExistingPhotos.count + pendingPhotos.count
    }

    private struct DisplayRow: Identifiable {
        let id: String
        let index: Int
        let text: String
    }

    private var displayInstructions: [String] {
        let cleaned = RecipeSanitizer.cleanInstructions(recipe.instructions, recipeName: recipe.name)
        if AppLanguageManager.shared.activeLanguage == .french {
            return cleaned.map { RecipeTranslator.translateInstruction($0) }
        }
        return cleaned
    }

    private var displayIngredientRows: [DisplayRow] {
        let items = AppLanguageManager.shared.activeLanguage == .french
            ? recipe.ingredients.map { RecipeTranslator.translateIngredient($0) }
            : recipe.ingredients
        return items.enumerated().map { idx, text in
            DisplayRow(id: "ing-\(idx)-\(text)", index: idx, text: text)
        }
    }

    private var displayInstructionRows: [DisplayRow] {
        displayInstructions.enumerated().map { idx, step in
            DisplayRow(id: "step-\(idx)-\(step.prefix(24))", index: idx, text: step)
        }
    }

    private var sanitizedDraft: RecipeDraft {
        RecipeSanitizer.clean(
            RecipeDraft(
                name: name,
                ingredients: ingredients.map(\.text),
                instructions: instructions.map(\.text),
                notes: notes,
                source: source
            )
        )
    }

    private var nonEmptyIngredientLines: [EditableLine] {
        ingredients.filter {
            !$0.text.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }

    private var hasChanges: Bool {
        let draft = sanitizedDraft
        let existingIcons = recipe.ingredients.indices.map { recipe.iconID(forIngredientIndex: $0) }
        return draft.name != recipe.name
            || draft.ingredients != recipe.ingredients
            || draft.instructions != recipe.instructions
            || draft.notes != recipe.notes
            || draft.source != recipe.source
            || RecipeSanitizer.minutes(prepTime) != recipe.prepTime
            || RecipeSanitizer.minutes(cookTime) != recipe.cookTime
            || RecipeSanitizer.servings(servings) != recipe.servings
            || category != recipe.category
            || coverIconID != recipe.coverIconID
            || usesCategoryCover != recipe.usesCategoryCover
            || Array(nonEmptyIngredientLines.map(\.iconID).prefix(draft.ingredients.count)) != existingIcons
            || !removedPhotoIDs.isEmpty
            || !pendingPhotos.isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if cookMode {
                RecipeCookModeView(
                    steps: displayInstructions,
                    coverElements: recipe.resolvedCoverElements,
                    cookStep: $cookStep,
                    cookMode: $cookMode
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                        if isEditing {
                            editor
                        } else {
                            reader
                        }
                        if !isEditing && AdPlacement.showsContentBanner(adsEnabled: ads.canPresentAds, hasContent: true) {
                            AdvertisementSlot(placementID: "detail-\(recipe.recipeID.uuidString)")
                        }
                    }
                    .padding(AppTheme.paddingMedium)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle(isEditing ? String.localized("Edit Recipe") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert(String.localized("Delete Recipe"), isPresented: $showingDeleteAlert) {
            Button(String.localized("Cancel"), role: .cancel) {}
            Button(String.localized("Delete"), role: .destructive, action: deleteRecipe)
        } message: {
            Text(String.localized("Delete %@? This can't be undone.", recipe.name))
        }
        .alert(String.localized("Couldn't save"), isPresented: saveAlertPresented) {
            Button(String.localized("OK"), role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .sheet(isPresented: viewerPresented) {
            PhotoViewerView(photos: viewerData ?? [], selectedIndex: viewerIndex)
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
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: recipe.isFavorite)
        .preferredColorScheme(.dark)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                HStack {
                    Button(String.localized("Cancel"), action: cancelEditing)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    Button(String.localized("Save"), action: saveChanges)
                        .fontWeight(.semibold)
                        .foregroundStyle(hasChanges && !sanitizedDraft.name.isEmpty ? AppTheme.burntOrange : AppTheme.tertiaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .disabled(!hasChanges || sanitizedDraft.name.isEmpty)
                }
            } else if cookMode {
                Button(String.localized("Done")) { cookMode = false }
                    .foregroundStyle(AppTheme.burntOrange)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            } else {
                HStack(spacing: 2) {
                    Button {
                        recipe.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(AppTheme.burntOrange)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(recipe.isFavorite ? String.localized("Remove favorite") : String.localized("Add favorite"))

                    ShareLink(item: recipe.shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel(String.localized("Share recipe"))

                    Button(String.localized("Edit")) { beginEditing() }
                        .foregroundStyle(AppTheme.burntOrange)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())

                    Menu {
                        Button(String.localized("Cook Mode")) {
                            cookStep = 0
                            cookMode = true
                        }
                        Button(String.localized("Delete"), role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel(String.localized("More options"))
                }
            }
        }
    }

    private var saveAlertPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private var viewerPresented: Binding<Bool> {
        Binding(get: { viewerData != nil }, set: { if !$0 { viewerData = nil } })
    }

    private var reader: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
            ZStack(alignment: .bottomLeading) {
                if let hero = visibleExistingPhotos.first?.imageData,
                   let image = LocalImageCache.image(for: hero, maxPixel: 1400) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()
                } else {
                    ZStack {
                        recipe.category.color.opacity(0.2)
                        FoodIconView(iconIDs: recipe.resolvedCoverElements, size: 140)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name)
                    .font(AppTheme.largeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 10) {
                    Label(recipe.formattedTotalTime, systemImage: "clock")
                    if let servings = recipe.formattedServings {
                        Label(servings, systemImage: "person.2")
                    }
                    Text(recipe.category.title)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(recipe.category.color.opacity(0.2))
                        .clipShape(Capsule())
                }
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 8) {
                TimeInfoView(title: String.localized("Prep"), time: recipe.prepTime)
                TimeInfoView(title: String.localized("Cook"), time: recipe.cookTime)
                TimeInfoView(title: String.localized("Total"), time: recipe.totalTime)
            }

            readSection(title: String.localized("Ingredients")) {
                ForEach(displayIngredientRows) { row in
                    let storedIcon = recipe.iconID(forIngredientIndex: row.index)
                    let iconID = storedIcon.isEmpty ? (IngredientCatalog.iconID(matching: row.text) ?? "") : storedIcon
                    HStack(spacing: 12) {
                        FoodIconView(iconID: iconID, size: 40)
                            .accessibilityHidden(true)
                        Text(row.text)
                            .font(AppTheme.body)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
            }

            readSection(title: String.localized("Instructions")) {
                ForEach(displayInstructionRows) { row in
                    HStack(alignment: .top, spacing: 10) {
                        Text(verbatim: "\(row.index + 1)")
                            .font(AppTheme.smallCaption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(AppTheme.burntOrange)
                            .clipShape(Circle())
                        Text(row.text)
                            .font(AppTheme.body)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if !recipe.notes.isEmpty {
                readSection(title: String.localized("Notes")) {
                    Text(recipe.notes)
                        .font(AppTheme.body)
                        .foregroundStyle(AppTheme.primaryText)
                }
            }

            if !recipe.source.isEmpty {
                readSection(title: String.localized("Source")) {
                    Text(recipe.source)
                        .font(AppTheme.body)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if !visibleExistingPhotos.isEmpty {
                photoGallery(editable: false)
            }

            Button {
                cookStep = 0
                cookMode = true
            } label: {
                Text(String.localized("Start cooking"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var editCoverElements: [String] {
        let dish: Set<RecipeCategory> = [.dinner, .dessert]
        if dish.contains(category),
           coverIconID == category.preferredCoverIconID || coverIconID.isEmpty {
            return category.coverElements
        }
        if coverIconID.isEmpty {
            return category.coverElements
        }
        return [coverIconID]
    }

    private var editCoverPreview: some View {
        let coverPhoto = visibleExistingPhotos.first?.thumbnailData
            ?? pendingPhotos.first?.stored.thumbnailData
        return HStack(spacing: 16) {
            Group {
                if let coverPhoto, let image = LocalImageCache.image(for: coverPhoto) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    FoodIconView(iconIDs: editCoverElements, size: 72)
                }
            }
            .frame(width: 88, height: 88)
            .background(AppTheme.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(coverPhoto == nil ? String.localized("Cover illustration") : String.localized("Cover photo"))
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(
                    coverPhoto == nil
                        ? String.localized("Shown when this recipe has no photos. Pick a category to choose the illustration.")
                        : String.localized("Your first photo is the cover. Remove all photos to use an illustration instead.")
                )
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .sectionSurface()
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
            RecipeFormSection(title: String.localized("Recipe Name")) {
                TextField(String.localized("Recipe name"), text: $name)
                    .textFieldStyle(CustomTextFieldStyle())
                    .font(AppTheme.title)
            }

            RecipeFormSection(title: String.localized("Category")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
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

            editCoverPreview

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
                NotesEditor(text: $notes, placeholder: String.localized("A tip or a memory"))
            }

            RecipeFormSection(title: String.localized("Source")) {
                TextField(String.localized("Optional link or where it came from"), text: $source)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            photoGallery(editable: true)
        }
    }

    private func readSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.accent)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .sectionSurface()
    }

    private func photoGallery(editable: Bool) -> some View {
        RecipeFormSection(title: String.localized("Photos")) {
            if editable {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(String.localized("Add Photo"), systemImage: "plus.circle.fill")
                        .foregroundStyle(AppTheme.burntOrange)
                        .frame(minHeight: 44)
                }
                .disabled(photoCount >= RecipeInputLimits.photoCount)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await addPhoto(newItem) }
                }
            }

            if photoCount == 0 {
                Text(String.localized("No photos yet"))
                    .foregroundStyle(AppTheme.tertiaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                    ForEach(visibleExistingPhotos, id: \.photoID) { photo in
                        let idx = visibleExistingPhotos.firstIndex(where: { $0.photoID == photo.photoID }) ?? 0
                        photoCell(imageData: photo.thumbnailData, index: idx, removableID: photo.photoID)
                    }
                    ForEach(pendingPhotos) { photo in
                        let idx = visibleExistingPhotos.count + (pendingPhotos.firstIndex(where: { $0.id == photo.id }) ?? 0)
                        photoCell(
                            imageData: photo.stored.thumbnailData,
                            index: idx,
                            removableID: nil,
                            pendingID: photo.id
                        )
                    }
                }
            }
        }
    }

    private var galleryData: [Data] {
        visibleExistingPhotos.map(\.imageData) + pendingPhotos.map(\.stored.imageData)
    }

    private func photoCell(imageData: Data, index: Int, removableID: UUID?, pendingID: UUID? = nil) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                viewerIndex = index
                viewerData = galleryData
            } label: {
                RecipeThumbnail(data: imageData)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(CardButtonStyle())
            .accessibilityLabel(String.localized("View photo %lld", index + 1))

            if isEditing {
                Button {
                    if let removableID { removedPhotoIDs.insert(removableID) }
                    if let pendingID { pendingPhotos.removeAll { $0.id == pendingID } }
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

    private func beginEditing() {
        name = recipe.name
        ingredients = Self.lines(from: recipe)
        if ingredients.isEmpty { ingredients = [] }
        let cleanedInstructions = RecipeSanitizer.cleanInstructions(recipe.instructions, recipeName: recipe.name)
        instructions = cleanedInstructions.isEmpty ? [EditableLine(text: "")] : cleanedInstructions.map { EditableLine(text: $0) }
        notes = recipe.notes
        source = recipe.source
        prepTime = recipe.prepTime
        cookTime = recipe.cookTime
        servings = recipe.servings
        category = recipe.category
        coverIconID = recipe.coverIconID
        usesCategoryCover = recipe.usesCategoryCover
        removedPhotoIDs.removeAll()
        pendingPhotos.removeAll()
        isEditing = true
    }

    private func cancelEditing() {
        removedPhotoIDs.removeAll()
        pendingPhotos.removeAll()
        isEditing = false
    }

    private func addPhoto(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }
        guard photoCount < RecipeInputLimits.photoCount else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let stored = PhotoProcessing.makeStoredPhoto(from: data) else {
            saveError = String.localized("That photo couldn't be read. Try a different one.")
            return
        }
        pendingPhotos.append(PendingPhoto(stored: stored))
    }

    private func saveChanges() {
        let draft = sanitizedDraft
        guard !draft.name.isEmpty else { return }
        recipe.name = draft.name
        recipe.ingredients = draft.ingredients
        recipe.instructions = draft.instructions
        recipe.notes = draft.notes
        recipe.source = draft.source
        recipe.prepTime = RecipeSanitizer.minutes(prepTime)
        recipe.cookTime = RecipeSanitizer.minutes(cookTime)
        recipe.servings = RecipeSanitizer.servings(servings)
        recipe.category = category
        recipe.coverIconID = coverIconID
        recipe.usesCategoryCover = usesCategoryCover
        recipe.syncIngredientIcons(from: {
            var lines = nonEmptyIngredientLines.map { line in
                EditableLine(
                    id: line.id,
                    text: line.text,
                    iconID: line.iconID.isEmpty ? (IngredientCatalog.iconID(matching: line.text) ?? "") : line.iconID
                )
            }
            while lines.count < draft.ingredients.count {
                lines.append(EditableLine(text: ""))
            }
            return Array(lines.prefix(draft.ingredients.count))
        }())
        recipe.dateModified = Date()

        for photo in recipe.sortedPhotos where removedPhotoIDs.contains(photo.photoID) {
            modelContext.delete(photo)
        }
        let remaining = recipe.sortedPhotos.filter { !removedPhotoIDs.contains($0.photoID) }
        for (index, photo) in remaining.enumerated() { photo.sortIndex = index }
        var nextIndex = remaining.count
        for pending in pendingPhotos {
            guard nextIndex < RecipeInputLimits.photoCount else { break }
            let photo = RecipePhoto(
                sortIndex: nextIndex,
                imageData: pending.stored.imageData,
                thumbnailData: pending.stored.thumbnailData
            )
            photo.recipe = recipe
            modelContext.insert(photo)
            nextIndex += 1
        }

        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
            removedPhotoIDs.removeAll()
            pendingPhotos.removeAll()
            isEditing = false
        } catch {
            saveError = String.localized("The recipe couldn't be saved. Try again.")
        }
    }

    private func deleteRecipe() {
        modelContext.delete(recipe)
        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
            dismiss()
        } catch {
            saveError = String.localized("The recipe couldn't be deleted. Try again.")
        }
    }
}

struct TimeInfoView: View {
    let title: String
    let time: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(AppTheme.smallCaption)
                .foregroundStyle(AppTheme.tertiaryText)
            Text(time == 0 ? String.localized("None") : RecipeTimeFormat.short(time))
                .font(AppTheme.headline)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct RecipeCookModeView: View {
    let steps: [String]
    let coverElements: [String]
    @Binding var cookStep: Int
    @Binding var cookMode: Bool

    var body: some View {
        VStack(spacing: AppTheme.paddingLarge) {
            ProgressView(value: Double(cookStep + 1), total: Double(max(steps.count, 1)))
                .tint(AppTheme.burntOrange)
                .padding(.horizontal)

            Spacer()

            if steps.indices.contains(cookStep) {
                FoodIconView(iconIDs: coverElements, size: 100)
                    .accessibilityHidden(true)
                Text(String.localized("Step %lld of %lld", cookStep + 1, steps.count))
                    .font(AppTheme.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accentAction)
                Text(steps[cookStep])
                    .font(AppTheme.title)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.paddingLarge)
            } else {
                Text(String.localized("You’re done!"))
                    .font(AppTheme.largeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                FoodIconView(iconID: "cupcake", size: 120)
                    .accessibilityHidden(true)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(String.localized("Previous")) {
                    cookStep = Swift.max(0, cookStep - 1)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(cookStep == 0)

                Button(cookStep >= steps.count - 1 ? String.localized("Finish") : String.localized("Next")) {
                    if cookStep >= steps.count - 1 {
                        cookMode = false
                    } else {
                        cookStep += 1
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .padding(.bottom, AppTheme.paddingLarge)
        }
        .sensoryFeedback(.selection, trigger: cookStep)
    }
}

struct PhotoViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [Data]
    // Seeded intentionally as initial page when modal opens.
    @State private var selectedIndex: Int

    private struct PhotoPage: Identifiable {
        let id: String
        let index: Int
        let data: Data
    }

    init(photos: [Data], selectedIndex: Int) {
        self.photos = photos
        _selectedIndex = State(initialValue: selectedIndex)
    }

    private var pages: [PhotoPage] {
        photos.enumerated().map { idx, data in
            PhotoPage(id: "photo-\(idx)-\(data.count)", index: idx, data: data)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selectedIndex) {
                ForEach(pages) { page in
                    if let image = UIImage(data: page.data) {
                        ZoomableImageView(image: image)
                            .tag(page.index)
                    }
                }
            }
            .tabViewStyle(.page)

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(String.localized("Close"))
                    .padding()
                }
                Spacer()
            }
        }
    }
}

struct ZoomableImageView: View {
    let image: UIImage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let delta = value.magnification / lastScale
                        lastScale = value.magnification
                        scale = min(max(scale * delta, 1), 4)
                    }
                    .onEnded { _ in lastScale = 1 }
            )
            .onTapGesture(count: 2) {
                let targetScale: CGFloat = scale > 1 ? 1 : 2
                if reduceMotion {
                    scale = targetScale
                } else {
                    withAnimation { scale = targetScale }
                }
            }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: RecipeMigration.showcaseFriedRice(isSample: false))
    }
    .modelContainer(PersistenceController.preview)
}
