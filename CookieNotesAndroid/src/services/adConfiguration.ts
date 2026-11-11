import type { AdSettings } from '../types/models';

export const GOOGLE_ANDROID_TEST_APPLICATION_ID = 'ca-app-pub-3940256099942544~3347511713';
export const GOOGLE_ANDROID_TEST_BANNER_ID = 'ca-app-pub-3940256099942544/6300978111';
export const SAMPLE_PUBLISHER_FRAGMENT = '3940256099942544';
export const DEFAULT_PRIVACY_POLICY_URL = 'https://ghostlycoder55.github.io/CookieNotes-privacy/';

const APP_ID_REGEX = /^ca-app-pub-\d{16}~\d{10}$/;
const BANNER_ID_REGEX = /^ca-app-pub-\d{16}\/\d{10}$/;
const PUBLISHER_PREFIX_REGEX = /^ca-app-pub-\d{16}/;

export function isProductionApplicationID(value: string): boolean {
  const trimmed = value.trim();
  return APP_ID_REGEX.test(trimmed) && !trimmed.includes(SAMPLE_PUBLISHER_FRAGMENT);
}

export function isProductionBannerID(value: string): boolean {
  const trimmed = value.trim();
  return BANNER_ID_REGEX.test(trimmed) && !trimmed.includes(SAMPLE_PUBLISHER_FRAGMENT);
}

export function extractPublisherPrefix(value: string): string | null {
  const match = value.trim().match(PUBLISHER_PREFIX_REGEX);
  return match ? match[0] : null;
}

export function resolveHttpsWebURL(raw?: string | null): string | null {
  const trimmed = (raw ?? '').trim();
  if (!trimmed) return null;
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol.toLowerCase() !== 'https:' || !parsed.hostname) {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

export interface ResolveAdSettingsOptions {
  isDebugBuild: boolean;
  allowTestAds?: boolean;
  forceProductionAds?: boolean;
  applicationID?: string;
  bannerAdUnitID?: string;
  privacyPolicyURLString?: string | null;
}

/**
 * Resolves AdMob IDs for Android without ever treating Google's sample IDs as a production account.
 * Fails closed (`mode: 'disabled'`) in production builds when real Android AdMob IDs are missing or invalid.
 */
export function resolveAdSettings(options: ResolveAdSettingsOptions): AdSettings {
  const privacyPolicyURL =
    resolveHttpsWebURL(options.privacyPolicyURLString) ?? DEFAULT_PRIVACY_POLICY_URL;

  const useTestMode =
    (options.isDebugBuild || options.allowTestAds === true) && !options.forceProductionAds;

  if (useTestMode) {
    return {
      mode: 'test',
      applicationID: GOOGLE_ANDROID_TEST_APPLICATION_ID,
      bannerAdUnitID: GOOGLE_ANDROID_TEST_BANNER_ID,
      privacyPolicyURL,
    };
  }

  const appID = (options.applicationID ?? '').trim();
  const bannerID = (options.bannerAdUnitID ?? '').trim();
  const appPrefix = extractPublisherPrefix(appID);
  const bannerPrefix = extractPublisherPrefix(bannerID);

  if (
    isProductionApplicationID(appID) &&
    isProductionBannerID(bannerID) &&
    appPrefix !== null &&
    appPrefix === bannerPrefix
  ) {
    return {
      mode: 'production',
      applicationID: appID,
      bannerAdUnitID: bannerID,
      privacyPolicyURL,
    };
  }

  return {
    mode: 'disabled',
    applicationID: appID || GOOGLE_ANDROID_TEST_APPLICATION_ID,
    bannerAdUnitID: '',
    privacyPolicyURL,
  };
}

export function getCurrentAdSettings(): AdSettings {
  const isDebug = typeof __DEV__ !== 'undefined' ? __DEV__ : false;
  const allowTestAds = process.env.EXPO_PUBLIC_ALLOW_TEST_ADS === 'true';
  return resolveAdSettings({
    isDebugBuild: isDebug,
    allowTestAds,
    forceProductionAds: false,
    applicationID: process.env.EXPO_PUBLIC_ADMOB_ANDROID_APP_ID ?? '',
    bannerAdUnitID: process.env.EXPO_PUBLIC_ADMOB_ANDROID_BANNER_UNIT_ID ?? '',
    privacyPolicyURLString:
      process.env.EXPO_PUBLIC_PRIVACY_POLICY_URL ?? DEFAULT_PRIVACY_POLICY_URL,
  });
}
