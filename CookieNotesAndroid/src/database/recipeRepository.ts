import { getLocalMealRecord } from '../data/localMealCatalog';
import { getActiveLanguage } from '../localization/i18n';
import type {
  DiscoveredRecipeDetail,
  DiscoveredRecipeSaveResult,
  Recipe,
  RecipePhoto,
} from '../types/models';
import { findMatchingIconID } from '../utils/ingredientCatalog';
import { canonicalRecipeID } from '../utils/mealIdentity';
import {
  deletePhotoFiles,
  downloadAndSaveRemotePhoto,
  type StoredPhotoPaths,
} from '../utils/photoProcessing';
import {
  getCategoryIconName,
  inferCategoryFromMealDB,
  parseRecipeCategory,
} from '../utils/recipeCategory';
import {
  cleanInstructions,
  sanitizeMinutes,
  sanitizeServings,
} from '../utils/recipeSanitizer';
import { estimateRecipeTime } from '../utils/recipeTimeEstimator';
import { generateUUID } from '../utils/uuid';
import { getDatabase, type SQLExecutor } from './db';
import { getRecipeAttribution } from './recipeAttribution';
import { inferredLegacyCatalogID } from './catalogIdentity';

interface RecipeRow {
  recipe_id: string;
  name: string;
  ingredients_json: string;
  instructions_json: string;
  notes: string;
  source: string;
  prep_time: number;
  cook_time: number;
  servings: number;
  is_sample: number;
  is_imported: number;
  is_favorite: number;
  category_raw: string;
  ingredient_icon_ids_json: string;
  cover_icon_id: string;
  uses_category_cover: number;
  catalog_recipe_id: string;
  is_catalog_synced: number;
  synced_english_name: string;
  synced_english_ingredients_json: string;
  synced_english_instructions_json: string;
  date_created: string;
  date_modified: string;
}

interface RecipePhotoRow {
  photo_id: string;
  recipe_id: string;
  sort_index: number;
  image_uri: string;
  thumbnail_uri: string;
}

function parseJsonStringArray(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.map((v) => String(v)) : [];
  } catch {
    return [];
  }
}

function rowToRecipe(row: RecipeRow, photos: RecipePhoto[]): Recipe {
  return {
    recipeID: row.recipe_id,
    name: row.name,
    ingredients: parseJsonStringArray(row.ingredients_json),
    instructions: parseJsonStringArray(row.instructions_json),
    notes: row.notes,
    source: row.source,
    prepTime: row.prep_time,
    cookTime: row.cook_time,
    servings: row.servings,
    isSample: row.is_sample === 1,
    isImported: row.is_imported === 1,
    isFavorite: row.is_favorite === 1,
    categoryRaw: parseRecipeCategory(row.category_raw),
    ingredientIconIDs: parseJsonStringArray(row.ingredient_icon_ids_json),
    coverIconID: row.cover_icon_id,
    usesCategoryCover: row.uses_category_cover === 1,
    catalogRecipeID: row.catalog_recipe_id,
    isCatalogSynced: row.is_catalog_synced === 1,
    syncedEnglishName: row.synced_english_name,
    syncedEnglishIngredients: parseJsonStringArray(row.synced_english_ingredients_json),
    syncedEnglishInstructions: parseJsonStringArray(row.synced_english_instructions_json),
    dateCreated: row.date_created,
    dateModified: row.date_modified,
    photos: [...photos].sort((a, b) =>
      a.sortIndex !== b.sortIndex
        ? a.sortIndex - b.sortIndex
        : a.photoID.localeCompare(b.photoID)
    ),
  };
}

function rowToPhoto(row: RecipePhotoRow): RecipePhoto {
  return {
    photoID: row.photo_id,
    recipeID: row.recipe_id,
    sortIndex: row.sort_index,
    imageUri: row.image_uri,
    thumbnailUri: row.thumbnail_uri,
  };
}

export async function fetchAllRecipes(executor?: SQLExecutor): Promise<Recipe[]> {
  const db = executor ?? (await getDatabase());
  const [recipeRows, photoRows] = await Promise.all([
    db.getAllAsync<RecipeRow>('SELECT * FROM recipes ORDER BY date_created DESC'),
    db.getAllAsync<RecipePhotoRow>(
      'SELECT * FROM recipe_photos ORDER BY sort_index ASC, photo_id ASC'
    ),
  ]);

  const photosByRecipe = new Map<string, RecipePhoto[]>();
  for (const photoRow of photoRows) {
    const list = photosByRecipe.get(photoRow.recipe_id) ?? [];
    list.push(rowToPhoto(photoRow));
    photosByRecipe.set(photoRow.recipe_id, list);
  }

  return recipeRows.map((row) => rowToRecipe(row, photosByRecipe.get(row.recipe_id) ?? []));
}

