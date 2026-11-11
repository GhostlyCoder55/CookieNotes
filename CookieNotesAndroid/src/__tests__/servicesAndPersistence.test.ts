import { Image } from 'react-native';
import type { SQLExecutor } from '../database/db';
import type { Recipe } from '../types/models';

// In-memory SQLite relational emulator for repositories, migrations, and offline caches.
interface MemRow {
  [key: string]: unknown;
}

function createInMemoryExecutor() {
  const recipes = new Map<string, MemRow>();
  const photos = new Map<string, MemRow>();
  const groceries = new Map<string, MemRow>();
  const settings = new Map<string, string>();
  const cache = new Map<string, MemRow>();

  const executor: SQLExecutor & {
    withExclusiveTransactionAsync: (fn: (txn: SQLExecutor) => Promise<void>) => Promise<void>;
    __reset: () => void;
    __counts: () => { recipes: number; photos: number; groceries: number; settings: number };
  } = {
    async execAsync() {},
    async withExclusiveTransactionAsync(fn) {
      await fn(executor);
    },
    __reset() {
      recipes.clear();
      photos.clear();
      groceries.clear();
      settings.clear();
      cache.clear();
    },
    __counts() {
      return {
        recipes: recipes.size,
        photos: photos.size,
        groceries: groceries.size,
        settings: settings.size,
      };
    },
    async runAsync(source: string, ...params: unknown[]) {
      const sql = source.replace(/\s+/g, ' ').trim();

      if (sql.startsWith('INSERT OR REPLACE INTO app_settings')) {
        settings.set(String(params[0]), String(params[1]));
      } else if (sql.startsWith('DELETE FROM app_settings WHERE key = ?')) {
        settings.delete(String(params[0]));
      } else if (sql.startsWith('INSERT OR REPLACE INTO mealdb_cache')) {
        cache.set(String(params[0]), {
          cache_key: String(params[0]),
          payload_json: String(params[1]),
          updated_at: Number(params[2]),
        });
      } else if (sql.startsWith('INSERT OR REPLACE INTO recipes')) {
        recipes.set(String(params[0]), {
          recipe_id: params[0],
          name: params[1],
          ingredients_json: params[2],
          instructions_json: params[3],
          notes: params[4],
          source: params[5],
          prep_time: params[6],
          cook_time: params[7],
          servings: params[8],
          is_sample: params[9],
          is_imported: params[10],
          is_favorite: params[11],
          category_raw: params[12],
          ingredient_icon_ids_json: params[13],
          cover_icon_id: params[14],
          uses_category_cover: params[15],
          catalog_recipe_id: params[16],
          is_catalog_synced: params[17],
          synced_english_name: params[18],
          synced_english_ingredients_json: params[19],
          synced_english_instructions_json: params[20],
          date_created: params[21],
          date_modified: params[22],
        });
      } else if (sql.startsWith('UPDATE recipes SET is_favorite')) {
        const rec = recipes.get(String(params[2]));
        if (rec) {
          rec.is_favorite = params[0];
          rec.date_modified = params[1];
        }
      } else if (sql.startsWith('DELETE FROM recipe_photos WHERE recipe_id = ?')) {
        for (const [k, v] of photos.entries()) {
          if (v.recipe_id === String(params[0])) photos.delete(k);
        }
      } else if (sql.startsWith('DELETE FROM recipe_photos WHERE photo_id = ?')) {
        photos.delete(String(params[0]));
      } else if (sql.startsWith('INSERT INTO recipe_photos')) {
        photos.set(String(params[0]), {
          photo_id: params[0],
          recipe_id: params[1],
          sort_index: params[2],
          image_uri: params[3],
          thumbnail_uri: params[4],
        });
      } else if (sql.startsWith('DELETE FROM recipes WHERE recipe_id = ?')) {
        recipes.delete(String(params[0]));
      } else if (sql.startsWith('INSERT INTO grocery_items')) {
        groceries.set(String(params[0]), {
          item_id: params[0],
          name: params[1],
          is_checked: params[2],
          sort_order: params[3],
          date_created: params[4],
          date_modified: params[5],
        });
      } else if (sql.startsWith('UPDATE grocery_items SET is_checked')) {
        const item = groceries.get(String(params[2]));
        if (item) {
          item.is_checked = params[0];
          item.date_modified = params[1];
        }
      } else if (sql.startsWith('UPDATE grocery_items SET name')) {
        const item = groceries.get(String(params[2]));
        if (item) {
          item.name = params[0];
          item.date_modified = params[1];
        }
      } else if (sql.startsWith('DELETE FROM grocery_items WHERE item_id = ?')) {
        groceries.delete(String(params[0]));
      } else if (sql.startsWith('DELETE FROM grocery_items WHERE is_checked = 1')) {
        for (const [k, v] of groceries.entries()) {
          if (v.is_checked === 1) groceries.delete(k);
        }
      } else if (sql.startsWith('DELETE FROM grocery_items')) {
        groceries.clear();
      }
      return { changes: 1, lastInsertRowId: 1 } as never;
    },
    async getFirstAsync<T>(source: string, ...params: unknown[]): Promise<T | null> {
      const sql = source.replace(/\s+/g, ' ').trim();
      if (sql.includes('FROM app_settings WHERE key = ?')) {
        const value = settings.get(String(params[0]));
        return value !== undefined ? ({ value } as T) : null;
      }
      if (sql.includes('FROM recipes WHERE recipe_id = ?')) {
        return (recipes.get(String(params[0])) as T | undefined) ?? null;
      }
      if (sql.includes('FROM mealdb_cache WHERE cache_key = ?')) {
        return (cache.get(String(params[0])) as T | undefined) ?? null;
      }
      return null;
    },
    async getAllAsync<T>(source: string, ...params: unknown[]): Promise<T[]> {
      const sql = source.replace(/\s+/g, ' ').trim();
      if (sql.includes('FROM recipes')) {
        return Array.from(recipes.values()).sort((a, b) =>
          String(b.date_created).localeCompare(String(a.date_created))
        ) as T[];
      }
      if (sql.includes('FROM recipe_photos WHERE recipe_id = ?')) {
        return Array.from(photos.values()).filter(
          (p) => p.recipe_id === String(params[0])
        ) as T[];
      }
      if (sql.includes('FROM recipe_photos')) {
        return Array.from(photos.values()) as T[];
      }
      if (sql.includes('FROM grocery_items')) {
        return Array.from(groceries.values()).sort(
          (a, b) => Number(a.sort_order) - Number(b.sort_order)
        ) as T[];
      }
      if (sql.includes('FROM app_settings')) {
        return Array.from(settings.entries()).map(([key, value]) => ({
          key,
          value,
        })) as T[];
      }
      return [];
    },
  };

  return executor;
}

