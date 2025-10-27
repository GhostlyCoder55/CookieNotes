//
//  RecipeManager.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import Foundation
import SwiftUI

class RecipeManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    
    private let userDefaults = UserDefaults.standard
    private let recipesKey = "saved_recipes"
    
    // Notification manager reference for activity tracking
    weak var notificationManager: NotificationManager?
    
    init() {
        loadRecipes()
    }
    
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
    }
    
    func addRecipe(_ recipe: Recipe) {
        recipes.append(recipe)
        saveRecipes()
        markUserAsActive()
    }
    
    func updateRecipe(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            var updatedRecipe = recipe
            updatedRecipe.dateModified = Date()
            recipes[index] = updatedRecipe
            saveRecipes()
            markUserAsActive()
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        saveRecipes()
        markUserAsActive()
    }
    
    func searchRecipes(query: String) -> [Recipe] {
        if query.isEmpty {
            return recipes
        }
        
        return recipes.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(query) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    private func saveRecipes() {
        if let encoded = try? JSONEncoder().encode(recipes) {
            userDefaults.set(encoded, forKey: recipesKey)
        }
    }
    
    private func loadRecipes() {
        if let data = userDefaults.data(forKey: recipesKey),
           let decoded = try? JSONDecoder().decode([Recipe].self, from: data) {
            recipes = decoded
        } else {
            // Add some sample recipes for demo
            addSampleRecipes()
        }
    }
    
    private func addSampleRecipes() {
        let sampleRecipes = [
            Recipe(
                name: "Simple Chicken Masala",
                ingredients: ["1 lb chicken breast", "1 onion", "2 cloves garlic", "1 inch ginger", "2 tomatoes", "1 cup yogurt", "2 tbsp garam masala", "1 tbsp turmeric", "1 tbsp cumin", "Salt to taste", "2 tbsp oil"],
                instructions: ["Cut chicken into bite-sized pieces", "Heat oil in pan over medium heat", "Add diced onions and cook until golden", "Add minced garlic and ginger, cook for 2 minutes", "Add spices and cook until fragrant", "Add chicken and cook for 5 minutes", "Add chopped tomatoes and yogurt", "Simmer for 15 minutes until chicken is cooked", "Serve with rice or naan"],
                prepTime: 15,
                cookTime: 25
            )
        ]
        
        for recipe in sampleRecipes {
            recipes.append(recipe)
        }
        saveRecipes()
    }
    
    private func markUserAsActive() {
        notificationManager?.markUserAsActive()
    }
}
