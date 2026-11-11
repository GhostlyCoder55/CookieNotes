import { Linking } from 'react-native';
import { getSetting, removeSetting, setSetting, SettingKeys } from '../database/settingsRepository';
import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type {
  AppUpdateInfo,
  LocalizedTextValue,
  RemoteUpdateConfig,
} from '../types/models';

export const APP_INSTALLED_VERSION = '1.0.0';
export const ANDROID_PACKAGE_ID = 'com.gc.cookienotes';
export const DEFAULT_PLAY_STORE_URL = `https://play.google.com/store/apps/details?id=${ANDROID_PACKAGE_ID}`;
export const DEFAULT_UPDATE_CONFIG_URL =
  'https://raw.githubusercontent.com/cookienotes/releases/main/update-config.json';
export const UPDATE_CHECK_COOLDOWN_MS = 4 * 60 * 60 * 1000; // 4 hours
const FETCH_TIMEOUT_MS = 5000;

export function parseSemanticVersion(raw: string): number[] | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const base = trimmed.split(/[-+]/)[0] ?? '';
  if (!base) return null;
  const parts = base.split('.').map((segment) => {
    if (!/^\d+$/.test(segment)) return NaN;
    return Number.parseInt(segment, 10);
  });
  if (parts.length === 0 || parts.some((n) => !Number.isFinite(n))) {
    return null;
  }
  return parts;
}

/**
 * Returns -1 if a < b, 0 if a == b, 1 if a > b.
 * Returns null if either string is not a valid semantic version.
 */
export function compareSemanticVersions(a: string, b: string): -1 | 0 | 1 | null {
  const pa = parseSemanticVersion(a);
  const pb = parseSemanticVersion(b);
  if (!pa || !pb) return null;
  const maxLen = Math.max(pa.length, pb.length);
  for (let i = 0; i < maxLen; i += 1) {
    const lv = i < pa.length ? pa[i] : 0;
    const rv = i < pb.length ? pb[i] : 0;
    if (lv < rv) return -1;
    if (lv > rv) return 1;
  }
  return 0;
}

export function isAllowedUpdateConfigURL(rawUrl: string): boolean {
  try {
    const parsed = new URL(rawUrl);
    return (
      parsed.protocol === 'https:' ||
      parsed.hostname === '127.0.0.1' ||
      parsed.hostname === 'localhost'
    );
  } catch {
    return false;
  }
}

export function resolveLocalizedConfigText(
  value: LocalizedTextValue | undefined,
  lang: AppLanguage
): string | null {
  if (!value) return null;
  if (typeof value === 'string') return value;
  return value[lang] ?? value.en ?? Object.values(value)[0] ?? null;
}

export function evaluateRemoteUpdateConfig(
  config: RemoteUpdateConfig,
  currentVersionString: string,
  lang: AppLanguage = getActiveLanguage()
): AppUpdateInfo | null {
  const availableVersion = (config.latestVersion ?? '').trim();
  if (!availableVersion) return null;
  if (!parseSemanticVersion(currentVersionString) || !parseSemanticVersion(availableVersion)) {
    return null;
  }

  let isMandatory = false;
  if (config.minimumRequiredVersion) {
    const minCmp = compareSemanticVersions(currentVersionString, config.minimumRequiredVersion);
    if (minCmp !== null && minCmp < 0) {
      isMandatory = true;
    }
  }
  const latestCmp = compareSemanticVersions(availableVersion, currentVersionString);
  if (!isMandatory && config.isMandatory === true && latestCmp !== null && latestCmp > 0) {
    isMandatory = true;
  }

  if (!isMandatory && (latestCmp === null || latestCmp <= 0)) {
    return null;
  }

  const candidateStoreUrl = (config.playStoreURL ?? config.appStoreURL ?? '').trim();
  let resolvedStoreURL = DEFAULT_PLAY_STORE_URL;
  if (candidateStoreUrl) {
    try {
      const parsed = new URL(candidateStoreUrl);
      if (parsed.protocol === 'https:' || parsed.protocol === 'market:') {
        resolvedStoreURL = parsed.toString();
      }
    } catch {
      resolvedStoreURL = DEFAULT_PLAY_STORE_URL;
    }
  }

  const title =
    resolveLocalizedConfigText(config.title, lang) ??
    tFor(lang, isMandatory ? 'Critical Update Required' : 'Update Available');

  let message: string;
  if (isMandatory) {
    message =
      resolveLocalizedConfigText(config.mandatoryMessage, lang) ??
      resolveLocalizedConfigText(config.message, lang) ??
      tFor(
        lang,
        'An update to version %@ is required to continue using CookieNotes safely.',
        availableVersion
      );
  } else {
    message =
      resolveLocalizedConfigText(config.message, lang) ??
      tFor(
        lang,
        'A new version of CookieNotes is available (%@). Update to enjoy the latest features and improvements.',
        availableVersion
      );
  }

  const releaseNotes = resolveLocalizedConfigText(config.releaseNotes, lang);

  return {
    id: availableVersion,
    version: availableVersion,
    isMandatory,
    title,
    message,
    releaseNotes,
    storeURL: resolvedStoreURL,
  };
}

