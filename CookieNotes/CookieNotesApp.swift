//
//  CookieNotesApp.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

@main
struct CookieNotesApp: App {
    @State private var showLaunchScreen = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .preferredColorScheme(.dark)
                }
            }
            .onAppear {
                // Show launch screen for 2.5 seconds then transition to main app
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