const mockExecutor = createInMemoryExecutor();

jest.mock('expo-sqlite', () => ({
  openDatabaseAsync: jest.fn(async () => mockExecutor),
}));

jest.mock('expo-file-system', () => ({
  Directory: class {
    uri = 'file:///mock/photos';
    exists = true;
    create() {}
  },
  File: class {
    uri: string;
    exists = true;
    constructor(...parts: unknown[]) {
      this.uri = String(parts[parts.length - 1] ?? 'file:///mock/photo.jpg');
    }
    copySync() {}
    delete() {}
    static downloadFileAsync: jest.Mock = jest.fn(async () => ({
      uri: 'file:///mock/dl.img',
      exists: true,
      delete() {},
    }));
  },
  Paths: { document: 'file:///mock/doc', cache: 'file:///mock/cache' },
}));

jest.mock('expo-image-manipulator', () => ({
  SaveFormat: { JPEG: 'jpeg' },
  manipulateAsync: jest.fn(async (uri: string) => ({ uri })),
}));

jest.mock('expo-notifications', () => ({
  AndroidImportance: { DEFAULT: 3 },
  SchedulableTriggerInputTypes: { TIME_INTERVAL: 'timeInterval' },
  setNotificationHandler: jest.fn(),
  setNotificationChannelAsync: jest.fn(async () => {}),
  getPermissionsAsync: jest.fn(async () => ({ status: 'granted' })),
  requestPermissionsAsync: jest.fn(async () => ({ status: 'granted' })),
  cancelAllScheduledNotificationsAsync: jest.fn(async () => {}),
  scheduleNotificationAsync: jest.fn(async () => 'id-1'),
  setBadgeCountAsync: jest.fn(async () => {}),
}));

