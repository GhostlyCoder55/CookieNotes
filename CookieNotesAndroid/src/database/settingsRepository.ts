import {
  DEFAULT_LANGUAGE,
  normalizeLanguageCode,
  type AppLanguage,
} from '../localization/i18n';
import type {
  AdConsentChoice,
  AppSettingsState,
  GrocerySort,
  RecipeFilter,
  RecipeSort,
} from '../types/models';
import { parseGrocerySort } from '../utils/groceryListLogic';
import { RECIPE_FILTERS } from '../utils/recipeCategory';
import { getDatabase, type SQLExecutor } from './db';

export const SettingKeys = {
  appLanguage: 'cookienotes.appLanguage',
  hasSelectedInitialLanguage: 'cookienotes.hasSelectedInitialLanguage',
  hasCompletedTutorial: 'cookienotes.hasCompletedTutorial',
  adConsent: 'cookienotes.adConsent',
  recipeSort: 'cookienotes.recipeSort',
  recipeFilter: 'cookienotes.recipeFilter',
  grocerySortMode: 'cookienotes.grocerySortMode',
  lastLoginDate: 'last_login_date',
  dismissedUpdateVersion: 'cookienotes.dismissedUpdateVersion',
  lastUpdateCheckTimestamp: 'cookienotes.lastUpdateCheckTimestamp',
  didFinishInitialLibrarySetup: 'cookienotes.didFinishInitialLibrarySetup',
  didPurgeDemoRecipes: 'cookienotes.didPurgeDemoRecipes',
  didPurgeExcludedAndMigrateSnackV1: 'cookienotes.didPurgeExcludedAndMigrateSnackV1',
  didMigrateCatalogIdentityV1: 'cookienotes.didMigrateCatalogIdentityV1',
} as const;

export async function getSetting(
  key: string,
  executor?: SQLExecutor
): Promise<string | null> {
  const db = executor ?? (await getDatabase());
  const row = await db.getFirstAsync<{ value: string }>(
    'SELECT value FROM app_settings WHERE key = ?',
    key
  );
  return row?.value ?? null;
}

export async function setSetting(
  key: string,
  value: string,
  executor?: SQLExecutor
): Promise<void> {
  const db = executor ?? (await getDatabase());
  await db.runAsync(
    'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
    key,
    value
  );
}

export async function removeSetting(
  key: string,
  executor?: SQLExecutor
): Promise<void> {
  const db = executor ?? (await getDatabase());
  await db.runAsync('DELETE FROM app_settings WHERE key = ?', key);
}

export async function getBooleanSetting(
  key: string,
  defaultValue = false,
  executor?: SQLExecutor
): Promise<boolean> {
  const raw = await getSetting(key, executor);
  if (raw === null) return defaultValue;
  return raw === 'true' || raw === '1';
}

export async function setBooleanSetting(
  key: string,
  value: boolean,
  executor?: SQLExecutor
): Promise<void> {
  await setSetting(key, value ? 'true' : 'false', executor);
}

export function normalizeStoredConsent(raw: string | null): AdConsentChoice {
  if (!raw) return 'allowed';
  switch (raw) {
    case 'unknown':
    case 'allowed':
    case 'personalized':
    case 'nonPersonalized':
    case 'platformManaged':
      return 'allowed';
    case 'declined':
      return 'declined';
    default:
      return 'allowed';
  }
}

function parseRecipeSort(raw: string | null): RecipeSort {
  return raw === 'name' ? 'name' : 'newest';
}

function parseRecipeFilter(raw: string | null): RecipeFilter {
  if (raw && (RECIPE_FILTERS as readonly string[]).includes(raw)) {
    return raw as RecipeFilter;
  }
  return 'all';
}

export async function loadAllSettings(executor?: SQLExecutor): Promise<AppSettingsState> {
  const db = executor ?? (await getDatabase());
  const rows = await db.getAllAsync<{ key: string; value: string }>(
    'SELECT key, value FROM app_settings'
  );
  const map = new Map<string, string>();
  for (const row of rows) {
    map.set(row.key, row.value);
  }

  const rawLang = map.get(SettingKeys.appLanguage);
  const appLanguage: AppLanguage = rawLang ? normalizeLanguageCode(rawLang) : DEFAULT_LANGUAGE;
  const lastUpdateRaw = map.get(SettingKeys.lastUpdateCheckTimestamp);
  const lastUpdateNum = lastUpdateRaw ? Number(lastUpdateRaw) : NaN;

  return {
    appLanguage,
    hasSelectedInitialLanguage: map.get(SettingKeys.hasSelectedInitialLanguage) === 'true',
    hasCompletedTutorial: map.get(SettingKeys.hasCompletedTutorial) === 'true',
    adConsentChoice: normalizeStoredConsent(map.get(SettingKeys.adConsent) ?? null),
    recipeSort: parseRecipeSort(map.get(SettingKeys.recipeSort) ?? null),
    recipeFilter: parseRecipeFilter(map.get(SettingKeys.recipeFilter) ?? null),
    grocerySort: parseGrocerySort(map.get(SettingKeys.grocerySortMode) ?? null) as GrocerySort,
    lastLoginDate: map.get(SettingKeys.lastLoginDate) ?? null,
    dismissedUpdateVersion: map.get(SettingKeys.dismissedUpdateVersion) ?? null,
    lastUpdateCheckTimestamp: Number.isFinite(lastUpdateNum) ? lastUpdateNum : null,
  };
}
