import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import { AppState, type AppStateStatus, Platform } from 'react-native';
import { getLocalMealRecord } from '../data/localMealCatalog';
import { runStartupMigrations } from '../database/migrations';
import {
  addGroceryItem as dbAddGroceryItem,
  clearAllGroceryItems as dbClearAllGroceryItems,
  clearCheckedGroceryItems as dbClearCheckedGroceryItems,
  deleteGroceryItem as dbDeleteGroceryItem,
  fetchAllGroceryItems,
  toggleGroceryItem as dbToggleGroceryItem,
  updateGroceryItemName as dbUpdateGroceryItemName,
} from '../database/groceryRepository';
import {
  deleteRecipeByID as dbDeleteRecipeByID,
  fetchAllRecipes,
  insertOrReplaceRecipe,
  saveDiscoveredRecipeToLibrary,
  toggleRecipeFavorite as dbToggleRecipeFavorite,
} from '../database/recipeRepository';
import {
  loadAllSettings,
  setBooleanSetting,
  setSetting,
  SettingKeys,
} from '../database/settingsRepository';
import { useLanguage } from '../localization/LanguageContext';
import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import {
  adMobController,
  type AdMobControllerState,
} from '../services/adMobController';
import { appUpdateManager } from '../services/appUpdateManager';
import { consumeSharedRecipePayload } from '../services/importCoordinator';
import { notificationManager } from '../services/notificationManager';
import type {
  AdConsentChoice,
  AppUpdateInfo,
  DiscoveredRecipeDetail,
  DiscoveredRecipeSaveResult,
  EditableLine,
  GroceryItem,
  GrocerySort,
  PendingPhoto,
  PrivacySheetMode,
  Recipe,
  RecipeCategory,
  RecipeDraft,
  RecipeFilter,
  RecipePhoto,
  RecipeSort,
  SharedRecipePayload,
} from '../types/models';
import { findMatchingIconID } from '../utils/ingredientCatalog';
import { deletePhotoFiles } from '../utils/photoProcessing';
import { cleanRecipeDraft, sanitizeMinutes, sanitizeServings } from '../utils/recipeSanitizer';
import { hapticImpactLight, hapticSuccess } from '../utils/haptics';
import { generateUUID } from '../utils/uuid';

interface SaveNewRecipeInput {
  draft: RecipeDraft;
  ingredientLines: EditableLine[];
  prepTime: number;
  cookTime: number;
  servings: number;
  category: RecipeCategory;
  coverIconID: string;
  usesCategoryCover: boolean;
  photos: PendingPhoto[];
}

interface UpdateRecipeInput {
  original: Recipe;
  draft: RecipeDraft;
  ingredientLines: EditableLine[];
  prepTime: number;
  cookTime: number;
  servings: number;
  category: RecipeCategory;
  coverIconID: string;
  usesCategoryCover: boolean;
  removedPhotoIDs: Set<string>;
  pendingPhotos: PendingPhoto[];
}

interface AppStateContextValue {
  isReady: boolean;
  storageWarning: string | null;
  recipes: Recipe[];
  groceryItems: GroceryItem[];
  hasSelectedInitialLanguage: boolean;
  hasCompletedTutorial: boolean;
  recipeSort: RecipeSort;
  recipeFilter: RecipeFilter;
  grocerySort: GrocerySort;
  adConsentChoice: AdConsentChoice;
  adState: AdMobControllerState;
  updateInfo: AppUpdateInfo | null;
  welcomeBackVisible: boolean;
  lastLoginDate: string | null;
  importBannerMessage: string | null;
  toastMessage: string | null;
  toastVisible: boolean;
  adsAreUnobstructed: boolean;

  showToast: (text: string) => void;
  showRecipeAddedToast: () => void;
  dismissImportBanner: () => void;

  selectInitialLanguage: (lang: AppLanguage) => Promise<void>;
  setAppLanguage: (lang: AppLanguage) => Promise<void>;
  completeTutorial: () => Promise<void>;

  setRecipeSort: (sort: RecipeSort) => Promise<void>;
  setRecipeFilter: (filter: RecipeFilter) => Promise<void>;
  setGrocerySort: (sort: GrocerySort) => Promise<void>;

