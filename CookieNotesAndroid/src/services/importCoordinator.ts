import { RecipeInputLimits } from '../constants/limits';
import {
  fetchAllRecipes,
  insertOrReplaceRecipe,
} from '../database/recipeRepository';
import { getActiveLanguage, tFor } from '../localization/i18n';
import type { Recipe, RecipePhoto, SharedRecipePayload } from '../types/models';
import { findMatchingIconID } from '../utils/ingredientCatalog';
import { processAndSavePhotoFromUri } from '../utils/photoProcessing';
import { sanitizeWebURL } from '../utils/recipeSanitizer';
import { buildSharedRecipeDraft } from '../utils/sharedRecipeBuilder';
import { generateUUID } from '../utils/uuid';

export interface ImportConsumeResult {
  saved: boolean;
  duplicate: boolean;
  errorMessage: string | null;
  savedRecipeName: string | null;
}

export async function consumeSharedRecipePayload(
  payload: SharedRecipePayload
): Promise<ImportConsumeResult> {
  const lang = getActiveLanguage();
  const draft = buildSharedRecipeDraft(payload, lang);
  if (!draft.name.trim()) {
    return {
      saved: false,
      duplicate: false,
      errorMessage: null,
      savedRecipeName: null,
    };
  }

  const normalizedSourceURL = sanitizeWebURL(draft.source)?.toLowerCase() ?? null;
  const existing = (await fetchAllRecipes()).filter((r) => !r.isSample && r.isImported);

  if (normalizedSourceURL) {
    const alreadyExists = existing.some(
      (r) => sanitizeWebURL(r.source)?.toLowerCase() === normalizedSourceURL
    );
    if (alreadyExists) {
      return {
        saved: false,
        duplicate: true,
        errorMessage: null,
        savedRecipeName: null,
      };
    }
  }

  const recipeID = generateUUID();
  const iconIDs = draft.ingredients.map(
    (line) => findMatchingIconID(line, lang) ?? ''
  );

  const photos: RecipePhoto[] = [];
  if (
    payload.imageUri &&
    (payload.imageSizeBytes == null ||
      payload.imageSizeBytes <= RecipeInputLimits.sharedImageBytes)
  ) {
    const stored = await processAndSavePhotoFromUri(payload.imageUri);
    if (stored) {
      photos.push({
        photoID: generateUUID(),
        recipeID,
        sortIndex: 0,
        imageUri: stored.imageUri,
        thumbnailUri: stored.thumbnailUri,
      });
    }
  }

  const now = new Date().toISOString();
  const recipe: Recipe = {
    recipeID,
    name: draft.name,
    ingredients: draft.ingredients,
    instructions: draft.instructions,
    notes: draft.notes,
    source: draft.source,
    prepTime: 0,
    cookTime: 0,
    servings: draft.servings ?? 0,
    isSample: false,
    isImported: true,
    isFavorite: false,
    categoryRaw: 'uncategorized',
    ingredientIconIDs: iconIDs,
    coverIconID: photos.length === 0 ? 'veggie_plate' : '',
    usesCategoryCover: false,
    catalogRecipeID: '',
    isCatalogSynced: false,
    syncedEnglishName: '',
    syncedEnglishIngredients: [],
    syncedEnglishInstructions: [],
    dateCreated: now,
    dateModified: now,
    photos,
  };

  try {
    await insertOrReplaceRecipe(recipe);
    return {
      saved: true,
      duplicate: false,
      errorMessage: null,
      savedRecipeName: recipe.name,
    };
  } catch {
    return {
      saved: false,
      duplicate: false,
      errorMessage: tFor(lang, "A shared recipe couldn't be saved."),
      savedRecipeName: null,
    };
  }
}
