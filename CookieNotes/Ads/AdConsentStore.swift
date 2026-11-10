//
//  AdConsentStore.swift
//  CookieNotes
//

import Foundation

enum AdConsentChoice: String, Equatable {
    case unknown
    case allowed
    case declined

    var allowsAds: Bool {
        self == .allowed
    }

    var title: String {
        switch self {
        case .unknown, .allowed: String.localized("Ads on")
        case .declined: String.localized("Ads off")
        }
    }
}

enum AdConsentStore {
    static let key = "cookienotes.adConsent"

    static func choice(defaults: UserDefaults = .standard) -> AdConsentChoice {
        guard let raw = defaults.string(forKey: key), !raw.isEmpty else {
            // Show ads is on by default
            return .allowed
        }
        if let choice = AdConsentChoice(rawValue: raw) {
            return choice == .unknown ? .allowed : choice
        }
        // Migrate older personalized / non-personalized / regional values.
        switch raw {
        case "personalized", "nonPersonalized", "platformManaged":
            return .allowed
        case "declined":
            return .declined
        default:
            return .allowed
        }
    }

    static func set(_ choice: AdConsentChoice, defaults: UserDefaults = .standard) {
        defaults.set(choice.rawValue, forKey: key)
    }
}