  saveNewRecipe: (input: SaveNewRecipeInput) => Promise<Recipe>;
  updateRecipe: (input: UpdateRecipeInput) => Promise<Recipe>;
  deleteRecipe: (recipeID: string) => Promise<void>;
  toggleFavorite: (recipeID: string) => Promise<void>;
  saveDiscoveredRecipe: (
    detail: DiscoveredRecipeDetail,
    options?: {
      englishDetail?: DiscoveredRecipeDetail | null;
      ingredientIcons?: string[];
    }
  ) => Promise<DiscoveredRecipeSaveResult>;
  refreshRecipes: () => Promise<void>;

  addGrocery: (rawName: string) => Promise<boolean>;
  toggleGrocery: (itemID: string) => Promise<void>;
  editGrocery: (itemID: string, rawName: string) => Promise<void>;
  removeGrocery: (itemID: string) => Promise<void>;
  clearCheckedGrocery: () => Promise<void>;
  clearAllGrocery: () => Promise<void>;

  dismissWelcomeBack: () => Promise<void>;
  startCookingFromWelcome: () => Promise<void>;

  openPrivacySheet: (mode?: PrivacySheetMode) => void;
  closePrivacySheet: () => void;
  applyAdConsentChoice: (choice: AdConsentChoice) => Promise<void>;
  presentPlatformPrivacyOptions: () => Promise<void>;

  performAppUpdate: () => Promise<void>;
  dismissAppUpdate: () => Promise<void>;
  handleSharedPayload: (payload: SharedRecipePayload) => Promise<void>;
}

const AppStateContext = createContext<AppStateContextValue | null>(null);

function ShareIntentWatcher({
  enabled,
  onPayload,
}: {
  enabled: boolean;
  onPayload: (payload: SharedRecipePayload) => void;
}) {
  // Always guard dynamic require so Expo Go or environments missing ShareIntent work safely.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { useShareIntent } = require('expo-share-intent') as typeof import('expo-share-intent');
  const { hasShareIntent, shareIntent, resetShareIntent } = useShareIntent({
    disabled: !enabled || Platform.OS !== 'android',
    resetOnBackground: true,
  });

  const lastSignatureRef = useRef<string | null>(null);

  useEffect(() => {
    if (!enabled || !hasShareIntent || !shareIntent) return;

    const firstFile =
      shareIntent.files?.find((f) => f.mimeType?.startsWith('image/')) ??
      shareIntent.files?.[0];
    const signature = `${shareIntent.webUrl ?? ''}|${shareIntent.text ?? ''}|${firstFile?.path ?? ''}`;
    if (!signature.replace(/\|/g, '') || lastSignatureRef.current === signature) {
      return;
    }
    lastSignatureRef.current = signature;

    onPayload({
      title: shareIntent.meta?.title ?? '',
      text: shareIntent.text ?? '',
      url: shareIntent.webUrl ?? '',
      imageUri: firstFile?.path ?? null,
      imageSizeBytes: firstFile?.size ?? null,
      createdAt: new Date().toISOString(),
    });

    resetShareIntent(true);
  }, [enabled, hasShareIntent, shareIntent, onPayload, resetShareIntent]);

  return null;
}

function isExpoShareIntentSupported(): boolean {
  if (Platform.OS !== 'android') return false;
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const mod = require('expo-share-intent/build/ExpoShareIntentModule') as {
      default?: unknown;
    };
    return Boolean(mod?.default);
  } catch {
    return false;
  }
}

