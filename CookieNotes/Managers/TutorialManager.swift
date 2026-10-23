//
//  TutorialManager.swift
//  CookieNotes
//

import Foundation

/// First-run tips for newcomers only — stored so they appear once per install.
final class TutorialManager: ObservableObject {
    private static let storageKey = "cookienotes.didCompleteFirstRunTips"
    private static let legacyKey = "hasCompletedTutorial"

    @Published private(set) var hasCompletedTutorial: Bool

    init() {
        if LaunchOptions.skipTutorial {
            hasCompletedTutorial = true
            Self.persist(true)
            return
        }

        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: Self.storageKey) as? Bool {
            hasCompletedTutorial = stored
        } else if defaults.object(forKey: Self.legacyKey) != nil {
            // Existing installs that already saw tips stay on the main app.
            hasCompletedTutorial = defaults.bool(forKey: Self.legacyKey)
            Self.persist(hasCompletedTutorial)
        } else {
            // Brand-new install — show tips this one time.
            hasCompletedTutorial = false
        }
    }

    var shouldShowFirstRunTips: Bool { !hasCompletedTutorial }

    func completeTutorial() {
        guard !hasCompletedTutorial else { return }
        hasCompletedTutorial = true
        Self.persist(true)
    }

    /// Manual replay from About only — never used on cold launch automatically.
    func resetTutorial() {
        hasCompletedTutorial = false
        Self.persist(false)
    }

    private static func persist(_ completed: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(completed, forKey: storageKey)
        defaults.set(completed, forKey: legacyKey)
    }
}
