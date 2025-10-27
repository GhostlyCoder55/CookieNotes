//
//  AboutView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.paddingLarge) {
                        // Header
                        VStack(spacing: AppTheme.paddingMedium) {
                            Text("CookieNotes")
                                .font(AppTheme.largeTitle)
                                .foregroundColor(AppTheme.primaryText)
                            
                            Text("Your Personal Cooking Journal")
                                .font(AppTheme.headline)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        .padding(.top, AppTheme.paddingLarge)
                        
                        // Note Cards
                        VStack(spacing: AppTheme.paddingMedium) {
                            NoteCard(
                                title: "What is CookieNotes?",
                                content: "CookieNotes is your digital recipe collection. A modern space where you can save, organize, and treasure your personal recipes. Think of it as your personal cooking journal that's always with you."
                            )
                            
                            NoteCard(
                                title: "Why I Built This",
                                content: "Christopher Ogbonnaya wanted to create something that feels like flipping through a digital cookbook. Every recipe tells a story, and CookieNotes helps you preserve those stories."
                            )
                            
                            NoteCard(
                                title: "Features",
                                content: "• Add and edit your personal recipes\n• Search by name, ingredients, or notes\n• Organize with prep and cook times\n• Add special notes and tips\n• Beautiful, minimal interface\n• Smooth animations and transitions"
                            )

                            
                            NoteCard(
                                title: "Tips for Getting Started",
                                content: "• Start by adding your favorite family recipes\n• Use the notes section for special tips and memories\n• Search is your friend - find recipes quickly\n• Edit mode lets you update recipes anytime\n• The app remembers everything automatically"
                            )
                            
                        }
                        .padding(.horizontal, AppTheme.paddingMedium)
                        
                        // Footer
                        VStack(spacing: AppTheme.paddingSmall) {
                            // Empty footer
                        }
                        .padding(.top, AppTheme.paddingLarge)
                        .padding(.bottom, AppTheme.paddingXLarge)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }
}

struct NoteCard: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
            Text(title)
                .font(AppTheme.headline)
                .foregroundColor(AppTheme.primaryText)
            
            Text(content)
                .font(AppTheme.body)
                .foregroundColor(AppTheme.secondaryText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.paddingMedium)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.surfaceBackground, lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

#Preview {
    AboutView()
}
