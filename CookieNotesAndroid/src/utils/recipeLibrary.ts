import { getLocalMealRecord } from '../data/localMealCatalog';
import { getTheMealDBRecord } from '../data/theMealDBCatalog';
import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { Recipe, RecipeFilter, RecipeSort } from '../types/models';
import { normalizeTaxonomyText } from './cuisineTaxonomy';
import { canonicalRecipeID } from './mealIdentity';
import { filterToCategory, parseRecipeCategory } from './recipeCategory';
import { cleanInstructions } from './recipeSanitizer';
import { formatDurationShort } from './recipeTimeEstimator';
import { translateIngredient, translateInstruction } from './recipeTranslator';

export const RECIPE_SORTS: readonly RecipeSort[] = ['newest', 'name'] as const;

export function getRecipeSortTitle(sort: RecipeSort, lang: AppLanguage = getActiveLanguage()): string {
  return sort === 'newest' ? tFor(lang, 'Newest') : tFor(lang, 'Name');
}

export function getRecipeTotalTime(recipe: Pick<Recipe, 'prepTime' | 'cookTime'>): number {
  return recipe.prepTime + recipe.cookTime;
}

export function hasRecipePhotos(recipe: Pick<Recipe, 'photos'>): boolean {
  return (recipe.photos?.length ?? 0) > 0;
}

export function getCardThumbnailUri(recipe: Pick<Recipe, 'photos'>): string | null {
  const first = getSortedPhotos(recipe)[0];
  return first?.thumbnailUri ?? null;
}

export function getSortedPhotos<T extends Pick<Recipe, 'photos'>>(recipe: T): Recipe['photos'] {
  return [...(recipe.photos ?? [])].sort((lhs, rhs) => {
    if (lhs.sortIndex !== rhs.sortIndex) return lhs.sortIndex - rhs.sortIndex;
    return lhs.photoID.localeCompare(rhs.photoID);
  });
}

function getResolvedCatalogContent(
  recipe: Pick<
    Recipe,
    | 'isCatalogSynced'
    | 'catalogRecipeID'
    | 'syncedEnglishName'
    | 'syncedEnglishIngredients'
    | 'syncedEnglishInstructions'
  >,
  lang: AppLanguage
): { name: string; ingredients: string[]; instructions: string[] } | null {
  if (!recipe.isCatalogSynced || !recipe.catalogRecipeID) return null;
  const canonical = canonicalRecipeID(recipe.catalogRecipeID);

  const localRecord = getLocalMealRecord(canonical, lang);
  if (localRecord) {
    return {
      name: localRecord.name,
      ingredients: localRecord.ingredients,
      instructions: cleanInstructions(localRecord.instructions, localRecord.name),
    };
  }

  if (lang === 'fr') {
    const mdbRecord = getTheMealDBRecord(canonical);
    if (mdbRecord) {
      return {
        name: mdbRecord.name,
        ingredients: mdbRecord.ingredients,
        instructions: cleanInstructions(mdbRecord.instructions, mdbRecord.name),
      };
    }
  }

  if (lang === 'en' && recipe.syncedEnglishName) {
    return {
      name: recipe.syncedEnglishName,
      ingredients: recipe.syncedEnglishIngredients,
      instructions: cleanInstructions(recipe.syncedEnglishInstructions, recipe.syncedEnglishName),
    };
  }

  return null;
}

export function resolveLocalizedRecipeName(
  recipe: Recipe,
  lang: AppLanguage = getActiveLanguage()
): string {
  return getResolvedCatalogContent(recipe, lang)?.name ?? recipe.name;
}

export function resolveLocalizedIngredients(
  recipe: Recipe,
  lang: AppLanguage = getActiveLanguage()
): string[] {
  const catalogContent = getResolvedCatalogContent(recipe, lang);
  if (catalogContent) return catalogContent.ingredients;
  if (lang === 'en') return recipe.ingredients;
  if (recipe.isCatalogSynced && recipe.catalogRecipeID) {
    return recipe.ingredients.map((line) => translateIngredient(line, lang));
  }
  return recipe.ingredients;
}

export function resolveLocalizedInstructions(
  recipe: Recipe,
  lang: AppLanguage = getActiveLanguage()
): string[] {
  const catalogContent = getResolvedCatalogContent(recipe, lang);
  if (catalogContent) return catalogContent.instructions;
  const cleaned = cleanInstructions(recipe.instructions, recipe.name);
  if (lang === 'en') return cleaned;
  if (recipe.isCatalogSynced && recipe.catalogRecipeID) {
    return cleaned.map((step) => translateInstruction(step, lang));
  }
  return cleaned;
}

export function resolveDisplayIngredientsForDetail(
  recipe: Recipe,
  lang: AppLanguage = getActiveLanguage()
): string[] {
  const catalogContent = getResolvedCatalogContent(recipe, lang);
  if (catalogContent) return catalogContent.ingredients;
  if (lang === 'en') return recipe.ingredients;
  return recipe.ingredients.map((line) => translateIngredient(line, lang));
}

export function resolveDisplayInstructionsForDetail(
  recipe: Recipe,
  lang: AppLanguage = getActiveLanguage()
): string[] {
  const catalogContent = getResolvedCatalogContent(recipe, lang);
  if (catalogContent) return catalogContent.instructions;
  const cleaned = cleanInstructions(recipe.instructions, recipe.name);
  if (lang === 'en') return cleaned;
  return cleaned.map((step) => translateInstruction(step, lang));
}

