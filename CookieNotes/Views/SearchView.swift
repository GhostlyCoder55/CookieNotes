//
//  SearchView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var searchText = ""
    @State private var selectedRecipe: Recipe?
    
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipeManager.recipes
        }
        
        return recipeManager.recipes.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Header
                    VStack(spacing: AppTheme.paddingMedium) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppTheme.tertiaryText)
                            
                            TextField("Search recipes...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(AppTheme.primaryText)
                                .font(AppTheme.body)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppTheme.tertiaryText)
                                }
                            }
                        }
                        .padding(AppTheme.paddingMedium)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                .stroke(AppTheme.surfaceBackground, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, AppTheme.paddingMedium)
                    .padding(.top, AppTheme.paddingSmall)
                    
                    // Results
                    if filteredRecipes.isEmpty {
                        EmptySearchView(searchText: searchText)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppTheme.paddingMedium) {
                                ForEach(filteredRecipes) { recipe in
                                    SearchResultCard(recipe: recipe) {
                                        selectedRecipe = recipe
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, AppTheme.paddingMedium)
                            .padding(.top, AppTheme.paddingMedium)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
                    .environmentObject(recipeManager)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SearchResultCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.paddingMedium) {
                // Recipe Icon
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundColor(AppTheme.secondaryBrown)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.surfaceBackground)
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                
                // Recipe Info
                VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
                    Text(recipe.name)
                        .font(AppTheme.headline)
                        .foregroundColor(AppTheme.primaryText)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(recipe.formattedTotalTime)
                            .font(AppTheme.caption)
                            .foregroundColor(AppTheme.tertiaryText)
                        
                        if !recipe.ingredients.isEmpty {
                            Text("•")
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.tertiaryText)
                            
                            Text("\(recipe.ingredients.count) ingredients")
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.tertiaryText)
                        }
                    }
                    
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.tertiaryText)
            }
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(AppTheme.surfaceBackground, lineWidth: 1)
            )
            .shadow(color: AppTheme.cardShadow, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptySearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: AppTheme.paddingLarge) {
            Image(systemName: searchText.isEmpty ? "magnifyingglass" : "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.secondaryBrown)
            
            Text(searchText.isEmpty ? "Search Your Recipes" : "No Results Found")
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
            
            Text(searchText.isEmpty ? 
                 "Use the search bar above to find recipes by name, ingredients, or notes." :
                 "Try searching with different keywords or check your spelling.")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.paddingLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SearchView()
        .environmentObject(RecipeManager())
}
