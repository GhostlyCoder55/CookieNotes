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
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @ObservedObject private var updateManager = AppUpdateManager.shared
    @ObservedObject private var ads = AdMobController.shared
    @ObservedObject private var imports = ImportCoordinator.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    private var shouldShowOnboarding: Bool {
        (!languageManager.hasSelectedInitialLanguage && !LaunchOptions.skipLanguageSelection)
            || tutorialManager.shouldShowFirstRunTips
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                // First launch only — language choice is page 1 of Tips, followed by app tips.
                TutorialView(tutorialManager: tutorialManager, isPresented: .constant(true))
                    .transition(.opacity)
            } else {
                mainInterface
                    .id(languageManager.currentLanguage.code)
                    .transition(.opacity)
            }
        }
        .environment(\.locale, languageManager.currentLanguage.locale)
        .animation(.easeInOut(duration: 0.3), value: shouldShowOnboarding)
    }

    private var mainInterface: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecipeListView(
                    adsActive: adsAreUnobstructed && selectedTab == 0,
                    storageWarning: storageWarning
                )
                .tabItem {
                     Label(String.localized("Library"), systemImage: "book.closed.fill")
                }
                .tag(0)

                DiscoverView()
                    .tabItem {
                        Label(String.localized("Discover"), systemImage: "globe")
                    }
                    .tag(1)

                AboutView(adsActive: adsAreUnobstructed && selectedTab == 2)
                    .tabItem {
                        Label(String.localized("About"), systemImage: "info.circle.fill")
                    }
                    .tag(2)
            }
            .tint(AppTheme.burntOrange)
            .toolbarBackground(AppTheme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .preferredColorScheme(.dark)

            LoginPromptOverlay()
            AppUpdatePromptOverlay()
        }
        .environmentObject(tutorialManager)
        .task {
            imports.consumePendingImports(context: modelContext)
            notificationManager.scheduleInactivityReminder()
            await ads.prepareForAdvertising()
            await updateManager.checkForUpdates()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                imports.consumePendingImports(context: modelContext)
                notificationManager.scheduleInactivityReminder()
                Task {
                    await updateManager.checkForUpdates()
                }
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
            && updateManager.updateInfo == nil
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview)
}