export async function fetchRecipeByID(
  recipeID: string,
  executor?: SQLExecutor
): Promise<Recipe | null> {
  const db = executor ?? (await getDatabase());
  const row = await db.getFirstAsync<RecipeRow>(
    'SELECT * FROM recipes WHERE recipe_id = ?',
    recipeID
  );
  if (!row) return null;
  const photoRows = await db.getAllAsync<RecipePhotoRow>(
    'SELECT * FROM recipe_photos WHERE recipe_id = ? ORDER BY sort_index ASC, photo_id ASC',
    recipeID
  );
  return rowToRecipe(row, photoRows.map(rowToPhoto));
}

export async function insertOrReplaceRecipe(
  recipe: Recipe,
  executor?: SQLExecutor
): Promise<void> {
  const execute = async (conn: SQLExecutor) => {
    await conn.runAsync(
      `INSERT OR REPLACE INTO recipes (
        recipe_id, name, ingredients_json, instructions_json, notes, source,
        prep_time, cook_time, servings, is_sample, is_imported, is_favorite,
        category_raw, ingredient_icon_ids_json, cover_icon_id, uses_category_cover,
        catalog_recipe_id, is_catalog_synced, synced_english_name,
        synced_english_ingredients_json, synced_english_instructions_json,
        date_created, date_modified
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      recipe.recipeID,
      recipe.name,
      JSON.stringify(recipe.ingredients),
      JSON.stringify(recipe.instructions),
      recipe.notes,
      recipe.source,
      sanitizeMinutes(recipe.prepTime),
      sanitizeMinutes(recipe.cookTime),
      sanitizeServings(recipe.servings),
      recipe.isSample ? 1 : 0,
      recipe.isImported ? 1 : 0,
      recipe.isFavorite ? 1 : 0,
      recipe.categoryRaw,
      JSON.stringify(recipe.ingredientIconIDs),
      recipe.coverIconID,
      recipe.usesCategoryCover ? 1 : 0,
      recipe.catalogRecipeID,
      recipe.isCatalogSynced ? 1 : 0,
      recipe.syncedEnglishName,
      JSON.stringify(recipe.syncedEnglishIngredients),
      JSON.stringify(recipe.syncedEnglishInstructions),
      recipe.dateCreated,
      recipe.dateModified
    );

    await conn.runAsync('DELETE FROM recipe_photos WHERE recipe_id = ?', recipe.recipeID);
    for (let i = 0; i < recipe.photos.length; i += 1) {
      const photo = recipe.photos[i];
      await conn.runAsync(
        `INSERT INTO recipe_photos (photo_id, recipe_id, sort_index, image_uri, thumbnail_uri)
         VALUES (?, ?, ?, ?, ?)`,
        photo.photoID || generateUUID(),
        recipe.recipeID,
        photo.sortIndex ?? i,
        photo.imageUri,
        photo.thumbnailUri
      );
    }
  };

  if (executor) {
    await execute(executor);
  } else {
    const db = await getDatabase();
    await db.withExclusiveTransactionAsync(async (txn) => {
      await execute(txn);
    });
  }
}

export async function toggleRecipeFavorite(
  recipeID: string,
  nextFavorite: boolean
): Promise<void> {
  const db = await getDatabase();
  const now = new Date().toISOString();
  await db.runAsync(
    'UPDATE recipes SET is_favorite = ?, date_modified = ? WHERE recipe_id = ?',
    nextFavorite ? 1 : 0,
    now,
    recipeID
  );
}

export async function deleteRecipeByID(
  recipeID: string,
  executor?: SQLExecutor
): Promise<void> {
  const db = executor ?? (await getDatabase());
  const existing = await fetchRecipeByID(recipeID, db);
  if (existing) {
    for (const photo of existing.photos) {
      deletePhotoFiles(photo);
    }
  }
  await db.runAsync('DELETE FROM recipe_photos WHERE recipe_id = ?', recipeID);
  await db.runAsync('DELETE FROM recipes WHERE recipe_id = ?', recipeID);
}

export async function findExistingCatalogRecipe(
  rawID: string,
  executor?: SQLExecutor
): Promise<Recipe | null> {
  const canonical = canonicalRecipeID(rawID);
  if (!canonical) return null;

  const recipes = (await fetchAllRecipes(executor)).filter((r) => !r.isSample);
  const direct = recipes.find(
    (r) => r.catalogRecipeID.length > 0 && canonicalRecipeID(r.catalogRecipeID) === canonical
  );
  if (direct) return direct;

  return (
    recipes.find(
      (r) =>
        r.catalogRecipeID.length === 0 &&
        r.isImported &&
        inferredLegacyCatalogID(r) === canonical
    ) ?? null
  );
}

export async function saveDiscoveredRecipeToLibrary(
  detail: DiscoveredRecipeDetail,
  options: {
    englishDetail?: DiscoveredRecipeDetail | null;
    ingredientIcons?: string[];
  } = {}
): Promise<DiscoveredRecipeSaveResult> {
  const canonical = canonicalRecipeID(detail.id);
  const times = estimateRecipeTime(detail.instructions, detail.ingredients.length, detail.category);
  const cleanedInstructions = cleanInstructions(detail.instructions, detail.name);
  const activeLanguage = getActiveLanguage();

  const resolvedIcons =
    options.ingredientIcons && options.ingredientIcons.length === detail.ingredients.length
      ? options.ingredientIcons
      : detail.ingredients.map((line) => findMatchingIconID(line, activeLanguage) ?? '');

  const mappedCategory = inferCategoryFromMealDB(detail.category);
  const trimmedSource = (detail.sourceURL ?? '').trim();
  const resolvedSource = trimmedSource.length > 0 ? trimmedSource : getRecipeAttribution(detail, activeLanguage);

  const isLocalEnglish = getLocalMealRecord(canonical, 'en') !== null;
  const shouldStoreEnglishSnapshot = activeLanguage !== 'en' && !isLocalEnglish;
  const snapshotEN = shouldStoreEnglishSnapshot ? options.englishDetail ?? null : null;
  const healingEnglishDetail: DiscoveredRecipeDetail | null = isLocalEnglish
    ? null
    : activeLanguage === 'en'
      ? detail
      : options.englishDetail ?? null;

  const db = await getDatabase();
  const existing = await findExistingCatalogRecipe(canonical, db);

  let downloadedPhoto: StoredPhotoPaths | null = null;
  if ((!existing || existing.photos.length === 0) && detail.thumbnailURL) {
    downloadedPhoto = await downloadAndSaveRemotePhoto(detail.thumbnailURL);
  }

  const now = new Date().toISOString();

  if (existing) {
    const updated: Recipe = { ...existing };
    if (updated.catalogRecipeID !== canonical) {
      updated.catalogRecipeID = canonical;
    }
    if (updated.isCatalogSynced) {
      if (
        !updated.syncedEnglishName &&
        healingEnglishDetail &&
        (activeLanguage !== 'en' ||
          updated.name.toLowerCase() !== healingEnglishDetail.name.toLowerCase())
      ) {
        updated.syncedEnglishName = healingEnglishDetail.name;
        updated.syncedEnglishIngredients = healingEnglishDetail.ingredients;
        updated.syncedEnglishInstructions = cleanInstructions(
          healingEnglishDetail.instructions,
          healingEnglishDetail.name
        );
      }
      if (updated.prepTime === 0 && times.prep > 0) updated.prepTime = times.prep;
      if (updated.cookTime === 0 && times.cook > 0) updated.cookTime = times.cook;
      if (!updated.source) updated.source = resolvedSource;
      if (updated.ingredientIconIDs.length === 0) updated.ingredientIconIDs = resolvedIcons;
    }
    if (updated.photos.length === 0 && downloadedPhoto) {
      updated.photos = [
        {
          photoID: generateUUID(),
          recipeID: updated.recipeID,
          sortIndex: 0,
          imageUri: downloadedPhoto.imageUri,
          thumbnailUri: downloadedPhoto.thumbnailUri,
        },
      ];
    }
    updated.dateModified = now;
    await insertOrReplaceRecipe(updated, db);
    return 'updatedExisting';
  }

  const recipeID = generateUUID();
  const photos: RecipePhoto[] = downloadedPhoto
    ? [
        {
          photoID: generateUUID(),
          recipeID,
          sortIndex: 0,
          imageUri: downloadedPhoto.imageUri,
          thumbnailUri: downloadedPhoto.thumbnailUri,
        },
      ]
    : [];

  const newRecipe: Recipe = {
    recipeID,
    name: detail.name,
    ingredients: detail.ingredients,
    instructions: cleanedInstructions,
    notes: '',
    source: resolvedSource,
    prepTime: times.prep,
    cookTime: times.cook,
    servings: 0,
    isSample: false,
    isImported: true,
    isFavorite: false,
    categoryRaw: mappedCategory,
    ingredientIconIDs: resolvedIcons,
    coverIconID: getCategoryIconName(mappedCategory),
    usesCategoryCover: false,
    catalogRecipeID: canonical,
    isCatalogSynced: true,
    syncedEnglishName: snapshotEN?.name ?? '',
    syncedEnglishIngredients: snapshotEN?.ingredients ?? [],
    syncedEnglishInstructions: snapshotEN
      ? cleanInstructions(snapshotEN.instructions, snapshotEN.name)
      : [],
    dateCreated: now,
    dateModified: now,
    photos,
  };

  await insertOrReplaceRecipe(newRecipe, db);
  return 'inserted';
}
