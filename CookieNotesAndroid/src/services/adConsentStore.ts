import {
  getSetting,
  normalizeStoredConsent,
  setSetting,
  SettingKeys,
} from '../database/settingsRepository';
import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { AdConsentChoice } from '../types/models';

export function normalizeAdConsentChoice(choice: AdConsentChoice): AdConsentChoice {
  return choice === 'unknown' ? 'allowed' : choice;
}

export function getConsentChoiceTitle(
  choice: AdConsentChoice,
  lang: AppLanguage = getActiveLanguage()
): string {
  return choice === 'declined' ? tFor(lang, 'Ads off') : tFor(lang, 'Ads on');
}

export async function getStoredAdConsent(): Promise<AdConsentChoice> {
  const raw = await getSetting(SettingKeys.adConsent);
  return normalizeStoredConsent(raw);
}

export async function saveAdConsent(choice: AdConsentChoice): Promise<void> {
  await setSetting(SettingKeys.adConsent, normalizeAdConsentChoice(choice));
}
