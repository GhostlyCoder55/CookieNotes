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
        case .unknown: "Not chosen"
        case .allowed: "Ads on"
        case .declined: "Ads off"
        }
    }
}

enum AdConsentStore {
    static let key = "cookienotes.adConsent"

    static func choice(defaults: UserDefaults = .standard) -> AdConsentChoice {
        let raw = defaults.string(forKey: key) ?? ""
        if let choice = AdConsentChoice(rawValue: raw) {
            return choice
        }
        // Migrate older personalized / non-personalized / regional values.
        switch raw {
        case "personalized", "nonPersonalized", "platformManaged":
            return .allowed
        case "declined":
            return .declined
        default:
            return .unknown
        }
    }

    static func set(_ choice: AdConsentChoice, defaults: UserDefaults = .standard) {
        defaults.set(choice.rawValue, forKey: key)
    }
}
