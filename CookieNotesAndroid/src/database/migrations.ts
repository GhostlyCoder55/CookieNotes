import { getLocalMealRecord } from '../data/localMealCatalog';
import type { Recipe } from '../types/models';
import { canonicalRecipeID, isExcludedMeal } from '../utils/mealIdentity';
import {
  inferredLegacyCatalogID,
  matchesExpectedCatalogShape,
} from './catalogIdentity';
import { getDatabase } from './db';
import {
  deleteRecipeByID,
  fetchAllRecipes,
  insertOrReplaceRecipe,
} from './recipeRepository';
import {
  getBooleanSetting,
  getSetting,
  setBooleanSetting,
  setSetting,
  SettingKeys,
} from './settingsRepository';

const LEGACY_DEMO_NAMES_EXACT = new Set([
  'Weeknight Fried Rice',
  'Riz frit de semaine',
  'Chocolate Chip Cookies',
]);

function isLegacyDemoRecipe(name: string): boolean {
  if (LEGACY_DEMO_NAMES_EXACT.has(name)) return true;
  const lowered = name.toLowerCase();
  return lowered.includes('cambodian waffles') || lowered.includes('num poum');
}

export async function runStartupMigrations(): Promise<void> {
  const db = await getDatabase();

  // 1. Remove sample recipes so library shows only the user's own notes
  const allAfterSampleCheck = await fetchAllRecipes(db);
  for (const recipe of allAfterSampleCheck) {
    if (recipe.isSample) {
      await deleteRecipeByID(recipe.recipeID, db);
    }
  }

  // 2. Remove legacy demo recipes (once)
  const didPurgeDemos = await getBooleanSetting(SettingKeys.didPurgeDemoRecipes, false, db);
  if (!didPurgeDemos) {
    const recipes = await fetchAllRecipes(db);
    for (const recipe of recipes) {
      if (isLegacyDemoRecipe(recipe.name)) {
        await deleteRecipeByID(recipe.recipeID, db);
      }
    }
    await setBooleanSetting(SettingKeys.didPurgeDemoRecipes, true, db);
  }

  // 3. Purge excluded Bouzgene recipes & migrate legacy snack categories (once)
  const didPurgeExcluded = await getBooleanSetting(
    SettingKeys.didPurgeExcludedAndMigrateSnackV1,
    false,
    db
  );
  if (!didPurgeExcluded) {
    const recipes = await fetchAllRecipes(db);
    for (const recipe of recipes) {
      if (
        isExcludedMeal(recipe.catalogRecipeID, recipe.name) ||
        recipe.source.includes('53284')
      ) {
        await deleteRecipeByID(recipe.recipeID, db);
      } else if (
        (recipe.categoryRaw as string).toLowerCase() === 'snack' ||
        (recipe.categoryRaw as string).toLowerCase() === 'snacks'
      ) {
        await insertOrReplaceRecipe(
          { ...recipe, categoryRaw: 'uncategorized' },
          db
        );
      }
    }
    const storedFilter = await getSetting(SettingKeys.recipeFilter, db);
    if (storedFilter === 'snack') {
      await setSetting(SettingKeys.recipeFilter, 'all', db);
    }
    await setBooleanSetting(SettingKeys.didPurgeExcludedAndMigrateSnackV1, true, db);
  }

  // 4. Deduplicate catalog recipes & normalize catalog IDs (once)
  const didMigrateIdentity = await getBooleanSetting(
    SettingKeys.didMigrateCatalogIdentityV1,
    false,
    db
  );
  if (!didMigrateIdentity) {
    const recipes = (await fetchAllRecipes(db)).filter((r) => !r.isSample);
    const updatedRecipes: Recipe[] = [];

    for (const original of recipes) {
      const recipe = { ...original };
      if (recipe.catalogRecipeID.length > 0) {
        const normalized = canonicalRecipeID(recipe.catalogRecipeID);
        if (normalized !== recipe.catalogRecipeID) {
          recipe.catalogRecipeID = normalized;
          await insertOrReplaceRecipe(recipe, db);
        }
        updatedRecipes.push(recipe);
        continue;
      }

      if (recipe.isImported) {
        const inferred = inferredLegacyCatalogID(recipe);
        if (inferred) {
          recipe.catalogRecipeID = inferred;
          if (matchesExpectedCatalogShape(recipe, inferred)) {
            recipe.isCatalogSynced = true;
          }
          await insertOrReplaceRecipe(recipe, db);
        }
      }
      updatedRecipes.push(recipe);
    }

    const grouped = new Map<string, Recipe[]>();
    for (const recipe of updatedRecipes) {
      if (!recipe.catalogRecipeID) continue;
      const list = grouped.get(recipe.catalogRecipeID) ?? [];
      list.push(recipe);
      grouped.set(recipe.catalogRecipeID, list);
    }

    for (const group of grouped.values()) {
      if (group.length <= 1) continue;
      const sorted = [...group].sort((lhs, rhs) => {
        const lhsPhotos = lhs.photos.length > 0 ? 1 : 0;
        const rhsPhotos = rhs.photos.length > 0 ? 1 : 0;
        if (lhsPhotos !== rhsPhotos) return rhsPhotos - lhsPhotos;

        const lhsNotes = lhs.notes.trim().length > 0 ? 1 : 0;
        const rhsNotes = rhs.notes.trim().length > 0 ? 1 : 0;
        if (lhsNotes !== rhsNotes) return rhsNotes - lhsNotes;

        if (lhs.isFavorite !== rhs.isFavorite) return lhs.isFavorite ? -1 : 1;
        if (lhs.dateCreated !== rhs.dateCreated) {
          return lhs.dateCreated.localeCompare(rhs.dateCreated);
        }
        return lhs.recipeID.localeCompare(rhs.recipeID);
      });

      const keeper = { ...sorted[0], photos: [...sorted[0].photos] };
      let mergedNotes = keeper.notes.trim();

      for (const dup of sorted.slice(1)) {
        if (dup.isFavorite) keeper.isFavorite = true;
        if (dup.dateCreated < keeper.dateCreated) {
          keeper.dateCreated = dup.dateCreated;
        }
        const dupNote = dup.notes.trim();
        if (
          dupNote.length > 0 &&
          !mergedNotes.toLowerCase().includes(dupNote.toLowerCase())
        ) {
          mergedNotes = mergedNotes.length === 0 ? dupNote : `${mergedNotes}\n\n${dupNote}`;
        }
        if (!keeper.syncedEnglishName) {
          if (dup.syncedEnglishName) {
            keeper.syncedEnglishName = dup.syncedEnglishName;
            keeper.syncedEnglishIngredients = dup.syncedEnglishIngredients;
            keeper.syncedEnglishInstructions = dup.syncedEnglishInstructions;
          } else {
            const englishFallback = getLocalMealRecord(keeper.catalogRecipeID, 'en');
            if (englishFallback) {
              keeper.syncedEnglishName = englishFallback.name;
              keeper.syncedEnglishIngredients = englishFallback.ingredients;
              keeper.syncedEnglishInstructions = englishFallback.instructions;
            }
          }
        }
        if (keeper.photos.length === 0 && dup.photos.length > 0) {
          const reassigned = {
            ...dup.photos[0],
            recipeID: keeper.recipeID,
            sortIndex: 0,
          };
          keeper.photos = [reassigned];
          // Avoid deleting physical photo file we just adopted onto keeper
          dup.photos = dup.photos.slice(1);
          await db.runAsync(
            'DELETE FROM recipe_photos WHERE photo_id = ?',
            reassigned.photoID
          );
        }
        await deleteRecipeByID(dup.recipeID, db);
      }

      keeper.notes = mergedNotes;
      await insertOrReplaceRecipe(keeper, db);
    }

    await setBooleanSetting(SettingKeys.didMigrateCatalogIdentityV1, true, db);
  }

  // 5. Mark fresh install initial setup done (starts with empty library)
  const didSetup = await getBooleanSetting(SettingKeys.didFinishInitialLibrarySetup, false, db);
  if (!didSetup) {
    await setBooleanSetting(SettingKeys.didFinishInitialLibrarySetup, true, db);
    await setBooleanSetting(SettingKeys.didPurgeDemoRecipes, true, db);
  }
}
