//
//  RecipeDetailView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @Environment(\.dismiss) private var dismiss
    
    let recipe: Recipe
    @State private var isEditing = false
    @State private var editedRecipe: Recipe
    @State private var showingDeleteAlert = false
    
    init(recipe: Recipe) {
        self.recipe = recipe
        self._editedRecipe = State(initialValue: recipe)
    }
    
    private var currentRecipe: Recipe {
        isEditing ? editedRecipe : recipe
    }
    
    // Force UI updates when editing
    private var displayRecipe: Recipe {
        if isEditing {
            return editedRecipe
        } else {
            return recipe
        }
    }
    
    private var hasChanges: Bool {
        guard isEditing else { return false }
        return editedRecipe.name != recipe.name ||
               editedRecipe.ingredients != recipe.ingredients ||
               editedRecipe.instructions != recipe.instructions ||
               editedRecipe.prepTime != recipe.prepTime ||
               editedRecipe.cookTime != recipe.cookTime
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.paddingLarge) {
                        // Header Section
                        VStack(spacing: AppTheme.paddingMedium) {
                            // Recipe Icon and Name
                            HStack {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.secondaryBrown)
                                
                                VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
                                    if isEditing {
                                        TextField("Recipe Name", text: $editedRecipe.name)
                                            .font(AppTheme.largeTitle)
                                            .foregroundColor(AppTheme.primaryText)
                                            .textFieldStyle(CustomTextFieldStyle())
                                    } else {
                                        Text(displayRecipe.name)
                                            .font(AppTheme.largeTitle)
                                            .foregroundColor(AppTheme.primaryText)
                                    }
                                    
                                    Text("Created \(recipe.dateCreated, style: .date)")
                                        .font(AppTheme.caption)
                                        .foregroundColor(AppTheme.tertiaryText)
                                }
                                
                                Spacer()
                            }
                            
                            // Time Information
                            HStack(spacing: AppTheme.paddingLarge) {
                                TimeInfoView(title: "Prep", time: displayRecipe.prepTime, isEditing: isEditing, onTimeChange: { editedRecipe.prepTime = $0 })
                                
                                TimeInfoView(title: "Cook", time: displayRecipe.cookTime, isEditing: isEditing, onTimeChange: { editedRecipe.cookTime = $0 })
                                
                                TimeInfoView(title: "Total", time: displayRecipe.totalTime, isEditing: false, onTimeChange: { _ in })
                            }
                        }
                        .padding(AppTheme.paddingMedium)
                        .cardStyle()
                        
                        // Ingredients Section
                        VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
                            HStack {
                                Text("Ingredients")
                                    .font(AppTheme.title)
                                    .foregroundColor(AppTheme.primaryText)
                                Spacer()
                                if isEditing {
                                    Button("Add") {
                                        editedRecipe.ingredients.append("")
                                    }
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.secondaryBrown)
                                }
                            }
                            
                            if isEditing {
                                ForEach(editedRecipe.ingredients.indices, id: \.self) { index in
                                    HStack {
                                        TextField("Ingredient \(index + 1)", text: $editedRecipe.ingredients[index])
                                            .textFieldStyle(CustomTextFieldStyle())
                                        
                                        Button(action: { removeIngredient(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            } else {
                                ForEach(displayRecipe.ingredients, id: \.self) { ingredient in
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.secondaryBrown)
                                        Text(ingredient)
                                            .font(AppTheme.body)
                                            .foregroundColor(AppTheme.primaryText)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(AppTheme.paddingMedium)
                        .cardStyle()
                        
                        // Instructions Section
                        VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
                            HStack {
                                Text("Instructions")
                                    .font(AppTheme.title)
                                    .foregroundColor(AppTheme.primaryText)
                                Spacer()
                                if isEditing {
                                    Button("Add Step") {
                                        editedRecipe.instructions.append("")
                                    }
                                    .font(AppTheme.caption)
                                    .foregroundColor(AppTheme.secondaryBrown)
                                }
                            }
                            
                            if isEditing {
                                ForEach(editedRecipe.instructions.indices, id: \.self) { index in
                                    HStack(alignment: .top) {
                                        Text("\(index + 1).")
                                            .font(AppTheme.body)
                                            .foregroundColor(AppTheme.secondaryBrown)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        TextField("Step \(index + 1)", text: $editedRecipe.instructions[index], axis: .vertical)
                                            .textFieldStyle(CustomTextFieldStyle())
                                            .lineLimit(3...6)
                                        
                                        Button(action: { removeInstruction(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            } else {
                                ForEach(Array(displayRecipe.instructions.enumerated()), id: \.offset) { index, instruction in
                                    HStack(alignment: .top) {
                                        Text("\(index + 1).")
                                            .font(AppTheme.body)
                                            .foregroundColor(AppTheme.secondaryBrown)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        Text(instruction)
                                            .font(AppTheme.body)
                                            .foregroundColor(AppTheme.primaryText)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, AppTheme.paddingSmall)
                                }
                            }
                        }
                        .padding(AppTheme.paddingMedium)
                        .cardStyle()
                        
                    }
                    .padding(AppTheme.paddingMedium)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditing {
                            Button("Cancel") {
                                editedRecipe = recipe
                                isEditing = false
                            }
                            .foregroundColor(AppTheme.secondaryText)
                            
                            Button("Save") {
                                saveChanges()
                            }
                            .foregroundColor(AppTheme.secondaryBrown)
                            .disabled(!hasChanges)
                        } else {
                            Button("Edit") {
                                isEditing = true
                            }
                            .foregroundColor(AppTheme.secondaryBrown)
                            
                            Button("Delete") {
                                showingDeleteAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Delete Recipe", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    recipeManager.deleteRecipe(recipe)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete '\(recipe.name)'? This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func removeIngredient(at index: Int) {
        editedRecipe.ingredients.remove(at: index)
    }
    
    private func removeInstruction(at index: Int) {
        editedRecipe.instructions.remove(at: index)
    }
    
    private func saveChanges() {
        // Only save if there are actual changes
        guard hasChanges else { return }
        
        let filteredIngredients = editedRecipe.ingredients.filter { !$0.isEmpty }
        let filteredInstructions = editedRecipe.instructions.filter { !$0.isEmpty }
        
        editedRecipe.ingredients = filteredIngredients
        editedRecipe.instructions = filteredInstructions
        editedRecipe.dateModified = Date()
        
        recipeManager.updateRecipe(editedRecipe)
        isEditing = false
        
        // Dismiss the view and return to recipes page
        dismiss()
    }
}

struct TimeInfoView: View {
    let title: String
    let time: Int
    let isEditing: Bool
    let onTimeChange: (Int) -> Void
    
    var body: some View {
        VStack(spacing: AppTheme.paddingSmall) {
            Text(title)
                .font(AppTheme.caption)
                .foregroundColor(AppTheme.tertiaryText)
            
            if isEditing && title != "Total" {
                HStack {
                    Button(action: { if time > 0 { onTimeChange(time - 5) } }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(AppTheme.secondaryBrown)
                    }
                    .disabled(time <= 0)
                    
                    Text("\(time)")
                        .font(AppTheme.headline)
                        .foregroundColor(AppTheme.primaryText)
                        .frame(width: 40, alignment: .center)
                    
                    Button(action: { onTimeChange(time + 5) }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppTheme.secondaryBrown)
                    }
                }
            } else {
                Text("\(time) min")
                    .font(AppTheme.headline)
                    .foregroundColor(AppTheme.primaryText)
                    .frame(width: 60, alignment: .center)
            }
        }
        .padding(AppTheme.paddingSmall)
        .background(AppTheme.surfaceBackground)
        .cornerRadius(AppTheme.cornerRadiusSmall)
    }
}

#Preview {
    RecipeDetailView(recipe: Recipe(name: "Chocolate Chip Cookies", ingredients: ["2 cups flour", "1 cup butter"], instructions: ["Mix ingredients", "Bake at 375°F"]))
        .environmentObject(RecipeManager())
}
