//
//  ContentView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var recipeManager = RecipeManager()
    @StateObject private var notificationManager = NotificationManager()
    
    var body: some View {
        ZStack {
            TabView {
                RecipeListView()
                    .environmentObject(recipeManager)
                    .tabItem {
                        Image(systemName: "book.closed")
                        Text("Recipes")
                    }
                
                SearchView()
                    .environmentObject(recipeManager)
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                
                AboutView()
                    .tabItem {
                        Image(systemName: "info.circle")
                        Text("About")
                    }
            }
            .accentColor(AppTheme.secondaryBrown)
            .preferredColorScheme(.dark)
            
            // Login prompt overlay
            LoginPromptOverlay(notificationManager: notificationManager)
        }
        .onAppear {
            // Mark user as active when they open the app
            notificationManager.markUserAsActive()
            // Connect the managers
            recipeManager.setNotificationManager(notificationManager)
        }
    }
}

#Preview {
    ContentView()
}
