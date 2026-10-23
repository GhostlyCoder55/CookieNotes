//
//  AdConfiguration.swift
//  CookieNotes
//

import Foundation

enum AdRuntimeMode: Equatable {
    case test
    case production
    case disabled
}

struct AdSettings: Equatable {
    var mode: AdRuntimeMode
    var applicationID: String
    var bannerAdUnitID: String
    var privacyPolicyURL: URL?
    var cloudKitEnabled: Bool
}

/// Resolves AdMob IDs without ever treating Google's sample IDs as a production account.
enum AdConfiguration {
    static let googleTestApplicationID = "ca-app-pub-3940256099942544~1458002511"
    static let googleTestBannerID = "ca-app-pub-3940256099942544/2435281174"
    static let samplePublisherFragment = "3940256099942544"

    static var current: AdSettings {
        let info = Bundle.main.infoDictionary ?? [:]
        return resolve(
            isDebugBuild: isDebugBuild,
            forceProductionAds: LaunchOptions.forceProductionAds,
            applicationID: info["GADApplicationIdentifier"] as? String ?? "",
            bannerAdUnitID: info["CookieNotesBannerAdUnitID"] as? String ?? "",
            privacyPolicyURLString: info["CookieNotesPrivacyPolicyURL"] as? String ?? "",
            cloudKitFlag: info["CookieNotesCloudKitEnabled"] as? String ?? ""
        )
    }

    static func resolve(
        isDebugBuild: Bool,
        forceProductionAds: Bool,
        applicationID: String,
        bannerAdUnitID: String,
        privacyPolicyURLString: String,
        cloudKitFlag: String
    ) -> AdSettings {
        let privacyPolicyURL = webURL(privacyPolicyURLString)
        let cloudKitEnabled = cloudKitFlag == "YES"

        if isDebugBuild && !forceProductionAds {
            return AdSettings(
                mode: .test,
                applicationID: googleTestApplicationID,
                bannerAdUnitID: googleTestBannerID,
                privacyPolicyURL: privacyPolicyURL,
                cloudKitEnabled: cloudKitEnabled
            )
        }

        let appID = applicationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let bannerID = bannerAdUnitID.trimmingCharacters(in: .whitespacesAndNewlines)
        if isProductionApplicationID(appID),
           isProductionBannerID(bannerID),
           publisherPrefix(appID) == publisherPrefix(bannerID) {
            return AdSettings(
                mode: .production,
                applicationID: appID,
                bannerAdUnitID: bannerID,
                privacyPolicyURL: privacyPolicyURL,
                cloudKitEnabled: cloudKitEnabled
            )
        }

        // Keep a valid-format app ID in Info.plist so the SDK can load, but never request ads.
        return AdSettings(
            mode: .disabled,
            applicationID: appID.isEmpty ? googleTestApplicationID : appID,
            bannerAdUnitID: "",
            privacyPolicyURL: privacyPolicyURL,
            cloudKitEnabled: cloudKitEnabled
        )
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func isProductionApplicationID(_ value: String) -> Bool {
        matches(value, pattern: #"^ca-app-pub-\d{16}~\d{10}$"#) && !value.contains(samplePublisherFragment)
    }

    private static func isProductionBannerID(_ value: String) -> Bool {
        matches(value, pattern: #"^ca-app-pub-\d{16}/\d{10}$"#) && !value.contains(samplePublisherFragment)
    }

    private static func publisherPrefix(_ value: String) -> String? {
        guard let range = value.range(of: #"^ca-app-pub-\d{16}"#, options: .regularExpression) else {
            return nil
        }
        return String(value[range])
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func webURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        // Privacy policy links must be https for App Store / AdMob compliance.
        guard scheme == "https", url.host() != nil else { return nil }
        return url
    }
}
