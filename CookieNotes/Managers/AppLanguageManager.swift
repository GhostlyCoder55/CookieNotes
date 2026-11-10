//
//  AppLanguageManager.swift
//  CookieNotes
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"

    var id: String { rawValue }
    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        }
    }

    var titleWithFlag: String {
        "\(displayName) \(flag)"
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

final class AppLanguageManager: ObservableObject, @unchecked Sendable {
    static let shared = AppLanguageManager()

    private static let languageKey = "cookienotes.appLanguage"
    private static let didSelectLanguageKey = "cookienotes.hasSelectedInitialLanguageV2"

    private let lock = NSLock()
    private var cachedActiveLanguage: AppLanguage
    private var cachedBundles: [AppLanguage: Bundle] = [:]

    @Published var currentLanguage: AppLanguage {
        didSet {
            lock.withLock {
                cachedActiveLanguage = currentLanguage
            }
            if isInitialized && !hasLaunchLanguageOverride {
                persist(currentLanguage)
            }
        }
    }

    @Published var hasSelectedInitialLanguage: Bool {
        didSet {
            if isInitialized {
                UserDefaults.standard.set(hasSelectedInitialLanguage, forKey: Self.didSelectLanguageKey)
            }
        }
    }

    private var isInitialized = false
    private var hasLaunchLanguageOverride = false

    var activeLanguage: AppLanguage {
        lock.withLock { cachedActiveLanguage }
    }

    private init() {
        let defaults = UserDefaults.standard
        let args = ProcessInfo.processInfo.arguments

        if let idx = args.firstIndex(of: "-cookienotes.hasSelectedInitialLanguage"),
           idx + 1 < args.count {
            self.hasSelectedInitialLanguage = (args[idx + 1] as NSString).boolValue
        } else {
            self.hasSelectedInitialLanguage = defaults.bool(forKey: Self.didSelectLanguageKey)
        }

        let initial: AppLanguage
        if let idx = args.firstIndex(of: "-cookienotes.appLanguage"),
           idx + 1 < args.count,
           let launchLang = AppLanguage(rawValue: args[idx + 1]) {
            initial = launchLang
            hasLaunchLanguageOverride = true
        } else if let savedCode = defaults.string(forKey: Self.languageKey),
           let savedLang = AppLanguage(rawValue: savedCode) {
            initial = savedLang
        } else {
            // English is default if no selection is made
            initial = .english
        }
        self.currentLanguage = initial
        self.cachedActiveLanguage = initial
        self.isInitialized = true
    }

    @MainActor
    func selectLanguage(_ language: AppLanguage) {
        hasLaunchLanguageOverride = false
        if currentLanguage == language {
            persist(language)
        } else {
            currentLanguage = language
        }
        hasSelectedInitialLanguage = true
    }

    @MainActor
    func setLanguage(_ language: AppLanguage) {
        hasLaunchLanguageOverride = false
        if currentLanguage == language {
            persist(language)
        } else {
            currentLanguage = language
        }
    }

    func localizedString(forKey key: String, defaultValue: String? = nil) -> String {
        let lang = activeLanguage
        let b = bundle(for: lang)
        let sentinel = "__COOKIENOTES_MISSING_KEY__"
        let localized = b.localizedString(forKey: key, value: sentinel, table: "Localizable")
        if localized != sentinel {
            return localized
        }
        return defaultValue ?? key
    }

    func bundle(for language: AppLanguage) -> Bundle {
        lock.withLock {
            if let cached = cachedBundles[language] {
                return cached
            }
            if let path = Bundle.main.path(forResource: language.code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                cachedBundles[language] = bundle
                return bundle
            }
            return Bundle.main
        }
    }

    private func persist(_ language: AppLanguage) {
        let defaults = UserDefaults.standard
        defaults.set(language.code, forKey: Self.languageKey)
        defaults.set([language.code], forKey: "AppleLanguages")
        if let sharedDefaults = UserDefaults(suiteName: "group.com.gc.CookieNotes") {
            sharedDefaults.set(language.code, forKey: Self.languageKey)
        }
    }
}

extension String {
    static func localized(_ key: String, defaultValue: String? = nil) -> String {
        AppLanguageManager.shared.localizedString(forKey: key, defaultValue: defaultValue)
    }

    static func localized(_ format: String, _ args: CVarArg...) -> String {
        let localizedFormat = AppLanguageManager.shared.localizedString(forKey: format)
        return String(format: localizedFormat, locale: AppLanguageManager.shared.activeLanguage.locale, arguments: args)
    }
}