import { manipulateAsync } from 'expo-image-manipulator';
import {
  FULL_PHOTO_MAX_EDGE,
  processAndSavePhotoFromUri,
  THUMBNAIL_MAX_EDGE,
} from '../utils/photoProcessing';
import { getLocalMealDetail } from '../data/localMealCatalog';
import { getTheMealDBRecord } from '../data/theMealDBCatalog';
import {
  addGroceryItem,
  clearAllGroceryItems,
  clearCheckedGroceryItems,
  deleteGroceryItem,
  fetchAllGroceryItems,
  toggleGroceryItem,
  updateGroceryItemName,
} from '../database/groceryRepository';
import { runStartupMigrations } from '../database/migrations';
import {
  fetchAllRecipes,
  insertOrReplaceRecipe,
  saveDiscoveredRecipeToLibrary,
} from '../database/recipeRepository';
import { getStoredAdConsent, saveAdConsent } from '../services/adConsentStore';
import {
  GOOGLE_ANDROID_TEST_BANNER_ID,
  resolveAdSettings,
} from '../services/adConfiguration';
import { blocksFromSlots, browsingSlots, searchSlots, showsContentBanner } from '../services/adPlacement';
import {
  APP_INSTALLED_VERSION,
  appUpdateManager,
  compareSemanticVersions,
  evaluateRemoteUpdateConfig,
  parseSemanticVersion,
} from '../services/appUpdateManager';
import { consumeSharedRecipePayload } from '../services/importCoordinator';
import { shouldPromptWelcomeBack } from '../services/notificationManager';
import { setActiveLanguage } from '../localization/i18n';
import { resolveLocalizedIngredients, resolveLocalizedRecipeName } from '../utils/recipeLibrary';
import { RecipeInputLimits } from '../constants/limits';

function makeSampleRecipe(overrides: Partial<Recipe>): Recipe {
  const now = '2026-10-01T12:00:00.000Z';
  return {
    recipeID: 'id-1',
    name: 'Recipe',
    ingredients: ['salt'],
    instructions: ['Cook'],
    notes: '',
    source: '',
    prepTime: 0,
    cookTime: 0,
    servings: 0,
    isSample: false,
    isImported: false,
    isFavorite: false,
    categoryRaw: 'uncategorized',
    ingredientIconIDs: [],
    coverIconID: '',
    usesCategoryCover: false,
    catalogRecipeID: '',
    isCatalogSynced: false,
    syncedEnglishName: '',
    syncedEnglishIngredients: [],
    syncedEnglishInstructions: [],
    dateCreated: now,
    dateModified: now,
    photos: [],
    ...overrides,
  };
}

