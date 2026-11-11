import { TurboModuleRegistry } from 'react-native';
import { getActiveLanguage, tFor } from '../localization/i18n';
import type { AdConsentChoice, PrivacySheetMode } from '../types/models';
import { generateUUID } from '../utils/uuid';
import { getCurrentAdSettings } from './adConfiguration';
import { getStoredAdConsent, saveAdConsent } from './adConsentStore';

export interface AdMobControllerState {
  canPresentAds: boolean;
  reloadToken: string;
  availabilityMessage: string | null;
  presentPrivacySheet: boolean;
  privacySheetMode: PrivacySheetMode;
  privacyOptionsRequired: boolean;
  isNativeModuleAvailable: boolean;
}

type GoogleMobileAdsPackage = typeof import('react-native-google-mobile-ads');

/**
 * Safely checks whether the compiled Google Mobile Ads TurboModule exists.
 * Returns `false` in Expo Go so JS never crashes invoking `getEnforcing(...)`.
 */
export function isNativeAdMobAvailable(): boolean {
  try {
    return TurboModuleRegistry.get('RNGoogleMobileAdsModule') != null;
  } catch {
    return false;
  }
}

export function loadGoogleMobileAdsModule(): GoogleMobileAdsPackage | null {
  if (!isNativeAdMobAvailable()) return null;
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    return require('react-native-google-mobile-ads') as GoogleMobileAdsPackage;
  } catch {
    return null;
  }
}

class AdMobController {
  private didPrepare = false;
  private didStartSDK = false;
  private platformCanRequestAds = false;
  private listeners = new Set<() => void>();

  private _state: AdMobControllerState = {
    canPresentAds: false,
    reloadToken: generateUUID(),
    availabilityMessage: null,
    presentPrivacySheet: false,
    privacySheetMode: 'firstRun',
    privacyOptionsRequired: false,
    isNativeModuleAvailable: isNativeAdMobAvailable(),
  };

  getState(): AdMobControllerState {
    return this._state;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private emit(): void {
    for (const listener of this.listeners) {
      listener();
    }
  }

  private updateState(patch: Partial<AdMobControllerState>): void {
    this._state = { ...this._state, ...patch };
    this.emit();
  }

  openPrivacySheet(mode: PrivacySheetMode = 'settings'): void {
    this.updateState({
      privacySheetMode: mode,
      presentPrivacySheet: true,
    });
  }

  closePrivacySheet(): void {
    this.updateState({ presentPrivacySheet: false });
  }

  async applyUserConsentChoice(choice: AdConsentChoice): Promise<void> {
    await saveAdConsent(choice);
    this.updateState({ presentPrivacySheet: false });
    await this.activateIfAllowed();
  }

  async prepareForAdvertising(): Promise<void> {
    if (this.didPrepare) return;
    this.didPrepare = true;

    const nativeAvailable = isNativeAdMobAvailable();
    this.updateState({ isNativeModuleAvailable: nativeAvailable });

    const adsModule = loadGoogleMobileAdsModule();
    if (!adsModule) {
      this.platformCanRequestAds = false;
      this.updateState({
        canPresentAds: false,
        availabilityMessage: null,
      });
      return;
    }

    const { AdsConsent, AdsConsentPrivacyOptionsRequirementStatus, AdsConsentStatus } = adsModule;

    try {
      const info = await AdsConsent.requestInfoUpdate({
        tagForUnderAgeOfConsent: false,
      });
      this.platformCanRequestAds = info.canRequestAds;
      this.updateState({
        privacyOptionsRequired:
          info.privacyOptionsRequirementStatus ===
          AdsConsentPrivacyOptionsRequirementStatus.REQUIRED,
      });

      if (info.status === AdsConsentStatus.REQUIRED && info.isConsentFormAvailable) {
        const formResult = await AdsConsent.loadAndShowConsentFormIfRequired();
        this.platformCanRequestAds = formResult.canRequestAds;
        this.updateState({
          privacyOptionsRequired:
            formResult.privacyOptionsRequirementStatus ===
            AdsConsentPrivacyOptionsRequirementStatus.REQUIRED,
        });
        if (formResult.status === AdsConsentStatus.OBTAINED) {
          await saveAdConsent('allowed');
        }
      }
    } catch {
      try {
        const lastInfo = await AdsConsent.getConsentInfo();
        this.platformCanRequestAds = lastInfo.canRequestAds;
        this.updateState({
          privacyOptionsRequired:
            lastInfo.privacyOptionsRequirementStatus ===
            AdsConsentPrivacyOptionsRequirementStatus.REQUIRED,
        });
      } catch {
        this.platformCanRequestAds = false;
      }
    }

    await this.activateIfAllowed();
  }

  async presentPlatformPrivacyOptions(): Promise<void> {
    const adsModule = loadGoogleMobileAdsModule();
    if (!adsModule) return;
    const { AdsConsent, AdsConsentPrivacyOptionsRequirementStatus } = adsModule;
    try {
      const info = await AdsConsent.showPrivacyOptionsForm();
      this.platformCanRequestAds = info.canRequestAds;
      this.updateState({
        privacyOptionsRequired:
          info.privacyOptionsRequirementStatus ===
          AdsConsentPrivacyOptionsRequirementStatus.REQUIRED,
      });
    } catch {
      // Fail gracefully if form cannot be presented
    }
    await this.activateIfAllowed();
  }

  async activateIfAllowed(): Promise<void> {
    const settings = getCurrentAdSettings();
    const consent = await getStoredAdConsent();
    const adsModule = loadGoogleMobileAdsModule();
    const lang = getActiveLanguage();

    if (!adsModule) {
      this.updateState({
        canPresentAds: false,
        availabilityMessage: null,
        reloadToken: generateUUID(),
      });
      return;
    }

    const platformAllows = this.platformCanRequestAds;
    const allowed =
      settings.mode !== 'disabled' &&
      consent === 'allowed' &&
      platformAllows &&
      settings.bannerAdUnitID.length > 0;

    let availabilityMessage: string | null = null;
    if (settings.mode !== 'disabled' && consent === 'allowed' && !platformAllows) {
      availabilityMessage = tFor(
        lang,
        'Ads stay off until the privacy check can reach Google. Your recipes are still available.'
      );
    }

    this.updateState({
      canPresentAds: allowed,
      availabilityMessage,
      reloadToken: generateUUID(),
    });

    if (!allowed) return;

    const { MaxAdContentRating, MobileAds } = adsModule;
    try {
      await MobileAds().setRequestConfiguration({
        maxAdContentRating: MaxAdContentRating.G,
        tagForChildDirectedTreatment: false,
        tagForUnderAgeOfConsent: false,
        publisherPrivacyPersonalizationState: 'disabled',
      });
    } catch {
      // Non-fatal request configuration failure
    }

    if (this.didStartSDK) return;
    this.didStartSDK = true;
    try {
      await MobileAds().initialize();
    } catch {
      this.didStartSDK = false;
    }
  }
}

export const adMobController = new AdMobController();
