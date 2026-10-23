//
//  AdMobController.swift
//  CookieNotes
//

import Foundation
import GoogleMobileAds
import UserMessagingPlatform

enum PrivacySheetMode {
    case firstRun
    case settings
}

/// Owns AdMob startup, Google's consent form, and the local ads on/off choice.
@MainActor
final class AdMobController: ObservableObject {
    static let shared = AdMobController()

    @Published private(set) var canPresentAds = false
    @Published private(set) var reloadToken = UUID()
    @Published private(set) var availabilityMessage: String?
    @Published var presentPrivacySheet = false
    @Published var privacySheetMode: PrivacySheetMode = .firstRun
    @Published var privacyOptionsRequired = false

    private var didPrepare = false
    private var didStartSDK = false
    private var pendingChoice: AdConsentChoice?

    func prepareForAdvertising() async {
        guard !didPrepare else { return }
        didPrepare = true

        if LaunchOptions.skipConsent {
            if AdConsentStore.choice() == .unknown {
                AdConsentStore.set(.declined)
            }
            canPresentAds = false
            return
        }

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        if let geography = LaunchOptions.umpDebugGeography {
            let debug = DebugSettings()
            switch geography {
            case "EEA":
                debug.geography = .EEA
            case "US":
                debug.geography = .regulatedUSState
            case "OTHER":
                debug.geography = .other
            default:
                break
            }
            parameters.debugSettings = debug
        }

        let updateError: Error? = await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }
        if updateError != nil {
            AppLog.ads.error("Ad consent update failed")
        }

        let status = ConsentInformation.shared.consentStatus
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required

        // Prefer CookieNotes-styled consent UI. Only fall back to Google's form when
        // the platform requires it (for example regulated regions).
        if status == .required && ConsentInformation.shared.formStatus == .available {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                ConsentForm.loadAndPresentIfRequired(from: InterfaceLocator.topViewController()) { _ in
                    continuation.resume()
                }
            }
            privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            if ConsentInformation.shared.consentStatus == .obtained && AdConsentStore.choice() == .unknown {
                AdConsentStore.set(.allowed)
            }
        }

        if AdConsentStore.choice() == .unknown {
            privacySheetMode = .firstRun
            presentPrivacySheet = true
            return
        }

        activateIfAllowed()
    }

    func stageChoice(_ choice: AdConsentChoice) {
        pendingChoice = choice
    }

    func finishPrivacySheet() async {
        guard let pendingChoice else { return }
        self.pendingChoice = nil
        AdConsentStore.set(pendingChoice)
        activateIfAllowed()
    }

    func presentPlatformPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: InterfaceLocator.topViewController()) { error in
            if error != nil {
                AppLog.ads.error("Privacy options form could not be presented")
            }
            Task { @MainActor in
                self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                self.activateIfAllowed()
            }
        }
    }

    func activateIfAllowed() {
        let settings = AdConfiguration.current
        let consent = AdConsentStore.choice()
        let platformAllows = ConsentInformation.shared.canRequestAds
        let allowed = settings.mode != .disabled && consent.allowsAds && platformAllows && !settings.bannerAdUnitID.isEmpty
        if settings.mode != .disabled && consent.allowsAds && !platformAllows {
            availabilityMessage = "Ads stay off until the privacy check can reach Google. Your recipes are still available."
        } else {
            availabilityMessage = nil
        }
        canPresentAds = allowed
        reloadToken = UUID()
        guard allowed else { return }

        applyRequestConfiguration()
        guard !didStartSDK else { return }
        didStartSDK = true
        MobileAds.shared.start { _ in
            AppLog.ads.debug("Google Mobile Ads started")
        }
    }

    private func applyRequestConfiguration() {
        let configuration = MobileAds.shared.requestConfiguration
        configuration.maxAdContentRating = GADMaxAdContentRating.general
        configuration.tagForChildDirectedTreatment = NSNumber(value: false)
        configuration.tagForUnderAgeOfConsent = NSNumber(value: false)
        // Standard ads only — no personalized targeting.
        configuration.publisherPrivacyPersonalizationState = .disabled
    }
}