export function AppStateProvider({ children }: { children: React.ReactNode }) {
  const { setLanguage } = useLanguage();

  const [isReady, setIsReady] = useState(false);
  const [storageWarning, setStorageWarning] = useState<string | null>(null);
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [groceryItems, setGroceryItems] = useState<GroceryItem[]>([]);
  const [hasSelectedInitialLanguage, setHasSelectedInitialLanguage] = useState(false);
  const [hasCompletedTutorial, setHasCompletedTutorial] = useState(false);
  const [recipeSort, setRecipeSortState] = useState<RecipeSort>('newest');
  const [recipeFilter, setRecipeFilterState] = useState<RecipeFilter>('all');
  const [grocerySort, setGrocerySortState] = useState<GrocerySort>('default');
  const [adConsentChoice, setAdConsentChoice] = useState<AdConsentChoice>('allowed');
  const [adState, setAdState] = useState<AdMobControllerState>(() =>
    adMobController.getState()
  );
  const [updateInfo, setUpdateInfo] = useState<AppUpdateInfo | null>(
    appUpdateManager.updateInfo
  );
  const [welcomeBackVisible, setWelcomeBackVisible] = useState(false);
  const [lastLoginDate, setLastLoginDate] = useState<string | null>(null);
  const [importBannerMessage, setImportBannerMessage] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [toastVisible, setToastVisible] = useState(false);

  const toastGenRef = useRef(0);

  const showToast = useCallback((text: string) => {
    const token = ++toastGenRef.current;
    setToastMessage(text);
    setToastVisible(true);
    setTimeout(() => {
      if (toastGenRef.current !== token) return;
      setToastVisible(false);
      setTimeout(() => {
        if (toastGenRef.current !== token) return;
        setToastMessage(null);
      }, 220);
    }, 2000);
  }, []);

  const showRecipeAddedToast = useCallback(() => {
    showToast(tFor(getActiveLanguage(), 'Recipe added to Library'));
  }, [showToast]);

  const dismissImportBanner = useCallback(() => {
    setImportBannerMessage(null);
  }, []);

  const refreshRecipes = useCallback(async () => {
    const list = (await fetchAllRecipes()).filter((r) => !r.isSample);
    setRecipes(list);
  }, []);

  useEffect(() => {
    const unsubAd = adMobController.subscribe(() => {
      setAdState(adMobController.getState());
    });
    const unsubUpdate = appUpdateManager.subscribe(() => {
      setUpdateInfo(appUpdateManager.updateInfo);
    });
    const unsubNotif = notificationManager.subscribe(() => {
      setWelcomeBackVisible(notificationManager.shouldShowWelcomePrompt);
      setLastLoginDate(notificationManager.lastLoginDate);
    });
    return () => {
      unsubAd();
      unsubUpdate();
      unsubNotif();
    };
  }, []);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await runStartupMigrations();
        const [loadedSettings, loadedRecipes, loadedGroceries] = await Promise.all([
          loadAllSettings(),
          fetchAllRecipes(),
          fetchAllGroceryItems(),
        ]);

        if (!mounted) return;
        setLanguage(loadedSettings.appLanguage);
        setHasSelectedInitialLanguage(loadedSettings.hasSelectedInitialLanguage);
        setHasCompletedTutorial(loadedSettings.hasCompletedTutorial);
        setRecipeSortState(loadedSettings.recipeSort);
        setRecipeFilterState(loadedSettings.recipeFilter);
        setGrocerySortState(loadedSettings.grocerySort);
        setAdConsentChoice(loadedSettings.adConsentChoice);
        setRecipes(loadedRecipes.filter((r) => !r.isSample));
        setGroceryItems(loadedGroceries);

        await notificationManager.initializeOnLaunch();
        if (mounted) {
          setIsReady(true);
        }

        // Non-blocking background startup checks
        void notificationManager.scheduleInactivityReminder();
        void adMobController.prepareForAdvertising();
        void appUpdateManager.checkForUpdates();
      } catch {
        if (!mounted) return;
        setStorageWarning(
          tFor(
            getActiveLanguage(),
            "Recipes couldn't be opened. You can keep using CookieNotes, but new changes may not be saved."
          )
        );
        setIsReady(true);
      }
    })();

    return () => {
      mounted = false;
    };
  }, [setLanguage]);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (nextState: AppStateStatus) => {
      if (nextState === 'active' && isReady) {
        void notificationManager.scheduleInactivityReminder();
        void appUpdateManager.checkForUpdates();
      }
    });
    return () => {
      sub.remove();
    };
  }, [isReady]);

  const selectInitialLanguage = useCallback(
    async (lang: AppLanguage) => {
      setLanguage(lang);
      setHasSelectedInitialLanguage(true);
      await setSetting(SettingKeys.appLanguage, lang);
      await setBooleanSetting(SettingKeys.hasSelectedInitialLanguage, true);
    },
    [setLanguage]
  );

  const setAppLanguage = useCallback(
    async (lang: AppLanguage) => {
      setLanguage(lang);
      await setSetting(SettingKeys.appLanguage, lang);
      if (!hasSelectedInitialLanguage) {
        setHasSelectedInitialLanguage(true);
        await setBooleanSetting(SettingKeys.hasSelectedInitialLanguage, true);
      }
    },
    [setLanguage, hasSelectedInitialLanguage]
  );

  const completeTutorial = useCallback(async () => {
    if (!hasSelectedInitialLanguage) {
      const current = getActiveLanguage();
      setHasSelectedInitialLanguage(true);
      await setSetting(SettingKeys.appLanguage, current);
      await setBooleanSetting(SettingKeys.hasSelectedInitialLanguage, true);
    }
    setHasCompletedTutorial(true);
    await setBooleanSetting(SettingKeys.hasCompletedTutorial, true);
  }, [hasSelectedInitialLanguage]);

  const setRecipeSort = useCallback(async (sort: RecipeSort) => {
    setRecipeSortState(sort);
    await setSetting(SettingKeys.recipeSort, sort);
  }, []);

  const setRecipeFilter = useCallback(async (filter: RecipeFilter) => {
    setRecipeFilterState(filter);
    await setSetting(SettingKeys.recipeFilter, filter);
  }, []);

  const setGrocerySort = useCallback(async (sort: GrocerySort) => {
    setGrocerySortState(sort);
    await setSetting(SettingKeys.grocerySortMode, sort);
  }, []);

  const saveNewRecipe = useCallback(
    async (input: SaveNewRecipeInput): Promise<Recipe> => {
      const clean = cleanRecipeDraft(input.draft);
      const lang = getActiveLanguage();
      const nonEmptyLines = input.ingredientLines.filter(
        (line) => line.text.replace(/[\r\n]+/g, ' ').trim().length > 0
      );
      const iconIDs = nonEmptyLines.map(
        (line) => line.iconID || findMatchingIconID(line.text, lang) || ''
      );
      while (iconIDs.length < clean.ingredients.length) iconIDs.push('');

      const recipeID = generateUUID();
      const now = new Date().toISOString();
      const storedPhotos: RecipePhoto[] = input.photos
        .slice(0, 5)
        .map((p, index) => ({
          photoID: generateUUID(),
          recipeID,
          sortIndex: index,
          imageUri: p.imageUri,
          thumbnailUri: p.thumbnailUri,
        }));

      const newRecipe: Recipe = {
        recipeID,
        name: clean.name,
        ingredients: clean.ingredients,
        instructions: clean.instructions,
        notes: clean.notes,
        source: clean.source,
        prepTime: sanitizeMinutes(input.prepTime),
        cookTime: sanitizeMinutes(input.cookTime),
        servings: sanitizeServings(input.servings),
        isSample: false,
        isImported: false,
        isFavorite: false,
        categoryRaw: input.category,
        ingredientIconIDs: iconIDs.slice(0, clean.ingredients.length),
        coverIconID: input.coverIconID,
        usesCategoryCover: input.usesCategoryCover,
        catalogRecipeID: '',
        isCatalogSynced: false,
        syncedEnglishName: '',
        syncedEnglishIngredients: [],
        syncedEnglishInstructions: [],
        dateCreated: now,
        dateModified: now,
        photos: storedPhotos,
      };

      await insertOrReplaceRecipe(newRecipe);
      setRecipes((prev) => [newRecipe, ...prev]);
      void hapticSuccess();
      void notificationManager.markUserAsActive();
      setTimeout(() => showRecipeAddedToast(), 320);
      return newRecipe;
    },
    [showRecipeAddedToast]
  );

  const updateRecipe = useCallback(
    async (input: UpdateRecipeInput): Promise<Recipe> => {
      const { original } = input;
      const clean = cleanRecipeDraft(input.draft);
      if (!clean.name) return original;
      const lang = getActiveLanguage();

      // Compare against localized baseline or stored fields to detect intentional text edits
      const baselineLocal =
        original.isCatalogSynced && original.catalogRecipeID
          ? getLocalMealRecord(original.catalogRecipeID, lang)
          : null;
      const baselineName = baselineLocal?.name ?? original.name;
      const baselineIngredients = baselineLocal?.ingredients ?? original.ingredients;
      const baselineInstructions = baselineLocal?.instructions ?? original.instructions;

      const textEdited =
        clean.name !== baselineName ||
        JSON.stringify(clean.ingredients) !== JSON.stringify(baselineIngredients) ||
        JSON.stringify(clean.instructions) !== JSON.stringify(baselineInstructions);

      const nextIsCatalogSynced = textEdited ? false : original.isCatalogSynced;

      const nonEmptyLines = input.ingredientLines.filter(
        (line) => line.text.replace(/[\r\n]+/g, ' ').trim().length > 0
      );
      const iconIDs = nonEmptyLines.map(
        (line) => line.iconID || findMatchingIconID(line.text, lang) || ''
      );
      while (iconIDs.length < clean.ingredients.length) iconIDs.push('');

      const remainingPhotos = original.photos.filter(
        (p) => !input.removedPhotoIDs.has(p.photoID)
      );
      const removedPhotos = original.photos.filter((p) =>
        input.removedPhotoIDs.has(p.photoID)
      );

      const finalPhotos: RecipePhoto[] = [
        ...remainingPhotos.map((p, idx) => ({ ...p, sortIndex: idx })),
        ...input.pendingPhotos
          .slice(0, Math.max(0, 5 - remainingPhotos.length))
          .map((p, idx) => ({
            photoID: generateUUID(),
            recipeID: original.recipeID,
            sortIndex: remainingPhotos.length + idx,
            imageUri: p.imageUri,
            thumbnailUri: p.thumbnailUri,
          })),
      ];

      const updated: Recipe = {
        ...original,
        name: !nextIsCatalogSynced || textEdited ? clean.name : original.name,
        ingredients:
          !nextIsCatalogSynced || textEdited
            ? clean.ingredients
            : original.ingredients,
        instructions:
          !nextIsCatalogSynced || textEdited
            ? clean.instructions
            : original.instructions,
        notes: clean.notes,
        source: clean.source,
        prepTime: sanitizeMinutes(input.prepTime),
        cookTime: sanitizeMinutes(input.cookTime),
        servings: sanitizeServings(input.servings),
        categoryRaw: input.category,
        coverIconID: input.coverIconID,
        usesCategoryCover: input.usesCategoryCover,
        ingredientIconIDs: iconIDs.slice(0, clean.ingredients.length),
        isCatalogSynced: nextIsCatalogSynced,
        dateModified: new Date().toISOString(),
        photos: finalPhotos,
      };

      await insertOrReplaceRecipe(updated);
      for (const removed of removedPhotos) {
        deletePhotoFiles(removed);
      }
      setRecipes((prev) =>
        prev.map((r) => (r.recipeID === updated.recipeID ? updated : r))
      );
      void notificationManager.markUserAsActive();
      return updated;
    },
    []
  );

  const deleteRecipe = useCallback(async (recipeID: string) => {
    await dbDeleteRecipeByID(recipeID);
    setRecipes((prev) => prev.filter((r) => r.recipeID !== recipeID));
    void notificationManager.markUserAsActive();
  }, []);

  const toggleFavorite = useCallback(
    async (recipeID: string) => {
      const current = recipes.find((r) => r.recipeID === recipeID);
      if (!current) return;
      const nextFav = !current.isFavorite;
      void hapticImpactLight();
      setRecipes((prev) =>
        prev.map((r) =>
          r.recipeID === recipeID ? { ...r, isFavorite: nextFav } : r
        )
      );
      await dbToggleRecipeFavorite(recipeID, nextFav);
    },
    [recipes]
  );

  const saveDiscoveredRecipe = useCallback(
    async (
      detail: DiscoveredRecipeDetail,
      options?: {
        englishDetail?: DiscoveredRecipeDetail | null;
        ingredientIcons?: string[];
      }
    ): Promise<DiscoveredRecipeSaveResult> => {
      const outcome = await saveDiscoveredRecipeToLibrary(detail, options);
      await refreshRecipes();
      void hapticSuccess();
      void notificationManager.markUserAsActive();
      return outcome;
    },
    [refreshRecipes]
  );

  const addGrocery = useCallback(async (rawName: string): Promise<boolean> => {
    const added = await dbAddGroceryItem(rawName);
    if (!added) return false;
    setGroceryItems((prev) => [...prev, added]);
    void hapticSuccess();
    void notificationManager.markUserAsActive();
    return true;
  }, []);

  const toggleGrocery = useCallback(
    async (itemID: string) => {
      const target = groceryItems.find((i) => i.itemID === itemID);
      if (!target) return;
      const nextChecked = !target.isChecked;
      const now = new Date().toISOString();
      setGroceryItems((prev) =>
        prev.map((i) =>
          i.itemID === itemID
            ? { ...i, isChecked: nextChecked, dateModified: now }
            : i
        )
      );
      await dbToggleGroceryItem(itemID, nextChecked);
      void notificationManager.markUserAsActive();
    },
    [groceryItems]
  );

  const editGrocery = useCallback(async (itemID: string, rawName: string) => {
    const cleaned = await dbUpdateGroceryItemName(itemID, rawName);
    if (!cleaned) return;
    const now = new Date().toISOString();
    setGroceryItems((prev) =>
      prev.map((i) =>
        i.itemID === itemID ? { ...i, name: cleaned, dateModified: now } : i
      )
    );
    void notificationManager.markUserAsActive();
  }, []);

  const removeGrocery = useCallback(async (itemID: string) => {
    setGroceryItems((prev) => prev.filter((i) => i.itemID !== itemID));
    await dbDeleteGroceryItem(itemID);
    void notificationManager.markUserAsActive();
  }, []);

  const clearCheckedGrocery = useCallback(async () => {
    setGroceryItems((prev) => prev.filter((i) => !i.isChecked));
    await dbClearCheckedGroceryItems();
    void notificationManager.markUserAsActive();
  }, []);

  const clearAllGrocery = useCallback(async () => {
    setGroceryItems([]);
    await dbClearAllGroceryItems();
    void notificationManager.markUserAsActive();
  }, []);

  const dismissWelcomeBack = useCallback(async () => {
    await notificationManager.dismissPrompt();
  }, []);

  const startCookingFromWelcome = useCallback(async () => {
    await notificationManager.markUserAsActive();
  }, []);

  const openPrivacySheet = useCallback((mode: PrivacySheetMode = 'settings') => {
    adMobController.openPrivacySheet(mode);
  }, []);

  const closePrivacySheet = useCallback(() => {
    adMobController.closePrivacySheet();
  }, []);

  const applyAdConsentChoice = useCallback(async (choice: AdConsentChoice) => {
    setAdConsentChoice(choice);
    await adMobController.applyUserConsentChoice(choice);
  }, []);

  const presentPlatformPrivacyOptions = useCallback(async () => {
    await adMobController.presentPlatformPrivacyOptions();
  }, []);

  const performAppUpdate = useCallback(async () => {
    await appUpdateManager.performUpdate();
  }, []);

  const dismissAppUpdate = useCallback(async () => {
    await appUpdateManager.dismissOptionalUpdate();
  }, []);

  const handleSharedPayload = useCallback(
    async (payload: SharedRecipePayload) => {
      const res = await consumeSharedRecipePayload(payload);
      if (res.errorMessage) {
        setImportBannerMessage(res.errorMessage);
        return;
      }
      if (res.saved) {
        await refreshRecipes();
        void notificationManager.markUserAsActive();
        showRecipeAddedToast();
      } else if (res.duplicate) {
        showToast(tFor(getActiveLanguage(), 'Already in Library'));
      }
    },
    [refreshRecipes, showRecipeAddedToast, showToast]
  );

  const adsAreUnobstructed =
    !welcomeBackVisible && !adState.presentPrivacySheet && updateInfo === null;

  const shareSupported = isExpoShareIntentSupported();

  return (
    <AppStateContext.Provider
      value={{
        isReady,
        storageWarning,
        recipes,
        groceryItems,
        hasSelectedInitialLanguage,
        hasCompletedTutorial,
        recipeSort,
        recipeFilter,
        grocerySort,
        adConsentChoice,
        adState,
        updateInfo,
        welcomeBackVisible,
        lastLoginDate,
        importBannerMessage,
        toastMessage,
        toastVisible,
        adsAreUnobstructed,
        showToast,
        showRecipeAddedToast,
        dismissImportBanner,
        selectInitialLanguage,
        setAppLanguage,
        completeTutorial,
        setRecipeSort,
        setRecipeFilter,
        setGrocerySort,
        saveNewRecipe,
        updateRecipe,
        deleteRecipe,
        toggleFavorite,
        saveDiscoveredRecipe,
        refreshRecipes,
        addGrocery,
        toggleGrocery,
        editGrocery,
        removeGrocery,
        clearCheckedGrocery,
        clearAllGrocery,
        dismissWelcomeBack,
        startCookingFromWelcome,
        openPrivacySheet,
        closePrivacySheet,
        applyAdConsentChoice,
        presentPlatformPrivacyOptions,
        performAppUpdate,
        dismissAppUpdate,
        handleSharedPayload,
      }}
    >
      {isReady && shareSupported && (
        <ShareIntentWatcher enabled={isReady} onPayload={handleSharedPayload} />
      )}
      {children}
    </AppStateContext.Provider>
  );
}

export function useAppState(): AppStateContextValue {
  const ctx = useContext(AppStateContext);
  if (!ctx) {
    throw new Error('useAppState must be used inside AppStateProvider');
  }
  return ctx;
}