describe('Services, Ad Policy, Update Checker, Migrations, and SQLite Persistence', () => {
  beforeEach(() => {
    mockExecutor.__reset();
    setActiveLanguage('en');
    jest.restoreAllMocks();
    jest.spyOn(Image, 'getSize').mockImplementation((_uri, success) => {
      if (typeof success === 'function') success(2000, 1000);
    });
  });

  test('PhotoProcessing downscales oversized images to full (1600px) and thumbnail (480px) limits', async () => {
    const res = await processAndSavePhotoFromUri('file:///source/big_dish.jpg');
    expect(res).not.toBeNull();
    expect(res?.imageUri).toContain('_full.jpg');
    expect(res?.thumbnailUri).toContain('_thumb.jpg');
    expect(manipulateAsync).toHaveBeenNthCalledWith(
      1,
      'file:///source/big_dish.jpg',
      [{ resize: { width: FULL_PHOTO_MAX_EDGE } }],
      expect.objectContaining({ compress: 0.82 })
    );
    expect(manipulateAsync).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('_full.jpg'),
      [{ resize: { width: THUMBNAIL_MAX_EDGE } }],
      expect.objectContaining({ compress: 0.72 })
    );
    expect(await processAndSavePhotoFromUri('')).toBeNull();
  });

  test('AdConfiguration resolves debug test ads and fails closed in production if IDs invalid/mismatched', () => {
    const debug = resolveAdSettings({
      isDebugBuild: true,
      allowTestAds: false,
      forceProductionAds: false,
      applicationID: 'ca-app-pub-1234567890123456~1234567890',
      bannerAdUnitID: 'ca-app-pub-1234567890123456/1234567890',
      privacyPolicyURLString: 'https://example.com/privacy',
    });
    expect(debug.mode).toBe('test');
    expect(debug.bannerAdUnitID).toBe(GOOGLE_ANDROID_TEST_BANNER_ID);

    const blankRelease = resolveAdSettings({
      isDebugBuild: false,
      allowTestAds: false,
      forceProductionAds: true,
      applicationID: '',
      bannerAdUnitID: '',
    });
    expect(blankRelease.mode).toBe('disabled');
    expect(blankRelease.bannerAdUnitID).toBe('');

    const sampleRelease = resolveAdSettings({
      isDebugBuild: false,
      allowTestAds: false,
      forceProductionAds: true,
      applicationID: 'ca-app-pub-3940256099942544~3347511713',
      bannerAdUnitID: GOOGLE_ANDROID_TEST_BANNER_ID,
    });
    expect(sampleRelease.mode).toBe('disabled');

    const mismatched = resolveAdSettings({
      isDebugBuild: false,
      allowTestAds: false,
      forceProductionAds: true,
      applicationID: 'ca-app-pub-1234567890123456~1234567890',
      bannerAdUnitID: 'ca-app-pub-9999999999999999/1234567890',
      privacyPolicyURLString: 'http://insecure.example.com/privacy',
    });
    expect(mismatched.mode).toBe('disabled');
    expect(mismatched.privacyPolicyURL?.startsWith('https://')).toBe(true);

    const validRelease = resolveAdSettings({
      isDebugBuild: false,
      allowTestAds: false,
      forceProductionAds: true,
      applicationID: 'ca-app-pub-8075634631393674~1234567890',
      bannerAdUnitID: 'ca-app-pub-8075634631393674/0987654321',
      privacyPolicyURLString: 'https://ghostlycoder55.github.io/CookieNotes-privacy/',
    });
    expect(validRelease.mode).toBe('production');
    expect(validRelease.bannerAdUnitID).toBe('ca-app-pub-8075634631393674/0987654321');
  });

  test('AdPlacement schedules inline feed ads safely and hides ads on empty states', () => {
    expect(browsingSlots(0, true)).toEqual([]);
    expect(searchSlots(0, true)).toEqual([]);
    expect(showsContentBanner(true, false)).toBe(false);

    const shortList = browsingSlots(3, true);
    expect(shortList.filter((s) => s.kind === 'advertisement').length).toBe(1);
    expect(shortList[shortList.length - 1]).toEqual({ kind: 'advertisement', adIndex: 0 });

    const longList = browsingSlots(13, true);
    expect(longList.filter((s) => s.kind === 'advertisement').length).toBe(2);
    expect(blocksFromSlots(longList).some((b) => b.kind === 'advertisement')).toBe(true);

    expect(searchSlots(2, true)).toEqual([
      { kind: 'item', index: 0 },
      { kind: 'item', index: 1 },
      { kind: 'advertisement', adIndex: 0 },
    ]);
  });

  test('AdConsentStore defaults to allowed and persists toggle cleanly', async () => {
    expect(await getStoredAdConsent()).toBe('allowed');
    await saveAdConsent('declined');
    expect(await getStoredAdConsent()).toBe('declined');
    await saveAdConsent('allowed');
    expect(await getStoredAdConsent()).toBe('allowed');
  });

  test('AppUpdateManager validates semver, enforces mandatory updates, and respects dismissal', async () => {
    expect(parseSemanticVersion('')).toBeNull();
    expect(parseSemanticVersion('abc')).toBeNull();
    expect(compareSemanticVersions('1.0', '1.0.0')).toBe(0);
    expect(compareSemanticVersions('1.9.9', '1.10.0')).toBe(-1);
    expect(compareSemanticVersions('2.0.0-beta.1', '1.10.0')).toBe(1);

    const mandatoryInfo = evaluateRemoteUpdateConfig(
      {
        latestVersion: '2.0.0',
        minimumRequiredVersion: '1.5.0',
        isMandatory: false,
        playStoreURL: 'https://play.google.com/store/apps/details?id=com.gc.cookienotes',
      },
      APP_INSTALLED_VERSION,
      'fr'
    )!;
    expect(mandatoryInfo.isMandatory).toBe(true);
    expect(mandatoryInfo.version).toBe('2.0.0');

    jest.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        latestVersion: '1.1.0',
        minimumRequiredVersion: '1.0.0',
        isMandatory: false,
      }),
    } as Response);

    appUpdateManager.remoteConfigURL = 'https://localhost/update-config.json';
    await appUpdateManager.checkForUpdates({ force: true });
    expect(appUpdateManager.updateInfo?.version).toBe('1.1.0');

    await appUpdateManager.dismissOptionalUpdate();
    expect(appUpdateManager.updateInfo).toBeNull();

    jest.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        latestVersion: '1.1.0',
        minimumRequiredVersion: '1.0.0',
        isMandatory: false,
      }),
    } as Response);
    await appUpdateManager.checkForUpdates({ force: true });
    expect(appUpdateManager.updateInfo).toBeNull();

    jest.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        latestVersion: '1.2.0',
        minimumRequiredVersion: '1.0.0',
        isMandatory: false,
      }),
    } as Response);
    await appUpdateManager.checkForUpdates({ force: true });
    expect(appUpdateManager.updateInfo?.version).toBe('1.2.0');
  });

  test('NotificationManager prompts only after 7+ days inactivity', () => {
    const now = new Date('2026-11-11T12:00:00.000Z');
    const sixDaysAgo = new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000).toISOString();
    const eightDaysAgo = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000).toISOString();

    expect(shouldPromptWelcomeBack(null, now.getTime())).toBe(false);
    expect(shouldPromptWelcomeBack(sixDaysAgo, now.getTime())).toBe(false);
    expect(shouldPromptWelcomeBack(eightDaysAgo, now.getTime())).toBe(true);
  });

  test('saveDiscoveredRecipeToLibrary is idempotent and syncs across EN/FR/ES without duplicating rows', async () => {
    const jollofEN = getLocalMealDetail('local-jollof-rice', 'en')!;
    const first = await saveDiscoveredRecipeToLibrary(jollofEN);
    expect(first).toBe('inserted');

    let all = await fetchAllRecipes();
    expect(all.length).toBe(1);
    expect(all[0].catalogRecipeID).toBe('local-jollof-rice');
    expect(all[0].isCatalogSynced).toBe(true);

    // Preserve user favorite & notes on French re-save
    await insertOrReplaceRecipe({ ...all[0], isFavorite: true, notes: 'Sunday dinner' });

    setActiveLanguage('fr');
    const jollofFR = getLocalMealDetail('local-jollof-rice', 'fr')!;
    const second = await saveDiscoveredRecipeToLibrary(jollofFR);
    expect(second).toBe('updatedExisting');

    all = await fetchAllRecipes();
    expect(all.length).toBe(1);
    expect(all[0].isFavorite).toBe(true);
    expect(all[0].notes).toBe('Sunday dinner');
    expect(resolveLocalizedRecipeName(all[0], 'fr')).toBe('Riz jollof');

    // Remote French MealDB record saved with English snapshot resolves bidirectionally
    const carrotsFR = getTheMealDBRecord('53282')!;
    const remoteSave = await saveDiscoveredRecipeToLibrary(
      {
        id: '53282',
        name: carrotsFR.name,
        category: carrotsFR.category ?? null,
        area: carrotsFR.area ?? null,
        ingredients: carrotsFR.ingredients,
        instructions: carrotsFR.instructions,
        thumbnailURL: null,
        sourceURL: 'https://www.themealdb.com/meal/53282',
        youtubeURL: null,
        tags: [],
      },
      {
        englishDetail: {
          id: '53282',
          name: 'Algerian Carrots',
          category: 'Vegetarian',
          area: 'Algerian',
          ingredients: ['4 Carrots', '1 tsp Thyme'],
          instructions: ['Steam carrots until tender.'],
          thumbnailURL: null,
          sourceURL: 'https://www.themealdb.com/meal/53282',
          youtubeURL: null,
          tags: [],
        },
      }
    );
    expect(remoteSave).toBe('inserted');

    all = await fetchAllRecipes();
    const carrots = all.find((r) => r.catalogRecipeID === '53282')!;
    expect(resolveLocalizedRecipeName(carrots, 'fr')).toBe('Carottes algériennes');
    expect(resolveLocalizedRecipeName(carrots, 'en')).toBe('Algerian Carrots');
    expect(resolveLocalizedIngredients(carrots, 'en')).toEqual(['4 Carrots', '1 tsp Thyme']);
  });

  test('Startup migrations purge samples, demos, Bouzgene, and deduplicate legacy catalog entries', async () => {
    await insertOrReplaceRecipe(
      makeSampleRecipe({ recipeID: 'sample-1', name: 'Sample Dish', isSample: true })
    );
    await insertOrReplaceRecipe(
      makeSampleRecipe({ recipeID: 'demo-1', name: 'Cambodian Waffles (Num Poum)' })
    );
    await insertOrReplaceRecipe(
      makeSampleRecipe({
        recipeID: 'bouz-1',
        name: 'Algerian Bouzgene Berber Bread',
        categoryRaw: 'sides' as never,
      })
    );
    await insertOrReplaceRecipe(
      makeSampleRecipe({
        recipeID: 'snack-1',
        name: 'Grandma Granola',
        categoryRaw: 'snack' as never,
      })
    );
    await insertOrReplaceRecipe(
      makeSampleRecipe({
        recipeID: 'legacy-1',
        name: 'Queues de castor (BeaverTails)',
        source: 'https://www.tastemade.com/videos/beavertails',
        notes: 'Warm cinnamon sugar',
        isImported: true,
        isFavorite: true,
        dateCreated: '2026-01-01T00:00:00.000Z',
      })
    );
    await insertOrReplaceRecipe(
      makeSampleRecipe({
        recipeID: 'legacy-2',
        name: 'Queues de castor',
        source: 'la base de recettes · Canadienne · Dessert',
        isImported: true,
        dateCreated: '2026-02-01T00:00:00.000Z',
        photos: [
          {
            photoID: 'p-1',
            recipeID: 'legacy-2',
            sortIndex: 0,
            imageUri: 'file:///p1.jpg',
            thumbnailUri: 'file:///p1t.jpg',
          },
        ],
      })
    );
    await insertOrReplaceRecipe(
      makeSampleRecipe({
        recipeID: 'alfredo-1',
        name: 'Fettuccine Alfredo',
        source: 'https://www.themealdb.com/meal/53064',
        isImported: true,
      })
    );
    await insertOrReplaceRecipe(
      makeSampleRecipe({
        recipeID: 'alfredo-2',
        name: 'Fettuccine Alfredo',
        source: 'https://www.themealdb.com/meal/52835',
        isImported: true,
      })
    );

    await runStartupMigrations();

    const remaining = await fetchAllRecipes();
    // Expected: Grandma Granola + 1 merged BeaverTails + 2 distinct Fettuccine Alfredo = 4
    expect(remaining.length).toBe(4);
    expect(remaining.some((r) => r.name.includes('Bouzgene'))).toBe(false);
    expect(remaining.some((r) => r.name.includes('Cambodian Waffles'))).toBe(false);

    const granola = remaining.find((r) => r.name === 'Grandma Granola')!;
    expect(granola.categoryRaw).toBe('uncategorized');

    const beaver = remaining.find((r) => r.catalogRecipeID === '52928')!;
    expect(beaver.isFavorite).toBe(true);
    expect(beaver.notes).toContain('Warm cinnamon sugar');
    expect(beaver.photos.length).toBe(1);

    const alfredoIDs = remaining
      .filter((r) => r.name === 'Fettuccine Alfredo')
      .map((r) => r.catalogRecipeID)
      .sort();
    expect(alfredoIDs).toEqual(['52835', '53064']);
  });

  test('ImportCoordinator skips duplicate shared URLs and enforces image byte limit', async () => {
    const first = await consumeSharedRecipePayload({
      title: 'Apple Tart',
      text: '- 2 apples',
      url: 'https://example.com/apple-tart',
    });
    expect(first.saved).toBe(true);

    const dup = await consumeSharedRecipePayload({
      title: 'Tarte aux pommes',
      text: '- 2 pommes',
      url: 'HTTPS://EXAMPLE.COM/apple-tart',
    });
    expect(dup.saved).toBe(false);
    expect(dup.duplicate).toBe(true);

    const oversized = await consumeSharedRecipePayload({
      title: 'Too Big',
      text: 'Recipe notes',
      url: '',
      imageUri: 'file:///huge.jpg',
      imageSizeBytes: RecipeInputLimits.sharedImageBytes + 1,
    });
    expect(oversized.saved).toBe(true);
    expect(oversized.errorMessage).toBeNull();

    const withValidPhoto = await consumeSharedRecipePayload({
      title: 'With Small Photo',
      text: 'Recipe notes',
      url: '',
      imageUri: 'file:///ok.jpg',
      imageSizeBytes: 1024,
    });
    expect(withValidPhoto.saved).toBe(true);

    const stored = await fetchAllRecipes();
    expect(stored.length).toBe(3);
    expect(stored.find((r) => r.name === 'Too Big')?.photos).toEqual([]);
    expect(stored.find((r) => r.name === 'With Small Photo')?.photos.length).toBe(1);
  });

  test('GroceryRepository supports full persistent CRUD (add, toggle, edit, delete, clear checked, clear all)', async () => {
    const milk = (await addGroceryItem('  Milk  '))!;
    const eggs = (await addGroceryItem('Eggs'))!;
    const bread = (await addGroceryItem('Bread'))!;

    expect(milk.name).toBe('Milk');
    expect(milk.isChecked).toBe(false);
    expect((await fetchAllGroceryItems()).length).toBe(3);

    await toggleGroceryItem(milk.itemID, true);
    await updateGroceryItemName(eggs.itemID, 'Organic Eggs');

    let items = await fetchAllGroceryItems();
    expect(items.find((i) => i.itemID === milk.itemID)?.isChecked).toBe(true);
    expect(items.find((i) => i.itemID === eggs.itemID)?.name).toBe('Organic Eggs');

    await clearCheckedGroceryItems();
    items = await fetchAllGroceryItems();
    expect(items.map((i) => i.itemID)).toEqual([eggs.itemID, bread.itemID]);

    await deleteGroceryItem(eggs.itemID);
    items = await fetchAllGroceryItems();
    expect(items.map((i) => i.itemID)).toEqual([bread.itemID]);

    await clearAllGroceryItems();
    expect(await fetchAllGroceryItems()).toEqual([]);
  });
});