export function formatRecipeTotalTime(
  recipe: Pick<Recipe, 'prepTime' | 'cookTime'>,
  lang: AppLanguage = getActiveLanguage()
): string {
  const total = getRecipeTotalTime(recipe);
  if (total === 0) return tFor(lang, 'Instant');
  return tFor(lang, '%@ total', formatDurationShort(total, lang));
}

export function formatRecipeServings(
  servings: number,
  lang: AppLanguage = getActiveLanguage()
): string | null {
  if (servings <= 0) return null;
  if (servings === 1) return tFor(lang, '1 serving');
  return tFor(lang, '%lld servings', servings);
}

export function buildRecipeShareText(
  recipe: Recipe,
  lang: AppLanguage = getActiveLanguage()
): string {
  const displayTitle = resolveLocalizedRecipeName(recipe, lang);
  const displayIngredients = resolveDisplayIngredientsForDetail(recipe, lang);
  const cleanSteps = resolveDisplayInstructionsForDetail(recipe, lang);
  const lines: string[] = [displayTitle, ''];

  const meta: string[] = [];
  if (getRecipeTotalTime(recipe) > 0) {
    meta.push(tFor(lang, 'Prep %lld min · Cook %lld min', recipe.prepTime, recipe.cookTime));
  }
  const formattedServings = formatRecipeServings(recipe.servings, lang);
  if (formattedServings) {
    meta.push(formattedServings);
  }
  if (meta.length > 0) {
    lines.push(meta.join(' · '));
    lines.push('');
  }

  if (displayIngredients.length > 0) {
    lines.push(tFor(lang, 'Ingredients'));
    for (const item of displayIngredients) {
      lines.push(`• ${item}`);
    }
    lines.push('');
  }

  if (cleanSteps.length > 0) {
    lines.push(tFor(lang, 'Instructions'));
    cleanSteps.forEach((step, idx) => {
      lines.push(`${idx + 1}. ${step}`);
    });
    lines.push('');
  }

  if (recipe.notes.trim().length > 0) {
    lines.push(tFor(lang, 'Notes'));
    lines.push(recipe.notes);
    lines.push('');
  }

  if (recipe.source.trim().length > 0) {
    lines.push(tFor(lang, 'Source: %@', recipe.source));
  }

  return lines.join('\n').trim();
}

export function matchesRecipeFilter(recipe: Recipe, filter: RecipeFilter): boolean {
  if (recipe.isSample) return false;
  switch (filter) {
    case 'all':
      return true;
    case 'favorites':
      return recipe.isFavorite;
    case 'breakfast':
    case 'lunch':
    case 'dinner':
    case 'dessert':
    case 'drinks':
      return parseRecipeCategory(recipe.categoryRaw) === filterToCategory(filter);
  }
}

export function matchesRecipeQuery(
  recipe: Recipe,
  rawQuery: string,
  lang: AppLanguage = getActiveLanguage()
): boolean {
  const query = rawQuery.trim();
  if (!query) return true;
  const q = normalizeTaxonomyText(query);
  const fallbackLower = query.toLowerCase();

  const contains = (text: string): boolean =>
    text.toLowerCase().includes(fallbackLower) || normalizeTaxonomyText(text).includes(q);

  if (contains(resolveLocalizedRecipeName(recipe, lang))) return true;
  if (contains(recipe.notes)) return true;
  if (contains(recipe.source)) return true;
  if (resolveLocalizedIngredients(recipe, lang).some(contains)) return true;
  return resolveLocalizedInstructions(recipe, lang).some(contains);
}

export function sortLibraryRecipes<T extends Recipe>(
  recipes: readonly T[],
  sort: RecipeSort,
  lang: AppLanguage = getActiveLanguage()
): T[] {
  const copy = [...recipes];
  switch (sort) {
    case 'newest':
      return copy.sort((lhs, rhs) => {
        if (lhs.dateCreated !== rhs.dateCreated) {
          return rhs.dateCreated.localeCompare(lhs.dateCreated);
        }
        return resolveLocalizedRecipeName(lhs, lang).localeCompare(
          resolveLocalizedRecipeName(rhs, lang),
          undefined,
          { sensitivity: 'base', numeric: true }
        );
      });
    case 'name':
      return copy.sort((lhs, rhs) =>
        resolveLocalizedRecipeName(lhs, lang).localeCompare(
          resolveLocalizedRecipeName(rhs, lang),
          undefined,
          { sensitivity: 'base', numeric: true }
        )
      );
  }
}

export function prepareLibraryRecipes<T extends Recipe>(
  recipes: readonly T[],
  options: {
    query?: string;
    filter?: RecipeFilter;
    sort?: RecipeSort;
    language?: AppLanguage;
  } = {}
): T[] {
  const query = (options.query ?? '').trim();
  const filter = options.filter ?? 'all';
  const sort = options.sort ?? 'newest';
  const lang = options.language ?? getActiveLanguage();

  const filtered = recipes.filter(
    (recipe) => matchesRecipeFilter(recipe, filter) && matchesRecipeQuery(recipe, query, lang)
  );
  return sortLibraryRecipes(filtered, sort, lang);
}
