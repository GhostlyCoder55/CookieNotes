//
//  AppUpdateManager.swift
//  CookieNotes
//
//  Lightweight, Apple-compliant in-app update checker supporting:
//  - Remote JSON configuration (mandatory/optional updates, min version, messages)
//  - Fallback to public iTunes Search / App Store lookup API
//  - Semantic version comparison
//  - Non-intrusive asynchronous fetching with fail-silent error handling
//  - Persistent dismissal of optional updates
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Semantic Versioning

struct SemanticVersion: Comparable, Equatable, Hashable, Sendable, CustomStringConvertible, LosslessStringConvertible {
    let rawValue: String
    let components: [Int]

    init?(_ description: String) {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed

        // Strip prerelease or build metadata (e.g. "1.2.0-beta.1" -> "1.2.0")
        let base = trimmed.components(separatedBy: CharacterSet(charactersIn: "-+")).first ?? trimmed
        let parts = base.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        self.components = parts
    }

    var description: String { rawValue }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let leftVal = index < lhs.components.count ? lhs.components[index] : 0
            let rightVal = index < rhs.components.count ? rhs.components[index] : 0
            if leftVal != rightVal {
                return leftVal < rightVal
            }
        }
        return false
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let leftVal = index < lhs.components.count ? lhs.components[index] : 0
            let rightVal = index < rhs.components.count ? rhs.components[index] : 0
            if leftVal != rightVal {
                return false
            }
        }
        return true
    }

    func hash(into hasher: inout Hasher) {
        var normalized = components
        while normalized.count > 1, normalized.last == 0 {
            normalized.removeLast()
        }
        hasher.combine(normalized)
    }
}

// MARK: - Remote Configuration Models

enum LocalizedText: Codable, Equatable, Sendable {
    case single(String)
    case localized([String: String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .single(string)
        } else if let dict = try? container.decode([String: String].self) {
            self = .localized(dict)
        } else {
            throw DecodingError.typeMismatch(
                LocalizedText.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or [String: String]"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let str):
            try container.encode(str)
        case .localized(let dict):
            try container.encode(dict)
        }
    }

    func resolve(languageCode: String? = nil) -> String? {
        let code = languageCode ?? AppLanguageManager.shared.currentLanguage.code
        switch self {
        case .single(let str):
            return str
        case .localized(let dict):
            return dict[code] ?? dict["en"] ?? dict.values.first
        }
    }
}

struct RemoteUpdateConfig: Codable, Equatable, Sendable {
    var latestVersion: String?
    var minimumRequiredVersion: String?
    var isMandatory: Bool?
    var appStoreURL: String?
    var title: LocalizedText?
    var message: LocalizedText?
    var mandatoryMessage: LocalizedText?
    var releaseNotes: LocalizedText?

    init(
        latestVersion: String? = nil,
        minimumRequiredVersion: String? = nil,
        isMandatory: Bool? = nil,
        appStoreURL: String? = nil,
        title: LocalizedText? = nil,
        message: LocalizedText? = nil,
        mandatoryMessage: LocalizedText? = nil,
        releaseNotes: LocalizedText? = nil
    ) {
        self.latestVersion = latestVersion
        self.minimumRequiredVersion = minimumRequiredVersion
        self.isMandatory = isMandatory
        self.appStoreURL = appStoreURL
        self.title = title
        self.message = message
        self.mandatoryMessage = mandatoryMessage
        self.releaseNotes = releaseNotes
    }
}

private struct iTunesLookupResponse: Codable, Sendable {
    struct Entry: Codable, Sendable {
        let version: String?
        let trackViewUrl: String?
        let releaseNotes: String?
    }
    let resultCount: Int?
    let results: [Entry]?
}

// MARK: - App Update Prompt Model

struct AppUpdateInfo: Identifiable, Equatable, Sendable {
    var id: String { version }
    let version: String
    let isMandatory: Bool
    let title: String
    let message: String
    let releaseNotes: String?
    let appStoreURL: URL

    init(
        version: String,
        isMandatory: Bool,
        title: String,
        message: String,
        releaseNotes: String? = nil,
        appStoreURL: URL
    ) {
        self.version = version
        self.isMandatory = isMandatory
        self.title = title
        self.message = message
        self.releaseNotes = releaseNotes
        self.appStoreURL = appStoreURL
    }
}

// MARK: - App Update Manager

@MainActor
final class AppUpdateManager: ObservableObject {
    static let shared = AppUpdateManager()

    // MARK: - Keys & Defaults
    static let dismissedVersionKey = "cookienotes.dismissedUpdateVersion"
    static let lastCheckTimestampKey = "cookienotes.lastUpdateCheckTimestamp"
    static let defaultCooldown: TimeInterval = 3600 * 4 // 4 hours

    /// Public fallback App Store URL for CookieNotes
    static let defaultAppStoreURL = URL(string: "https://apps.apple.com/app/cookienotes/id6738000000")!

