//
//  ContentView.swift
//  CookieNotes
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var storageWarning: String?

    @ObservedObject private var notificationManager = NotificationManager.shared
    @StateObject private var tutorialManager = TutorialManager()
    @ObservedObject private var ads = AdMobController.shared
    @ObservedObject private var imports = ImportCoordinator.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if tutorialManager.shouldShowFirstRunTips {
                // First launch only — full-screen tips before the tab UI appears.
                TutorialView(tutorialManager: tutorialManager, isPresented: .constant(true))
                    .transition(.opacity)
            } else {
                mainInterface
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tutorialManager.hasCompletedTutorial)
    }

    private var mainInterface: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecipeListView(
                    adsActive: adsAreUnobstructed && selectedTab == 0,
                    storageWarning: storageWarning
                )
                .tabItem {
                     Label("Library", systemImage: "book.closed.fill")
                }
                .tag(0)

                DiscoverView()
                    .tabItem {
                        Label("Discover", systemImage: "globe")
                    }
                    .tag(1)

                AboutView(adsActive: adsAreUnobstructed && selectedTab == 2)
                    .tabItem {
                        Label("About", systemImage: "info.circle.fill")
                    }
                    .tag(2)
            }
            .tint(AppTheme.burntOrange)
            .toolbarBackground(AppTheme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .preferredColorScheme(.dark)

            LoginPromptOverlay()
        }
        .environmentObject(tutorialManager)
        .task {
            imports.consumePendingImports(context: modelContext)
            await ads.prepareForAdvertising()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                imports.consumePendingImports(context: modelContext)
                notificationManager.scheduleInactivityReminder()
            }
        }
        .sheet(isPresented: $ads.presentPrivacySheet, onDismiss: {
            Task { await ads.finishPrivacySheet() }
        }) {
            PrivacyChoicesView(ads: ads)
        }
    }

    private var adsAreUnobstructed: Bool {
        !notificationManager.shouldShowLoginPrompt
            && !ads.presentPrivacySheet
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview)
}
