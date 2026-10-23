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
}

enum LaunchOptions {
    static var skipTutorial: Bool {
        ProcessInfo.processInfo.arguments.contains("-CookieNotesSkipTutorial")
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