    /// Default remote config endpoint hosted via raw HTTPS.
    /// Remote config is optional; if unreachable or unconfigured, the manager falls back to iTunes Store Lookup API.
    var remoteConfigURL: URL? = URL(string: "https://raw.githubusercontent.com/cookienotes/releases/main/update-config.json")

    // MARK: - State
    @Published private(set) var updateInfo: AppUpdateInfo?
    @Published private(set) var isChecking: Bool = false
    @Published private(set) var lastCheckDate: Date?

    private let session: URLSession
    private let userDefaults: UserDefaults
    private let bundle: Bundle

    init(
        session: URLSession? = nil,
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 5.0
            config.timeoutIntervalForResource = 5.0
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: config)
        }
        self.userDefaults = userDefaults
        self.bundle = bundle
    }

    var currentInstalledVersion: String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var bundleIdentifier: String {
        bundle.bundleIdentifier ?? "com.gc.CookieNotes"
    }

    var dismissedVersion: String? {
        userDefaults.string(forKey: Self.dismissedVersionKey)
    }

    // MARK: - Update Check Execution

    /// Asynchronously checks for an update.
    /// - Parameter force: If true, ignores cooldown interval.
    func checkForUpdates(force: Bool = false) async {
        // 1. Honor test flags or skip conditions
        if LaunchOptions.skipUpdateCheck {
            AppLog.update.debug("Update check skipped via LaunchOptions.")
            return
        }

        if LaunchOptions.resetUpdateDismissal {
            resetDismissedState()
        }

        // 2. Check for UI test mock arguments
        if let mockMandatory = LaunchOptions.mockMandatoryUpdateVersion {
            applyMockUpdate(version: mockMandatory, isMandatory: true)
            return
        }
        if let mockOptional = LaunchOptions.mockUpdateAvailableVersion {
            if dismissedVersion != mockOptional || force {
                applyMockUpdate(version: mockOptional, isMandatory: false)
            }
            return
        }

        // 3. Honor cooldown unless forced
        if !force, let lastCheck = lastCheckDate, Date().timeIntervalSince(lastCheck) < Self.defaultCooldown {
            AppLog.update.debug("Update check skipped due to cooldown.")
            return
        }

        isChecking = true
        defer {
            isChecking = false
            lastCheckDate = Date()
        }

        // 4. Resolve remote config URL (LaunchOptions override takes precedence)
        let configURL = LaunchOptions.updateConfigURL ?? remoteConfigURL

        // 5. Run async fetch on utility queue so launch is never delayed
        let currentVersionString = currentInstalledVersion
        let bundleID = bundleIdentifier

        let resolvedInfo = await Task.detached(priority: .utility) { [session, configURL] () -> AppUpdateInfo? in
            await Self.fetchAndEvaluateUpdate(
                currentVersionString: currentVersionString,
                bundleID: bundleID,
                remoteConfigURL: configURL,
                session: session
            )
        }.value

        // 6. Handle evaluated result
        guard let resolvedInfo else {
            AppLog.update.debug("No update required or check completed without action.")
            return
        }

        // Filter out previously dismissed optional updates
        if !resolvedInfo.isMandatory, let dismissed = dismissedVersion {
            if let semDismissed = SemanticVersion(dismissed),
               let semNew = SemanticVersion(resolvedInfo.version),
               semNew <= semDismissed {
                AppLog.update.debug("Optional update \(resolvedInfo.version) was previously dismissed (\(dismissed)).")
                return
            }
        }

        self.updateInfo = resolvedInfo
        AppLog.update.info("Presenting update prompt for version \(resolvedInfo.version) (mandatory: \(resolvedInfo.isMandatory)).")
    }

    // MARK: - Prompt Actions

    func dismissOptionalUpdate() {
        guard let info = updateInfo, !info.isMandatory else { return }
        userDefaults.set(info.version, forKey: Self.dismissedVersionKey)
        self.updateInfo = nil
        AppLog.update.debug("Optional update \(info.version) dismissed by user.")
    }

    func performUpdate() {
        guard let info = updateInfo else { return }
        AppLog.update.info("Opening App Store URL: \(info.appStoreURL)")
        UIApplication.shared.open(info.appStoreURL, options: [:]) { success in
            AppLog.update.debug("App Store URL open result: \(success)")
        }
    }

    func resetDismissedState() {
        userDefaults.removeObject(forKey: Self.dismissedVersionKey)
    }

    // MARK: - Internal Evaluation

    private static func fetchAndEvaluateUpdate(
        currentVersionString: String,
        bundleID: String,
        remoteConfigURL: URL?,
        session: URLSession
    ) async -> AppUpdateInfo? {
        guard let currentVersion = SemanticVersion(currentVersionString) else {
            return nil
        }

        // 1. Fetch remote JSON configuration if available
        var remoteConfig: RemoteUpdateConfig? = nil
        if let configURL = remoteConfigURL {
            remoteConfig = await fetchRemoteConfig(from: configURL, session: session)
        }

        // 2. Fetch iTunes lookup API if remote config didn't supply full data
        var appStoreVersionString: String? = nil
        var appStoreTrackURL: URL? = nil
        var appStoreReleaseNotes: String? = nil

        let itunesURLString = "https://itunes.apple.com/lookup?bundleId=\(bundleID)"
        if let itunesURL = URL(string: itunesURLString),
           let itunesResponse = await fetchAppStoreLookup(from: itunesURL, session: session),
           let first = itunesResponse.results?.first {
            appStoreVersionString = first.version
            if let track = first.trackViewUrl, let trackURL = URL(string: track) {
                appStoreTrackURL = trackURL
            }
            appStoreReleaseNotes = first.releaseNotes
        }

        // 3. Determine available version
        let availableVersionString = remoteConfig?.latestVersion ?? appStoreVersionString
        guard let availableVersionString,
              let availableVersion = SemanticVersion(availableVersionString) else {
            return nil
        }

        // 4. Determine mandatory requirement
        var isMandatory = false
        if let minRequiredString = remoteConfig?.minimumRequiredVersion,
           let minRequired = SemanticVersion(minRequiredString),
           currentVersion < minRequired {
            isMandatory = true
        } else if remoteConfig?.isMandatory == true, currentVersion < availableVersion {
            isMandatory = true
        }

        // If not mandatory and not newer than current installed, no update is needed
        if !isMandatory && availableVersion <= currentVersion {
            return nil
        }

        // 5. Determine resolved App Store URL
        let resolvedURL: URL
        if let customTrack = remoteConfig?.appStoreURL, let url = URL(string: customTrack) {
            resolvedURL = url
        } else if let track = appStoreTrackURL {
            resolvedURL = track
        } else {
            resolvedURL = defaultAppStoreURL
        }

        // 6. Build localized title and message
        let activeLang = AppLanguageManager.shared.currentLanguage.code
        let title: String
        let message: String
        let releaseNotes: String?

        if isMandatory {
            title = remoteConfig?.title?.resolve(languageCode: activeLang)
                ?? String.localized("Critical Update Required")

            if let customMsg = remoteConfig?.mandatoryMessage?.resolve(languageCode: activeLang) {
                message = customMsg
            } else if let customMsg = remoteConfig?.message?.resolve(languageCode: activeLang) {
                message = customMsg
            } else {
                message = String.localized("An update to version %@ is required to continue using CookieNotes safely.", availableVersion.rawValue)
            }
        } else {
            title = remoteConfig?.title?.resolve(languageCode: activeLang)
                ?? String.localized("Update Available")

            if let customMsg = remoteConfig?.message?.resolve(languageCode: activeLang) {
                message = customMsg
            } else {
                message = String.localized("A new version of CookieNotes is available (%@). Update to enjoy the latest features and improvements.", availableVersion.rawValue)
            }
        }

        releaseNotes = remoteConfig?.releaseNotes?.resolve(languageCode: activeLang) ?? appStoreReleaseNotes

        return AppUpdateInfo(
            version: availableVersion.rawValue,
            isMandatory: isMandatory,
            title: title,
            message: message,
            releaseNotes: releaseNotes,
            appStoreURL: resolvedURL
        )
    }

    private static func fetchRemoteConfig(from url: URL, session: URLSession) async -> RemoteUpdateConfig? {
        // Enforce HTTPS security unless running on localhost in local mock/test runs
        guard url.scheme?.lowercased() == "https" || url.host == "127.0.0.1" || url.host == "localhost" else {
            AppLog.update.error("Remote config rejected non-HTTPS URL: \(url.absoluteString)")
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoder = JSONDecoder()
            return try decoder.decode(RemoteUpdateConfig.self, from: data)
        } catch {
            AppLog.update.debug("Remote config fetch failed silently: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchAppStoreLookup(from url: URL, session: URLSession) async -> iTunesLookupResponse? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoder = JSONDecoder()
            return try decoder.decode(iTunesLookupResponse.self, from: data)
        } catch {
            AppLog.update.debug("iTunes lookup fetch failed silently: \(error.localizedDescription)")
            return nil
        }
    }

    private func applyMockUpdate(version: String, isMandatory: Bool) {
        let activeLang = AppLanguageManager.shared.currentLanguage.code
        let title = isMandatory
            ? String.localized("Critical Update Required")
            : String.localized("Update Available")

        let message = isMandatory
            ? String.localized("An update to version %@ is required to continue using CookieNotes safely.", version)
            : String.localized("A new version of CookieNotes is available (%@). Update to enjoy the latest features and improvements.", version)

        self.updateInfo = AppUpdateInfo(
            version: version,
            isMandatory: isMandatory,
            title: title,
            message: message,
            releaseNotes: activeLang == "fr" ? "• Améliorations de performance\n• Corrections diverses" : "• Performance improvements\n• Bug fixes",
            appStoreURL: Self.defaultAppStoreURL
        )
    }
}