class AppUpdateManager {
  updateInfo: AppUpdateInfo | null = null;
  isChecking = false;
  lastCheckTimestamp: number | null = null;
  remoteConfigURL: string = DEFAULT_UPDATE_CONFIG_URL;
  private listeners = new Set<() => void>();

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

  async checkForUpdates(options: { force?: boolean } = {}): Promise<void> {
    const force = options.force === true;
    const now = Date.now();

    if (this.lastCheckTimestamp === null) {
      const storedTs = await getSetting(SettingKeys.lastUpdateCheckTimestamp);
      const parsed = storedTs ? Number(storedTs) : NaN;
      if (Number.isFinite(parsed)) {
        this.lastCheckTimestamp = parsed;
      }
    }

    if (
      !force &&
      this.lastCheckTimestamp !== null &&
      now - this.lastCheckTimestamp < UPDATE_CHECK_COOLDOWN_MS
    ) {
      return;
    }

    this.isChecking = true;
    this.emit();

    try {
      const configUrl =
        process.env.EXPO_PUBLIC_UPDATE_CONFIG_URL?.trim() || this.remoteConfigURL;
      if (!isAllowedUpdateConfigURL(configUrl)) {
        return;
      }

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

      let config: RemoteUpdateConfig | null = null;
      try {
        const res = await fetch(configUrl, {
          signal: controller.signal,
          headers: { 'Cache-Control': 'no-cache' },
        });
        clearTimeout(timeout);
        if (res.ok) {
          config = (await res.json()) as RemoteUpdateConfig;
        }
      } catch {
        clearTimeout(timeout);
        config = null;
      } finally {
        this.lastCheckTimestamp = Date.now();
        await setSetting(
          SettingKeys.lastUpdateCheckTimestamp,
          String(this.lastCheckTimestamp)
        ).catch(() => {});
      }

      if (!config) return;

      const evaluated = evaluateRemoteUpdateConfig(
        config,
        APP_INSTALLED_VERSION,
        getActiveLanguage()
      );
      if (!evaluated) return;

      if (!evaluated.isMandatory) {
        const dismissed = await getSetting(SettingKeys.dismissedUpdateVersion);
        if (dismissed) {
          const cmp = compareSemanticVersions(evaluated.version, dismissed);
          if (cmp !== null && cmp <= 0) {
            return;
          }
        }
      }

      this.updateInfo = evaluated;
      this.emit();
    } finally {
      this.isChecking = false;
      this.emit();
    }
  }

  async dismissOptionalUpdate(): Promise<void> {
    const info = this.updateInfo;
    if (!info || info.isMandatory) return;
    await setSetting(SettingKeys.dismissedUpdateVersion, info.version);
    this.updateInfo = null;
    this.emit();
  }

  async performUpdate(): Promise<void> {
    const info = this.updateInfo;
    if (!info) return;
    try {
      await Linking.openURL(info.storeURL);
    } catch {
      await Linking.openURL(DEFAULT_PLAY_STORE_URL).catch(() => {});
    }
  }

  async resetDismissedState(): Promise<void> {
    await removeSetting(SettingKeys.dismissedUpdateVersion);
  }
}

export const appUpdateManager = new AppUpdateManager();
