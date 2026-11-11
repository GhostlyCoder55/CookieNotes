//
//  GroceryListView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI

struct GroceryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \GroceryItem.sortOrder, order: .forward) private var items: [GroceryItem]
    @AppStorage(GrocerySort.defaultsKey) private var sortRaw = GrocerySort.defaultOrder.rawValue

    @State private var showingAddSheet = false
    @State private var showingClearConfirmation = false
    @State private var editingItem: GroceryItem?
    @State private var editedItemName = ""
    @State private var saveError: String?
    @State private var toggleFeedbackTrigger = false

    private var sort: GrocerySort {
        GrocerySort(rawValue: sortRaw) ?? .defaultOrder
    }

    private var displayedItems: [GroceryItem] {
        GroceryListLogic.sorted(items, by: sort)
    }

    private var saveAlertPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private var editAlertPresented: Binding<Bool> {
        Binding(
            get: { editingItem != nil },
            set: {
                if !$0 {
                    editingItem = nil
                    editedItemName = ""
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if displayedItems.isEmpty {
                    GeometryReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                controlsBar
                                    .padding(.horizontal, AppTheme.paddingMedium)
                                    .padding(.top, 4)
                                    .padding(.bottom, AppTheme.paddingSmall)

                                Spacer(minLength: 24)

                                EmptyState(
                                    systemImage: "checklist",
                                    title: String.localized("Your list is empty"),
                                    message: String.localized("Tap + below to add groceries to your list.")
                                )
                                .padding(.horizontal, AppTheme.paddingLarge)

                                Spacer(minLength: 96)
                            }
                            .frame(minHeight: proxy.size.height)
                        }
                        .softTopScrollEdgeEffect()
                    }
                } else {
                    List {
                        controlsBar
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(
                                EdgeInsets(
                                    top: 4,
                                    leading: AppTheme.paddingMedium,
                                    bottom: AppTheme.paddingSmall,
                                    trailing: AppTheme.paddingMedium
                                )
                            )

                        ForEach(displayedItems, id: \.itemID) { item in
                            GroceryItemRow(item: item) {
                                toggleItem(item)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(
                                EdgeInsets(
                                    top: 4,
                                    leading: AppTheme.paddingMedium,
                                    bottom: 4,
                                    trailing: AppTheme.paddingMedium
                                )
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Label(String.localized("Delete"), systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    beginEditing(item)
                                } label: {
                                    Label(String.localized("Edit"), systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Label(String.localized("Delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.bottom, 96, for: .scrollContent)
                    .softTopScrollEdgeEffect()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                bottomArea
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle(String.localized("List"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAddSheet) {
                AddGrocerySheet { newName in
                    addItem(named: newName)
                }
                .presentationDetents([.height(210)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.parchment)
            }
            .background(
                Color.clear
                    .alert(String.localized("Clear list?"), isPresented: $showingClearConfirmation) {
                        Button(String.localized("Delete all"), role: .destructive) {
                            clearAllItems()
                        }
                        Button(String.localized("Cancel"), role: .cancel) {}
                    } message: {
                        Text(String.localized("All items on your grocery list will be deleted."))
                    }
                    .tint(AppTheme.secondaryText)
            )
            .alert(String.localized("Edit item"), isPresented: editAlertPresented) {
                TextField(String.localized("Grocery item"), text: $editedItemName)
                Button(String.localized("Cancel"), role: .cancel) {
                    editingItem = nil
                    editedItemName = ""
                }
                Button(String.localized("Save")) {
                    commitEdit()
                }
            }
            .alert(String.localized("Couldn't save"), isPresented: saveAlertPresented) {
                Button(String.localized("OK"), role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .sensoryFeedback(.selection, trigger: toggleFeedbackTrigger)
        }
        .preferredColorScheme(.dark)
    }

    private var controlsBar: some View {
        HStack(spacing: 10) {
            Menu {
                Picker(String.localized("Sort"), selection: $sortRaw) {
                    ForEach(GrocerySort.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(String.localized("Sort"))
                }
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(AppTheme.burntOrange.opacity(0.22), lineWidth: 1)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(String.localized("Sort list"))
            .accessibilityIdentifier("grocery-sort-button")
            .tint(AppTheme.burntOrange)
            .sensoryFeedback(.selection, trigger: sortRaw)

            Button {
                showingClearConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text(String.localized("Clear"))
                }
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(items.isEmpty ? AppTheme.tertiaryText.opacity(0.65) : AppTheme.tomatoRed)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(items.isEmpty ? AppTheme.cardBackground.opacity(0.45) : AppTheme.tomatoRed.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        items.isEmpty ? AppTheme.separator.opacity(0.5) : AppTheme.tomatoRed.opacity(0.4),
                        lineWidth: 1
                    )
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(items.isEmpty)
            .accessibilityLabel(String.localized("Clear list"))
            .accessibilityIdentifier("grocery-clear-button")

            Spacer(minLength: 0)
        }
    }

    private var bottomArea: some View {
        Button {
            showingAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(AppTheme.burntOrange)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(FloatingAddButtonStyle())
        .accessibilityLabel(String.localized("Add grocery"))
        .accessibilityIdentifier("add-grocery-button")
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    @discardableResult
    private func addItem(named rawName: String) -> Bool {
        let cleaned = GroceryListLogic.sanitizeName(rawName)
        guard !cleaned.isEmpty else { return false }

        let existingItems = (try? modelContext.fetch(FetchDescriptor<GroceryItem>())) ?? items
        let newItem = GroceryItem(
            name: cleaned,
            sortOrder: GroceryListLogic.nextSortOrder(in: existingItems)
        )
        modelContext.insert(newItem)
        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
            return true
        } catch {
            modelContext.delete(newItem)
            saveError = String.localized("The grocery item couldn't be saved. Try again.")
            return false
        }
    }

    private func toggleItem(_ item: GroceryItem) {
        let previousState = item.isChecked
        let previousModified = item.dateModified
        let applyToggle = {
            item.isChecked.toggle()
            item.dateModified = Date()
        }
        if reduceMotion {
            applyToggle()
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                applyToggle()
            }
        }
        do {
            try modelContext.save()
            toggleFeedbackTrigger.toggle()
            NotificationManager.shared.markUserAsActive()
        } catch {
            item.isChecked = previousState
            item.dateModified = previousModified
            saveError = String.localized("The list couldn't be updated. Try again.")
        }
    }

    private func beginEditing(_ item: GroceryItem) {
        editingItem = item
        editedItemName = item.name
    }

    private func commitEdit() {
        guard let item = editingItem else { return }
        let cleaned = GroceryListLogic.sanitizeName(editedItemName)
        editingItem = nil
        editedItemName = ""
        guard !cleaned.isEmpty, cleaned != item.name else { return }

        let previousName = item.name
        let previousModified = item.dateModified
        item.name = cleaned
        item.dateModified = Date()
        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
        } catch {
            item.name = previousName
            item.dateModified = previousModified
            saveError = String.localized("The grocery item couldn't be saved. Try again.")
        }
    }

    private func deleteItem(_ item: GroceryItem) {
        modelContext.delete(item)
        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
        } catch {
            saveError = String.localized("The list couldn't be updated. Try again.")
        }
    }

    private func clearAllItems() {
        guard !items.isEmpty else { return }
        for item in items {
            modelContext.delete(item)
        }
        do {
            try modelContext.save()
            NotificationManager.shared.markUserAsActive()
        } catch {
            saveError = String.localized("The list couldn't be updated. Try again.")
        }
    }
}

private struct GroceryItemRow: View {
    let item: GroceryItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(item.isChecked ? AppTheme.burntOrange : Color.clear)
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    item.isChecked ? AppTheme.burntOrange : AppTheme.secondaryText.opacity(0.75),
                                    lineWidth: 1.75
                                )
                        )

                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .accessibilityHidden(true)

                Text(item.name)
                    .font(AppTheme.body)
                    .foregroundStyle(item.isChecked ? AppTheme.tertiaryText : AppTheme.primaryText)
                    .strikethrough(item.isChecked, color: AppTheme.tertiaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("grocery-item-row")
        .accessibilityLabel(item.name)
        .accessibilityValue(item.isChecked ? String.localized("Checked") : String.localized("Unchecked"))
        .accessibilityHint(item.isChecked ? String.localized("Double tap to uncheck") : String.localized("Double tap to check off"))
    }
}

private struct AddGrocerySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var itemText = ""
    @State private var lastAddedName: String?
    @State private var addedTrigger = false
    @FocusState private var isFieldFocused: Bool

    var onAdd: (String) -> Bool

    private var trimmedText: String {
        GroceryListLogic.sanitizeName(itemText)
    }

    private var canSubmit: Bool {
        !trimmedText.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String.localized("Add grocery"))
                    .font(AppTheme.headline)
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button(String.localized("Done")) {
                    dismiss()
                }
                .font(AppTheme.headline)
                .foregroundStyle(AppTheme.burntOrange)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("add-grocery-done-button")
            }

            HStack(spacing: 12) {
                TextField(String.localized("Add grocery item…"), text: $itemText)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($isFieldFocused)
                    .onSubmit {
                        submitFromKeyboard()
                    }
                    .accessibilityIdentifier("add-grocery-textfield")

                Button {
                    submitItem()
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 48, height: 48)
                        .background(canSubmit ? AppTheme.burntOrange : AppTheme.burntOrange.opacity(0.45))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(FloatingAddButtonStyle())
                .disabled(!canSubmit)
                .accessibilityLabel(String.localized("Add item"))
                .accessibilityIdentifier("add-grocery-submit-button")
            }

            Text(lastAddedName.map { String.localized("Added %@", $0) } ?? " ")
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .opacity(lastAddedName == nil ? 0 : 1)
                .lineLimit(1)
                .accessibilityIdentifier("add-grocery-feedback")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.paddingMedium)
        .padding(.top, 18)
        .padding(.bottom, AppTheme.paddingSmall)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.parchment.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: addedTrigger)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                isFieldFocused = true
            }
        }
    }

    private func submitItem() {
        let cleaned = trimmedText
        guard !cleaned.isEmpty else { return }
        if onAdd(cleaned) {
            lastAddedName = cleaned
            itemText = ""
            addedTrigger.toggle()
        }
    }

    private func submitFromKeyboard() {
        if canSubmit {
            submitItem()
            Task { @MainActor in
                await Task.yield()
                isFieldFocused = true
            }
        } else {
            dismiss()
        }
    }
}

private struct FloatingAddButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    GroceryListView()
        .modelContainer(PersistenceController.preview)
}
