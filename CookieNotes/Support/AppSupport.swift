//
//  AppSupport.swift
//  CookieNotes
//

import Foundation
import os
import UIKit
import UserNotifications

enum AppLog {
    static let ads = Logger(subsystem: "com.gc.CookieNotes", category: "ads")
    static let storage = Logger(subsystem: "com.gc.CookieNotes", category: "storage")
    static let update = Logger(subsystem: "com.gc.CookieNotes", category: "update")
}

enum LaunchOptions {
    static var skipTutorial: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesSkipTutorial")
    }

    static var skipLanguageSelection: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesSkipLanguageSelection") || skipTutorial
    }

    static var skipConsent: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesSkipConsent")
    }

    static var skipWelcome: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesSkipWelcome")
    }

    static var forceProductionAds: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesUseProductionAds")
    }

    static var skipUpdateCheck: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesSkipUpdateCheck")
    }

    static var resetUpdateDismissal: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesResetUpdateDismissal")
    }

    static var resetGrocerySort: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesResetGrocerySort")
    }

    static var mockUpdateAvailableVersion: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-CookieNotesMockUpdateAvailable"),
              index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static var mockMandatoryUpdateVersion: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-CookieNotesMockMandatoryUpdate"),
              index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static var updateConfigURL: URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-CookieNotesUpdateConfigURL"),
              index + 1 < args.count else { return nil }
        return URL(string: args[index + 1])
    }

    static var umpDebugGeography: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-CookieNotesUMPDebugGeography"),
              index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}

enum AppBadge {
    static func clear() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if error != nil {
                AppLog.storage.debug("App icon badge could not be cleared")
            }
        }
    }
}

enum InterfaceLocator {
    @MainActor
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let resolved = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        if let navigation = resolved as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }
        if let tab = resolved as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = resolved?.presentedViewController {
            return topViewController(base: presented)
        }
        return resolved
    }
}

/// Keeps UIKit search bars / text fields on the same dark traits as SwiftUI.
enum InterfaceStyle {
    @MainActor
    static func forceDark() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = .dark
            }
        }
    }
}
