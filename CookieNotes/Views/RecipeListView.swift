//
//  RecipeListView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var showingAddRecipe = false
    @State private var selectedRecipe: Recipe?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                if recipeManager.recipes.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: AppTheme.paddingMedium) {
                            ForEach(recipeManager.recipes) { recipe in
                                RecipeCard(recipe: recipe) {
                                    selectedRecipe = recipe
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .padding(.horizontal, AppTheme.paddingMedium)
                        .padding(.top, AppTheme.paddingMedium)
                    }
                }
            }
            .navigationTitle("My Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRecipe = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.secondaryBrown)
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                AddRecipeView()
                    .environmentObject(recipeManager)
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
                    .environmentObject(recipeManager)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
                // Recipe Icon
                HStack {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(AppTheme.secondaryBrown)
                    Spacer()
                    Text(recipe.formattedTotalTime)
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.tertiaryText)
                }
                
                // Recipe Name
                Text(recipe.name)
                    .font(AppTheme.headline)
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Ingredients Preview
                if !recipe.ingredients.isEmpty {
                    Text(recipe.ingredients.prefix(2).joined(separator: ", "))
                        .font(AppTheme.smallCaption)
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Date Created
                Text(recipe.dateCreated, style: .date)
                    .font(AppTheme.smallCaption)
                    .foregroundColor(AppTheme.tertiaryText)
            }
            .padding(AppTheme.paddingMedium)
            .frame(height: 140)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(AppTheme.surfaceBackground, lineWidth: 1)
            )
            .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: AppTheme.paddingLarge) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.secondaryBrown)
            
            Text("No Recipes Yet")
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
            
            Text("Start building your personal cooking journal by adding your first recipe!")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.paddingLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RecipeListView()
        .environmentObject(RecipeManager())
}
