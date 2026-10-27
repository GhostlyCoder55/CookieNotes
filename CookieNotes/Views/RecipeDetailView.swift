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
        _instructions = State(initialValue: recipe.instructions.map { EditableLine(text: $0) })
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

    private var hasChanges: Bool {
        let draft = sanitizedDraft
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
            || ingredients.map(\.iconID) != recipe.ingredientIconIDs
            || !removedPhotoIDs.isEmpty
            || !pendingPhotos.isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if cookMode {
                cookModeView
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
        .navigationTitle(isEditing ? "Edit Recipe" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Delete Recipe", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteRecipe)
        } message: {
            Text("Delete \(recipe.name)? This can't be undone.")
        }
        .alert("Couldn't save", isPresented: saveAlertPresented) {
            Button("OK", role: .cancel) { saveError = nil }
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
        .preferredColorScheme(.dark)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                HStack {
                    Button("Cancel", action: cancelEditing)
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Save", action: saveChanges)
                        .fontWeight(.semibold)
                        .foregroundStyle(hasChanges && !sanitizedDraft.name.isEmpty ? AppTheme.burntOrange : AppTheme.tertiaryText)
                        .disabled(!hasChanges || sanitizedDraft.name.isEmpty)
                }
            } else if cookMode {
                Button("Done") { cookMode = false }
                    .foregroundStyle(AppTheme.burntOrange)
            } else {
                HStack(spacing: 2) {
                    Button {
                        recipe.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(AppTheme.burntOrange)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(recipe.isFavorite ? "Remove favorite" : "Add favorite")

                    ShareLink(item: recipe.shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .foregroundStyle(AppTheme.accent)

                    Button("Edit") { beginEditing() }
                        .foregroundStyle(AppTheme.burntOrange)

                    Menu {
                        Button("Cook Mode") {
                            cookStep = 0
                            cookMode = true
                        }
                        Button("Delete", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .foregroundStyle(AppTheme.accent)
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
                if !recipe.usesCategoryCover,
                   let hero = visibleExistingPhotos.first?.imageData,
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
                TimeInfoView(title: "Prep", time: recipe.prepTime)
                TimeInfoView(title: "Cook", time: recipe.cookTime)
                TimeInfoView(title: "Total", time: recipe.totalTime)
            }

            readSection(title: "Ingredients") {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(spacing: 12) {
                        FoodIconView(iconID: recipe.iconID(forIngredientIndex: index), size: 40)
                        Text(ingredient)
                            .font(AppTheme.body)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
            }

            readSection(title: "Instructions") {
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(AppTheme.smallCaption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(AppTheme.burntOrange)
                            .clipShape(Circle())
                        Text(instruction)
                            .font(AppTheme.body)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
            }

            if !recipe.notes.isEmpty {
                readSection(title: "Notes") {
                    Text(recipe.notes)
                        .font(AppTheme.body)
                        .foregroundStyle(AppTheme.primaryText)
                }
            }

            if !recipe.source.isEmpty {
                readSection(title: "Source") {
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
                Text("Start cooking")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var editCoverElements: [String] {
        let dish: Set<RecipeCategory> = [.dinner, .dessert, .snack]
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
        HStack(spacing: 16) {
            FoodIconView(iconIDs: editCoverElements, size: 72)
                .padding(8)
                .background(AppTheme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text("Cover illustration")
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(
                    usesCategoryCover
                        ? "Using the \(category.title) cover instead of the Discover photo."
                        : "Pick a category to switch the cover to that meal’s illustration."
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
            RecipeFormSection(title: "Recipe Name") {
                TextField("Recipe name", text: $name)
                    .textFieldStyle(CustomTextFieldStyle())
                    .font(AppTheme.title)
            }

            RecipeFormSection(title: "Category") {
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
                NotesEditor(text: $notes, placeholder: "A tip or a memory")
            }

            RecipeFormSection(title: "Source") {
                TextField("Optional link or where it came from", text: $source)
                    .textFieldStyle(CustomTextFieldStyle())
            }

            photoGallery(editable: true)
        }
    }

    private var cookModeView: some View {
        let steps = recipe.instructions
        return VStack(spacing: AppTheme.paddingLarge) {
            ProgressView(value: Double(cookStep + 1), total: Double(max(steps.count, 1)))
                .tint(AppTheme.burntOrange)
                .padding(.horizontal)

            Spacer()

            if steps.indices.contains(cookStep) {
                FoodIconView(iconIDs: recipe.resolvedCoverElements, size: 100)
                Text("Step \(cookStep + 1) of \(steps.count)")
                    .font(AppTheme.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accentAction)
                Text(steps[cookStep])
                    .font(AppTheme.title)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.paddingLarge)
            } else {
                Text("You’re done!")
                    .font(AppTheme.largeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                FoodIconView(iconID: "cupcake", size: 120)
            }

            Spacer()

            HStack(spacing: 16) {
                Button("Previous") {
                    cookStep = Swift.max(0, cookStep - 1)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(cookStep == 0)

                Button(cookStep >= steps.count - 1 ? "Finish" : "Next") {
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
    }

    private func readSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.accent)
            content()
        }
        .sectionSurface()
    }

    private func photoGallery(editable: Bool) -> some View {
        RecipeFormSection(title: "Photos") {
            if editable {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Photo", systemImage: "plus.circle.fill")
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
                Text("No photos yet")
                    .foregroundStyle(AppTheme.tertiaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                    ForEach(Array(visibleExistingPhotos.enumerated()), id: \.element.photoID) { index, photo in
                        photoCell(imageData: photo.thumbnailData, index: index, removableID: photo.photoID)
                    }
                    ForEach(Array(pendingPhotos.enumerated()), id: \.element.id) { index, photo in
                        photoCell(
                            imageData: photo.stored.thumbnailData,
                            index: visibleExistingPhotos.count + index,
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
            .buttonStyle(.plain)

            if isEditing {
                Button {
                    if let removableID { removedPhotoIDs.insert(removableID) }
                    if let pendingID { pendingPhotos.removeAll { $0.id == pendingID } }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.error)
                        .background(Circle().fill(AppTheme.elevatedHighlight))
                        .frame(width: 44, height: 44)
                }
            }
        }
    }

    private func beginEditing() {
        name = recipe.name
        ingredients = Self.lines(from: recipe)
        if ingredients.isEmpty { ingredients = [] }
        instructions = recipe.instructions.isEmpty ? [EditableLine(text: "")] : recipe.instructions.map { EditableLine(text: $0) }
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
            saveError = "That photo couldn't be read. Try a different one."
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
            var lines = ingredients
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
            saveError = "The recipe couldn't be saved. Try again."
        }
    }

    private func deleteRecipe() {
        modelContext.delete(recipe)
        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
            dismiss()
        } catch {
            saveError = "The recipe couldn't be deleted. Try again."
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
            Text(time == 0 ? "None" : RecipeTimeFormat.short(time))
                .font(AppTheme.headline)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PhotoViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [Data]
    @State private var selectedIndex: Int

    init(photos: [Data], selectedIndex: Int) {
        self.photos = photos
        _selectedIndex = State(initialValue: selectedIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selectedIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    if let image = UIImage(data: photos[index]) {
                        ZoomableImageView(image: image)
                            .tag(index)
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
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

struct ZoomableImageView: View {
    let image: UIImage
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
                withAnimation { scale = scale > 1 ? 1 : 2 }
            }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: RecipeMigration.showcaseFriedRice(isSample: false))
    }
    .modelContainer(PersistenceController.preview)
}
