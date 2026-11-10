//
//  TutorialManager.swift
//  CookieNotes
//

import Foundation

/// First-run tips for newcomers only — stored so they appear once per install.
final class TutorialManager: ObservableObject {
    private static let storageKey = "cookienotes.didCompleteFirstRunTipsV2"

    @Published private(set) var hasCompletedTutorial: Bool

    init() {
        if LaunchOptions.skipTutorial {
            hasCompletedTutorial = true
            return
        }

        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-cookienotes.didCompleteFirstRunTips"),
           idx + 1 < args.count {
            hasCompletedTutorial = (args[idx + 1] as NSString).boolValue
            return
        }

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.storageKey) != nil {
            hasCompletedTutorial = defaults.bool(forKey: Self.storageKey)
        } else {
            // Brand-new install or first launch on the updated onboarding — show Tips once.
            hasCompletedTutorial = false
        }
    }

    var shouldShowFirstRunTips: Bool { !hasCompletedTutorial }

    func completeTutorial() {
        guard !hasCompletedTutorial else { return }
        hasCompletedTutorial = true
        Self.persist(true)
    }

    private static func persist(_ completed: Bool) {
        UserDefaults.standard.set(completed, forKey: storageKey)
    }
}
