//
//  AddRecipeView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct AddRecipeView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var ingredients = [""]
    @State private var instructions = [""]
    @State private var prepTime = 0
    @State private var cookTime = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.paddingLarge) {
                        // Recipe Name
                        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
                            Text("Recipe Name")
                                .font(AppTheme.headline)
                                .foregroundColor(AppTheme.primaryText)
                            
                            TextField("Enter recipe name", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Time Section
                        HStack(spacing: AppTheme.paddingMedium) {
                            TimeInputView(title: "Prep Time", value: $prepTime)
                            TimeInputView(title: "Cook Time", value: $cookTime)
                        }
                        
                        // Ingredients
                        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
                            HStack {
                                Text("Ingredients")
                                    .font(AppTheme.headline)
                                    .foregroundColor(AppTheme.primaryText)
                                Spacer()
                                Button("Add Ingredient") {
                                    ingredients.append("")
                                }
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.secondaryBrown)
                            }
                            
                            ForEach(ingredients.indices, id: \.self) { index in
                                HStack {
                                    TextField("Ingredient \(index + 1)", text: $ingredients[index])
                                        .textFieldStyle(CustomTextFieldStyle())
                                    
                                    if ingredients.count > 1 {
                                        Button(action: { removeIngredient(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
                            HStack {
                                Text("Instructions")
                                    .font(AppTheme.headline)
                                    .foregroundColor(AppTheme.primaryText)
                                Spacer()
                                Button("Add Step") {
                                    instructions.append("")
                                }
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.secondaryBrown)
                            }
                            
                            ForEach(instructions.indices, id: \.self) { index in
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(AppTheme.body)
                                        .foregroundColor(AppTheme.secondaryBrown)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    TextField("Step \(index + 1)", text: $instructions[index], axis: .vertical)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .lineLimit(3...6)
                                    
                                    if instructions.count > 1 {
                                        Button(action: { removeInstruction(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                        
                    }
                    .padding(AppTheme.paddingMedium)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .foregroundColor(AppTheme.secondaryBrown)
                    .disabled(name.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func removeIngredient(at index: Int) {
        ingredients.remove(at: index)
    }
    
    private func removeInstruction(at index: Int) {
        instructions.remove(at: index)
    }
    
    private func saveRecipe() {
        let filteredIngredients = ingredients.filter { !$0.isEmpty }
        let filteredInstructions = instructions.filter { !$0.isEmpty }
        
        let recipe = Recipe(
            name: name,
            ingredients: filteredIngredients,
            instructions: filteredInstructions,
            prepTime: prepTime,
            cookTime: cookTime
        )
        
        recipeManager.addRecipe(recipe)
        dismiss()
    }
}

struct TimeInputView: View {
    let title: String
    @Binding var value: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
            Text(title)
                .font(AppTheme.body)
                .foregroundColor(AppTheme.primaryText)
            
            HStack {
                Button(action: { if value > 0 { value -= 5 } }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(AppTheme.secondaryBrown)
                }
                .disabled(value <= 0)
                
                Text("\(value) min")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)
                    .frame(width: 60, alignment: .center)
                
                Button(action: { value += 5 }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(AppTheme.secondaryBrown)
                }
            }
            .padding(.horizontal, AppTheme.paddingSmall)
            .padding(.vertical, AppTheme.paddingSmall)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusSmall)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusSmall)
            .foregroundColor(AppTheme.primaryText)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(AppTheme.surfaceBackground, lineWidth: 1)
            )
    }
}

#Preview {
    AddRecipeView()
        .environmentObject(RecipeManager())
}
