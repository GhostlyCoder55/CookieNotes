import { AppTheme } from '../constants/theme';
import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { Recipe, RecipeCategory, RecipeFilter } from '../types/models';

export const RECIPE_CATEGORIES: readonly RecipeCategory[] = [
  'uncategorized',
  'breakfast',
  'lunch',
  'dinner',
  'dessert',
  'drinks',
] as const;

export const RECIPE_FILTERS: readonly RecipeFilter[] = [
  'all',
  'favorites',
  'breakfast',
  'lunch',
  'dinner',
  'dessert',
  'drinks',
] as const;

export function parseRecipeCategory(raw?: string | null): RecipeCategory {
  if (!raw) return 'uncategorized';
  const normalized = raw.trim().toLowerCase();
  if ((RECIPE_CATEGORIES as readonly string[]).includes(normalized)) {
    return normalized as RecipeCategory;
  }
  return 'uncategorized';
}

export function getCategoryTitle(category: RecipeCategory, lang: AppLanguage = getActiveLanguage()): string {
  switch (category) {
    case 'uncategorized':
      return tFor(lang, 'General');
    case 'breakfast':
      return tFor(lang, 'Breakfast');
    case 'lunch':
      return tFor(lang, 'Lunch');
    case 'dinner':
      return tFor(lang, 'Dinner');
    case 'dessert':
      return tFor(lang, 'Dessert');
    case 'drinks':
      return tFor(lang, 'Drinks');
  }
}

export function getFilterTitle(filter: RecipeFilter, lang: AppLanguage = getActiveLanguage()): string {
  switch (filter) {
    case 'all':
      return tFor(lang, 'All');
    case 'favorites':
      return tFor(lang, 'Favorites');
    case 'breakfast':
      return getCategoryTitle('breakfast', lang);
    case 'lunch':
      return getCategoryTitle('lunch', lang);
    case 'dinner':
      return getCategoryTitle('dinner', lang);
    case 'dessert':
      return getCategoryTitle('dessert', lang);
    case 'drinks':
      return getCategoryTitle('drinks', lang);
  }
}

export function filterToCategory(filter: RecipeFilter): RecipeCategory | null {
  switch (filter) {
    case 'all':
    case 'favorites':
      return null;
    case 'breakfast':
    case 'lunch':
    case 'dinner':
    case 'dessert':
    case 'drinks':
      return filter;
  }
}

export function getCategoryColor(category: RecipeCategory): string {
  switch (category) {
    case 'uncategorized':
      return AppTheme.goldenYellow;
    case 'breakfast':
      return AppTheme.brightOrange;
    case 'lunch':
      return AppTheme.leafGreen;
    case 'dinner':
      return AppTheme.burntOrange;
    case 'dessert':
      return AppTheme.warmBrown;
    case 'drinks':
      return AppTheme.brightOrange;
  }
}

export function getCategoryIconName(category: RecipeCategory): string {
  switch (category) {
    case 'uncategorized':
      return 'veggie_plate';
    case 'breakfast':
      return 'pancakes';
    case 'lunch':
      return 'salad_bowl';
    case 'dinner':
      return 'soup_bowl';
    case 'dessert':
      return 'berries_bowl';
    case 'drinks':
      return 'berry_smoothie';
  }
}

export function getCategoryCoverElements(category: RecipeCategory): string[] {
  switch (category) {
    case 'dinner':
      return ['soup_bowl'];
    case 'dessert':
      return ['strawberry', 'ice_cream', 'cupcake'];
    default:
      return [getCategoryIconName(category)];
  }
}

export function inferCategoryFromMealDB(category?: string | null): RecipeCategory {
  const raw = category?.trim().toLowerCase() ?? '';
  if (!raw) return 'uncategorized';
  switch (raw) {
    case 'breakfast':
      return 'breakfast';
    case 'dessert':
      return 'dessert';
    case 'drink':
    case 'drinks':
    case 'beverage':
    case 'beverages':
      return 'drinks';
    case 'vegetarian':
    case 'vegan':
      return 'lunch';
    case 'chicken':
    case 'beef':
    case 'pork':
    case 'lamb':
    case 'goat':
    case 'seafood':
    case 'pasta':
    case 'miscellaneous':
      return 'dinner';
    default:
      return 'uncategorized';
  }
}

const LEGACY_SINGLES_DINNER = new Set([
  'roast_chicken',
  'spaghetti_bowl',
  'plated_meal',
  'steak',
  'salmon_steak',
  'ribeye_steak',
  'soup_bowl',
]);

const LEGACY_SINGLES_DESSERT = new Set(['cupcake']);

export function resolveRecipeCoverElements(
  recipe: Pick<Recipe, 'categoryRaw' | 'coverIconID' | 'ingredientIconIDs'>
): string[] {
  const category = parseRecipeCategory(recipe.categoryRaw);
  const coverIconID = recipe.coverIconID ?? '';
  const ingredientIconIDs = recipe.ingredientIconIDs ?? [];

  if (!coverIconID) {
    const firstNonEmpty = ingredientIconIDs.find((id) => id.trim().length > 0);
    if (firstNonEmpty) return [firstNonEmpty];
    return getCategoryCoverElements(category);
  }

  if (category === 'dinner' || category === 'dessert') {
    const preferred = getCategoryIconName(category);
    const isLegacySingle =
      category === 'dinner'
        ? LEGACY_SINGLES_DINNER.has(coverIconID)
        : LEGACY_SINGLES_DESSERT.has(coverIconID);

    if (coverIconID === preferred || isLegacySingle) {
      return getCategoryCoverElements(category);
    }
  }

  return [coverIconID];
}

export function resolveRecipeCoverIcon(
  recipe: Pick<Recipe, 'categoryRaw' | 'coverIconID' | 'ingredientIconIDs'>
): string {
  const elements = resolveRecipeCoverElements(recipe);
  const category = parseRecipeCategory(recipe.categoryRaw);
  return elements[0] ?? getCategoryIconName(category);
}
