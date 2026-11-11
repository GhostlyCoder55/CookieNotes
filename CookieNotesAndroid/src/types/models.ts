import type { AppLanguage } from '../localization/i18n';

export type RecipeCategory =
  | 'uncategorized'
  | 'breakfast'
  | 'lunch'
  | 'dinner'
  | 'dessert'
  | 'drinks';

export type RecipeSort = 'newest' | 'name';

export type RecipeFilter =
  | 'all'
  | 'favorites'
  | 'breakfast'
  | 'lunch'
  | 'dinner'
  | 'dessert'
  | 'drinks';

export type GrocerySort = 'default' | 'uncheckedFirst' | 'alphabetical';

export type CuisineRegion =
  | 'African'
  | 'Asian'
  | 'Caribbean'
  | 'European'
  | 'Middle Eastern'
  | 'North American'
  | 'Oceania'
  | 'South American';

export interface RecipePhoto {
  photoID: string;
  recipeID: string;
  sortIndex: number;
  imageUri: string;
  thumbnailUri: string;
}

export interface Recipe {
  recipeID: string;
  name: string;
  ingredients: string[];
  instructions: string[];
  notes: string;
  source: string;
  prepTime: number;
  cookTime: number;
  servings: number;
  isSample: boolean;
  isImported: boolean;
  isFavorite: boolean;
  categoryRaw: RecipeCategory;
  ingredientIconIDs: string[];
  coverIconID: string;
  usesCategoryCover: boolean;
  catalogRecipeID: string;
  isCatalogSynced: boolean;
  syncedEnglishName: string;
  syncedEnglishIngredients: string[];
  syncedEnglishInstructions: string[];
  dateCreated: string;
  dateModified: string;
  photos: RecipePhoto[];
}

export interface EditableLine {
  id: string;
  text: string;
  iconID: string;
}

export interface PendingPhoto {
  id: string;
  imageUri: string;
  thumbnailUri: string;
}

export interface RecipeDraft {
  name: string;
  ingredients: string[];
  instructions: string[];
  notes: string;
  source: string;
  servings?: number;
}

export interface GroceryItem {
  itemID: string;
  name: string;
  isChecked: boolean;
  sortOrder: number;
  dateCreated: string;
  dateModified: string;
}

export interface DiscoveredRecipeSummary {
  id: string;
  name: string;
  thumbnailURL: string | null;
  category: string | null;
  area: string | null;
  illustrationIconID?: string | null;
}

export interface CuisineArea {
  name: string;
  country: string;
}

export interface DiscoveredRecipeDetail {
  id: string;
  name: string;
  category: string | null;
  area: string | null;
  instructions: string[];
  ingredients: string[];
  thumbnailURL: string | null;
  sourceURL: string | null;
  youtubeURL: string | null;
  tags: string[];
  illustrationIconID?: string | null;
}

export interface LocalMealRecord {
  id: string;
  name: string;
  category: string;
  area: string;
  illustration: string | null;
  ingredients: string[];
  instructions: string[];
  thumbnailURL: string | null;
  sourceURL: string | null;
}

export interface TheMealDBRecord {
  id: string;
  name: string;
  ingredients: string[];
  instructions: string[];
  category?: string | null;
  area?: string | null;
  thumbnailURL?: string | null;
}

export interface RecipeTimeEstimate {
  prep: number;
  cook: number;
}

export interface IngredientCatalogCategory {
  id: string;
  title: string;
  color: string;
  icons: string[];
}

export interface IngredientCatalogFile {
  categories: IngredientCatalogCategory[];
  displayNames: Record<string, string>;
  aliases: Record<string, string>;
}

export type AdRuntimeMode = 'test' | 'production' | 'disabled';

export interface AdSettings {
  mode: AdRuntimeMode;
  applicationID: string;
  bannerAdUnitID: string;
  privacyPolicyURL: string | null;
}

export type AdConsentChoice = 'unknown' | 'allowed' | 'declined';

export type PrivacySheetMode = 'firstRun' | 'settings';

export type AdSlot =
  | { kind: 'item'; index: number }
  | { kind: 'advertisement'; adIndex: number };

export type AdFeedBlock =
  | { id: number; kind: 'items'; indices: number[] }
  | { id: number; kind: 'advertisement' };

export type LocalizedTextValue = string | Record<string, string>;

export interface RemoteUpdateConfig {
  latestVersion?: string;
  minimumRequiredVersion?: string;
  isMandatory?: boolean;
  playStoreURL?: string;
  appStoreURL?: string;
  title?: LocalizedTextValue;
  message?: LocalizedTextValue;
  mandatoryMessage?: LocalizedTextValue;
  releaseNotes?: LocalizedTextValue;
}

export interface AppUpdateInfo {
  id: string;
  version: string;
  isMandatory: boolean;
  title: string;
  message: string;
  releaseNotes: string | null;
  storeURL: string;
}

export interface SharedRecipePayload {
  title: string;
  text: string;
  url: string;
  imageUri?: string | null;
  imageSizeBytes?: number | null;
  createdAt?: string;
}

export interface AppSettingsState {
  appLanguage: AppLanguage;
  hasSelectedInitialLanguage: boolean;
  hasCompletedTutorial: boolean;
  adConsentChoice: AdConsentChoice;
  recipeSort: RecipeSort;
  recipeFilter: RecipeFilter;
  grocerySort: GrocerySort;
  lastLoginDate: string | null;
  dismissedUpdateVersion: string | null;
  lastUpdateCheckTimestamp: number | null;
}

export type DiscoveredRecipeSaveResult = 'inserted' | 'updatedExisting';

export type LibraryStackParamList = {
  RecipeList: undefined;
  RecipeDetail: { recipeID: string };
};

export type DiscoverStackParamList = {
  DiscoverHome: undefined;
  DiscoverDetail: { mealID: string };
};

export type MainTabParamList = {
  LibraryTab: undefined;
  DiscoverTab: undefined;
  ListTab: undefined;
  AboutTab: undefined;
};
