//
//  CookieNotesApp.swift
//  CookieNotes
//

import SwiftUI
import SwiftData

@main
struct CookieNotesApp: App {
    private let container: ModelContainer
    private let storageWarning: String?

    init() {
        AppBadge.clear()
        let boot = Self.bootstrap()
        container = boot.container
        storageWarning = boot.warning
    }

    var body: some Scene {
        WindowGroup {
            // System `LaunchScreen.storyboard` is the only splash.
            // First launch → tips once; later launches → library.
            ContentView(storageWarning: storageWarning)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .onAppear { InterfaceStyle.forceDark() }
        }
    }

    @MainActor
    private static func bootstrap() -> (container: ModelContainer, warning: String?) {
        do {
            let container = try PersistenceController.makeContainer()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            do {
                try PersistenceController.prepareLibrary(context: context)
            } catch {
                return (container, PersistenceController.lastErrorMessage)
            }
            return (container, PersistenceController.lastErrorMessage)
        } catch {
            return (
                PersistenceController.makeFallbackContainer(),
                "Recipes couldn't be opened. You can keep using CookieNotes, but new changes may not be saved."
            )
        }
    }
}
