import {
  filterLocalMealsByArea,
  filterLocalMealsByRegion,
  getAllLocalMeals,
  getLocalMealDetail,
  getLocalMealRecord,
  resolvedAreaForQuery,
  searchLocalMeals,
} from '../data/localMealCatalog';
import {
  getTheMealDBRecord,
  searchTheMealDBFrenchCatalog,
} from '../data/theMealDBCatalog';
import { getCachedMealDBJson, setCachedMealDBJson } from '../database/db';
import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type {
  CuisineArea,
  CuisineRegion,
  DiscoveredRecipeDetail,
  DiscoveredRecipeSummary,
  RecipeTimeEstimate,
} from '../types/models';
import {
  getRegionForArea,
  normalizeTaxonomyText,
} from '../utils/cuisineTaxonomy';
import {
  alphabeticallySortedSummaries,
  canonicalRecipeID,
  isExcludedMeal,
  mergingDiscoveredSummaries,
} from '../utils/mealIdentity';
import { cleanInstructions } from '../utils/recipeSanitizer';
import { estimateRecipeTime } from '../utils/recipeTimeEstimator';
import {
  translateDiscoveredDetail,
  translateDiscoveredSummary,
} from '../utils/recipeTranslator';
import { generateUUID } from '../utils/uuid';

interface RawMealDBMeal {
  idMeal?: string | null;
  strMeal?: string | null;
  strCategory?: string | null;
  strArea?: string | null;
  strInstructions?: string | null;
  strMealThumb?: string | null;
  strSource?: string | null;
  strYoutube?: string | null;
  strTags?: string | null;
  [key: string]: string | null | undefined;
}

interface MealDBEnvelope {
  meals?: RawMealDBMeal[] | null;
}

const REQUEST_TIMEOUT_MS = 15000;

const MULTILINGUAL_CATEGORY_ALIASES: Record<string, string> = {
  // French
  boeuf: 'Beef',
  bœuf: 'Beef',
  dejeuner: 'Breakfast',
  déjeuner: 'Breakfast',
  'petit dejeuner': 'Breakfast',
  'petit déjeuner': 'Breakfast',
  poulet: 'Chicken',
  dessert: 'Dessert',
  chevre: 'Goat',
  chèvre: 'Goat',
  agneau: 'Lamb',
  divers: 'Miscellaneous',
  pates: 'Pasta',
  pâtes: 'Pasta',
  porc: 'Pork',
  'fruits de mer': 'Seafood',
  accompagnement: 'Side',
  entree: 'Starter',
  entrée: 'Starter',
  vegan: 'Vegan',
  végan: 'Vegan',
  vegetarien: 'Vegetarian',
  végétarien: 'Vegetarian',
  // Spanish
  res: 'Beef',
  'carne de res': 'Beef',
  desayuno: 'Breakfast',
  pollo: 'Chicken',
  postre: 'Dessert',
  postres: 'Dessert',
  cabra: 'Goat',
  cordero: 'Lamb',
  varios: 'Miscellaneous',
  pasta: 'Pasta',
  pastas: 'Pasta',
  cerdo: 'Pork',
  puerco: 'Pork',
  mariscos: 'Seafood',
  pescados: 'Seafood',
  guarnicion: 'Side',
  guarnición: 'Side',
  entrada: 'Starter',
  entrante: 'Starter',
  vegano: 'Vegan',
  vegetariano: 'Vegetarian',
};

function rawMealToSummary(
  meal: RawMealDBMeal,
  categoryHint?: string | null
): DiscoveredRecipeSummary {
  const category = (categoryHint ?? meal.strCategory)?.trim() || null;
  const area = meal.strArea?.trim() || null;
  return {
    id: meal.idMeal?.trim() || generateUUID(),
    name: meal.strMeal?.trim() || 'Recipe',
    thumbnailURL: meal.strMealThumb?.trim() || null,
    category,
    area,
    illustrationIconID: null,
  };
}

export function rawMealToDetail(meal: RawMealDBMeal): DiscoveredRecipeDetail {
  const ingredients: string[] = [];
  for (let i = 1; i <= 20; i += 1) {
    const ing = (meal[`strIngredient${i}`] ?? '').trim();
    if (!ing) continue;
    const measure = (meal[`strMeasure${i}`] ?? '').trim();
    ingredients.push(measure ? `${measure} ${ing}` : ing);
  }

  const rawInstructions = (meal.strInstructions ?? '').trim();
  const splitSteps = rawInstructions
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  const instructions =
    splitSteps.length > 0 ? splitSteps : rawInstructions ? [rawInstructions] : [];

  const tags = (meal.strTags ?? '')
    .split(',')
    .map((t) => t.trim())
    .filter((t) => t.length > 0);

  return {
    id: meal.idMeal?.trim() || generateUUID(),
    name: meal.strMeal?.trim() || 'Recipe',
    category: meal.strCategory?.trim() || null,
    area: meal.strArea?.trim() || null,
    instructions,
    ingredients,
    thumbnailURL: meal.strMealThumb?.trim() || null,
    sourceURL: meal.strSource?.trim() || null,
    youtubeURL: meal.strYoutube?.trim() || null,
    tags,
    illustrationIconID: null,
  };
}

export interface DiscoverFetchOutcome<T> {
  data: T;
  fromOfflineCache: boolean;
}

class MealDBClient {
  private cachedAreas: CuisineArea[] | null = null;
  private cachedCategories: string[] | null = null;
  private cachedIngredients: string[] | null = null;
  private listCache = new Map<string, DiscoveredRecipeSummary[]>();
  private detailCache = new Map<string, DiscoveredRecipeDetail>();
  private detailRequests = new Map<string, Promise<DiscoveredRecipeDetail>>();
  private timeCache = new Map<string, RecipeTimeEstimate>();

  get apiKey(): string {
    const configured = process.env.EXPO_PUBLIC_MEALDB_API_KEY?.trim() ?? '';
    return configured.length > 0 ? configured : '1';
  }

  private get baseURL(): string {
    return `https://www.themealdb.com/api/json/v1/${this.apiKey}`;
  }

  static listKeyCategory(category: string): string {
    return `c:${category.toLowerCase()}`;
  }

  static listKeyArea(area: string): string {
    return `a:${area.toLowerCase()}`;
  }

  static listKeyRegion(region: CuisineRegion): string {
    return `r:${region.toLowerCase()}`;
  }

  static listKeySearch(query: string): string {
    return `s:${query.trim().toLowerCase()}`;
  }

  getCachedList(key: string): DiscoveredRecipeSummary[] | null {
    return this.listCache.get(key) ?? null;
  }

  getCachedEnglishDetail(id: string): DiscoveredRecipeDetail | null {
    const canonical = canonicalRecipeID(id);
    const localEN = getLocalMealDetail(canonical, 'en');
    if (localEN) return localEN;
    return this.detailCache.get(`${canonical}_en`) ?? null;
  }

  clearMemoryCache(): void {
    this.listCache.clear();
  }

  private async fetchJsonWithOfflineFallback<T>(
    path: string,
    params: Record<string, string>,
    cacheKey: string
  ): Promise<{ parsed: T; fromCache: boolean }> {
    const query = new URLSearchParams(params).toString();
    const url = `${this.baseURL}/${path}${query ? `?${query}` : ''}`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch(url, { signal: controller.signal });
      clearTimeout(timeoutId);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const text = await response.text();
      const parsed = JSON.parse(text) as T;
      await setCachedMealDBJson(cacheKey, text);
      return { parsed, fromCache: false };
    } catch (err) {
      clearTimeout(timeoutId);
      const cachedRaw = await getCachedMealDBJson(cacheKey);
      if (cachedRaw) {
        return { parsed: JSON.parse(cachedRaw) as T, fromCache: true };
      }
      throw err;
    }
  }

  private async fetchMeals(
    path: string,
    params: Record<string, string>,
    cacheKey: string
  ): Promise<{ meals: RawMealDBMeal[]; fromCache: boolean }> {
    const { parsed, fromCache } = await this.fetchJsonWithOfflineFallback<MealDBEnvelope>(
      path,
      params,
      cacheKey
    );
    return { meals: parsed.meals ?? [], fromCache };
  }

  async cuisineAreas(): Promise<CuisineArea[]> {
    if (this.cachedAreas) return this.cachedAreas;
    const { parsed } = await this.fetchJsonWithOfflineFallback<{
      meals?: Array<{ strArea?: string | null; strCountry?: string | null }> | null;
    }>('list.php', { a: 'list' }, 'meta:areas');

    const areas = (parsed.meals ?? [])
      .filter((item) => Boolean(item.strArea && item.strArea.trim()))
      .map((item) => ({
        name: item.strArea!.trim(),
        country: item.strCountry?.trim() ?? '',
      }));
    if (areas.length > 0) {
      this.cachedAreas = areas;
    }
    return areas;
  }

  async categories(): Promise<string[]> {
    if (this.cachedCategories) return this.cachedCategories;
    const { parsed } = await this.fetchJsonWithOfflineFallback<{
      meals?: Array<{ strCategory?: string | null }> | null;
    }>('list.php', { c: 'list' }, 'meta:categories');

    const list = (parsed.meals ?? [])
      .map((item) => item.strCategory?.trim() ?? '')
      .filter((c) => c.length > 0);
    if (list.length > 0) {
      this.cachedCategories = list;
    }
    return list;
  }

  private async ingredients(): Promise<string[]> {
    if (this.cachedIngredients) return this.cachedIngredients;
    const { parsed } = await this.fetchJsonWithOfflineFallback<{
      meals?: Array<{ strIngredient?: string | null }> | null;
    }>('list.php', { i: 'list' }, 'meta:ingredients');

    const list = (parsed.meals ?? [])
      .map((item) => item.strIngredient?.trim() ?? '')
      .filter((i) => i.length > 0);
    if (list.length > 0) {
      this.cachedIngredients = list;
    }
    return list;
  }

  private async matchedRemoteArea(query: string): Promise<string | null> {
    const normalized = normalizeTaxonomyText(query);
    if (normalized.length < 3) return null;
    try {
      const catalog = await this.cuisineAreas();
      const exact = catalog.find(
        (item) =>
          normalizeTaxonomyText(item.name) === normalized ||
          normalizeTaxonomyText(item.country) === normalized
      );
      if (exact) return exact.name;
      return (
        catalog.find(
          (item) =>
            normalizeTaxonomyText(item.name).startsWith(normalized) ||
            normalizeTaxonomyText(item.country).startsWith(normalized)
        )?.name ?? null
      );
    } catch {
      return null;
    }
  }

  private async matchedRemoteCategory(query: string): Promise<string | null> {
    const normalized = normalizeTaxonomyText(query);
    if (normalized.length < 3) return null;
    const aliased = MULTILINGUAL_CATEGORY_ALIASES[normalized];
    if (aliased) return aliased;
    try {
      const list = await this.categories();
      return list.find((c) => normalizeTaxonomyText(c) === normalized) ?? null;
    } catch {
      return null;
    }
  }

  private async matchedRemoteIngredient(query: string): Promise<string | null> {
    const terms = normalizeTaxonomyText(query)
      .split(' ')
      .filter((t) => t.length > 0);
    if (terms.length === 0 || terms.length > 2 || terms.join('').length < 4) {
      return null;
    }
    try {
      const list = await this.ingredients();
      return (
        list.find((ing) => {
          const candidateTerms = normalizeTaxonomyText(ing)
            .split(' ')
            .filter((t) => t.length > 0);
          return terms.every((term) => candidateTerms.some((c) => c.startsWith(term)));
        }) ?? null
      );
    } catch {
      return null;
    }
  }

  async filterByArea(
    area: string,
    lang: AppLanguage = getActiveLanguage()
  ): Promise<DiscoverFetchOutcome<DiscoveredRecipeSummary[]>> {
    const cacheKey = `${MealDBClient.listKeyArea(area)}_${lang}`;
    const cached = this.listCache.get(cacheKey);
    if (cached) return { data: cached, fromOfflineCache: false };

    const local = filterLocalMealsByArea(area, lang);
    let remote: DiscoveredRecipeSummary[] = [];
    let fromCache = false;
    let fetchError: unknown = null;

    try {
      const res = await this.fetchMeals('filter.php', { a: area }, `area:${area.toLowerCase()}`);
      fromCache = res.fromCache;
      remote = res.meals
        .filter((meal) => !isExcludedMeal(meal.idMeal, meal.strMeal))
        .map((meal) => ({
          id: meal.idMeal?.trim() || generateUUID(),
          name: meal.strMeal?.trim() || 'Recipe',
          thumbnailURL: meal.strMealThumb?.trim() || null,
          category: meal.strCategory?.trim() || null,
          area,
          illustrationIconID: null,
        }));
    } catch (err) {
      fetchError = err;
      if (local.length === 0) throw err;
      fromCache = true;
    }

    const merged = mergingDiscoveredSummaries(local, remote);
    const localized =
      lang !== 'en'
        ? merged.map((item) => translateDiscoveredSummary(item, lang))
        : merged;

    if (!fetchError) {
      this.listCache.set(cacheKey, localized);
    }
    return { data: localized, fromOfflineCache: fromCache };
  }

  async filterByCategory(
    category: string,
    lang: AppLanguage = getActiveLanguage()
  ): Promise<DiscoverFetchOutcome<DiscoveredRecipeSummary[]>> {
    const cacheKey = `${MealDBClient.listKeyCategory(category)}_${lang}`;
    const cached = this.listCache.get(cacheKey);
    if (cached) return { data: cached, fromOfflineCache: false };

    const res = await this.fetchMeals(
      'filter.php',
      { c: category },
      `cat:${category.toLowerCase()}`
    );
    const remote = res.meals
      .filter((meal) => !isExcludedMeal(meal.idMeal, meal.strMeal))
      .map((meal) => rawMealToSummary(meal, category));

    const local = getAllLocalMeals(lang)
      .filter((m) => m.category.toLowerCase() === category.toLowerCase())
      .map((m) => ({
        id: m.id,
        name: m.name,
        thumbnailURL: m.thumbnailURL || null,
        category: m.category || null,
        area: m.area || null,
        illustrationIconID: m.illustration || null,
      }));

    const merged = mergingDiscoveredSummaries(local, remote);
    const localized =
      lang !== 'en'
        ? merged.map((item) => translateDiscoveredSummary(item, lang))
        : merged;

    this.listCache.set(cacheKey, localized);
    return { data: localized, fromOfflineCache: res.fromCache };
  }

  private async filterByIngredient(ingredient: string): Promise<DiscoveredRecipeSummary[]> {
    const { meals } = await this.fetchMeals(
      'filter.php',
      { i: ingredient },
      `ing:${ingredient.toLowerCase()}`
    );
    return meals
      .filter((meal) => !isExcludedMeal(meal.idMeal, meal.strMeal))
      .map((meal) => rawMealToSummary(meal));
  }

  async filterByRegion(
    region: CuisineRegion,
    lang: AppLanguage = getActiveLanguage()
  ): Promise<DiscoverFetchOutcome<DiscoveredRecipeSummary[]>> {
    const cacheKey = `${MealDBClient.listKeyRegion(region)}_${lang}`;
    const cached = this.listCache.get(cacheKey);
    if (cached) return { data: cached, fromOfflineCache: false };

    const local = filterLocalMealsByRegion(region, lang);
    let areaNames: string[] = [];
    let metadataFailed = false;

    try {
      const areas = await this.cuisineAreas();
      areaNames = areas
        .filter((a) => getRegionForArea(a.name, a.country) === region)
        .map((a) => a.name);
    } catch {
      metadataFailed = true;
    }

    if (areaNames.length === 0) {
      const sorted = alphabeticallySortedSummaries(local);
      const localized =
        lang !== 'en'
          ? sorted.map((item) => translateDiscoveredSummary(item, lang))
          : sorted;
      if (!metadataFailed) {
        this.listCache.set(cacheKey, localized);
      }
      return { data: localized, fromOfflineCache: metadataFailed };
    }

    const remote: DiscoveredRecipeSummary[] = [];
    let failedCount = 0;
    let usedOfflineCache = false;
    const concurrency = 6;
    let cursor = 0;

    const worker = async () => {
      while (cursor < areaNames.length) {
        const index = cursor;
        cursor += 1;
        const area = areaNames[index];
        try {
          const outcome = await this.filterByArea(area, lang);
          remote.push(...outcome.data);
          if (outcome.fromOfflineCache) usedOfflineCache = true;
        } catch {
          failedCount += 1;
        }
      }
    };

    await Promise.all(
      Array.from({ length: Math.min(concurrency, areaNames.length) }, () => worker())
    );

    if (failedCount === areaNames.length && local.length === 0) {
      throw new Error(tFor(lang, 'The recipe service didn’t respond.'));
    }

    const filteredRemote = remote.filter((item) => !isExcludedMeal(item.id, item.name));
    const sorted = alphabeticallySortedSummaries(
      mergingDiscoveredSummaries(local, filteredRemote)
    );
    const localized =
      lang !== 'en'
        ? sorted.map((item) => translateDiscoveredSummary(item, lang))
        : sorted;

    if (failedCount === 0 && !usedOfflineCache) {
      this.listCache.set(cacheKey, localized);
    }
    return { data: localized, fromOfflineCache: usedOfflineCache || failedCount > 0 };
  }

  async search(
    query: string,
    lang: AppLanguage = getActiveLanguage()
  ): Promise<DiscoverFetchOutcome<DiscoveredRecipeSummary[]>> {
    const trimmed = query.trim();
    if (!trimmed) return { data: [], fromOfflineCache: false };

    const cacheKey = `${MealDBClient.listKeySearch(trimmed)}_${lang}`;
    const cached = this.listCache.get(cacheKey);
    if (cached) return { data: cached, fromOfflineCache: false };

    const local = searchLocalMeals(trimmed, lang);
    const catalogFR = lang === 'fr' ? searchTheMealDBFrenchCatalog(trimmed) : [];
    const matches: DiscoveredRecipeSummary[] = [...local, ...catalogFR];
    let usedOfflineCache = false;
    let nameSearchError: unknown = null;

    try {
      const res = await this.fetchMeals(
        'search.php',
        { s: trimmed },
        `search:${trimmed.toLowerCase()}`
      );
      if (res.fromCache) usedOfflineCache = true;
      for (const meal of res.meals) {
        if (isExcludedMeal(meal.idMeal, meal.strMeal)) continue;
        const detailEN = rawMealToDetail(meal);
        const canonical = canonicalRecipeID(detailEN.id);
        this.detailCache.set(`${canonical}_en`, detailEN);
        if (lang !== 'en') {
          this.detailCache.set(
            `${canonical}_${lang}`,
            translateDiscoveredDetail(detailEN, lang)
          );
        }
        matches.push(rawMealToSummary(meal));
      }
    } catch (err) {
      nameSearchError = err;
      usedOfflineCache = true;
    }

    let matchedArea = resolvedAreaForQuery(trimmed);
    if (!matchedArea) {
      matchedArea = await this.matchedRemoteArea(trimmed);
    }
    if (matchedArea) {
      try {
        const res = await this.filterByArea(matchedArea, lang);
        matches.push(...res.data);
        if (res.fromOfflineCache) usedOfflineCache = true;
      } catch {
        // non-fatal supplemental area search
      }
    }

    const matchedCategory = await this.matchedRemoteCategory(trimmed);
    if (matchedCategory) {
      try {
        const res = await this.filterByCategory(matchedCategory, lang);
        matches.push(...res.data);
        if (res.fromOfflineCache) usedOfflineCache = true;
      } catch {
        // non-fatal supplemental category search
      }
    }

    const matchedIngredient = await this.matchedRemoteIngredient(trimmed);
    if (matchedIngredient) {
      try {
        const res = await this.filterByIngredient(matchedIngredient);
        matches.push(...res);
      } catch {
        // non-fatal supplemental ingredient search
      }
    }

    if (matches.length === 0 && nameSearchError) {
      throw nameSearchError;
    }

    const excludedFiltered = matches.filter((m) => !isExcludedMeal(m.id, m.name));
    const localizedResults =
      lang !== 'en'
        ? excludedFiltered.map((item) => translateDiscoveredSummary(item, lang))
        : excludedFiltered;
    const merged = mergingDiscoveredSummaries([], localizedResults);

    if (!nameSearchError && !usedOfflineCache) {
      this.listCache.set(cacheKey, merged);
    }
    return { data: merged, fromOfflineCache: usedOfflineCache };
  }

  async lookup(
    id: string,
    lang: AppLanguage = getActiveLanguage()
  ): Promise<DiscoveredRecipeDetail> {
    const canonical = canonicalRecipeID(id);
    if (isExcludedMeal(canonical, null)) {
      throw new Error(tFor(lang, 'No recipes matched.'));
    }

    const local = getLocalMealDetail(canonical, lang);
    if (local) return local;

    const cacheKey = `${canonical}_${lang}`;
    const cached = this.detailCache.get(cacheKey);
    if (cached) return cached;

    const existingReq = this.detailRequests.get(cacheKey);
    if (existingReq) return existingReq;

    const task = (async () => {
      try {
        const { meals } = await this.fetchMeals(
          'lookup.php',
          { i: canonical },
          `detail:${canonical}`
        );
        const meal = meals[0];
        if (!meal || isExcludedMeal(meal.idMeal, meal.strMeal)) {
          throw new Error(tFor(lang, 'No recipes matched.'));
        }
        const detailEN = rawMealToDetail(meal);
        this.detailCache.set(`${canonical}_en`, detailEN);
        const localized =
          lang !== 'en' ? translateDiscoveredDetail(detailEN, lang) : detailEN;
        this.detailCache.set(cacheKey, localized);
        return localized;
      } catch (err) {
        if (lang === 'fr' && !isExcludedMeal(canonical, null)) {
          const record = getTheMealDBRecord(canonical);
          if (record) {
            const localized: DiscoveredRecipeDetail = {
              id: record.id,
              name: record.name,
              category: record.category || null,
              area: record.area || null,
              instructions: cleanInstructions(record.instructions, record.name),
              ingredients: record.ingredients,
              thumbnailURL: record.thumbnailURL || null,
              sourceURL: null,
              youtubeURL: null,
              tags: [],
              illustrationIconID: null,
            };
            this.detailCache.set(cacheKey, localized);
            return localized;
          }
        }
        throw err;
      } finally {
        this.detailRequests.delete(cacheKey);
      }
    })();

    this.detailRequests.set(cacheKey, task);
    return task;
  }

  async timeEstimate(
    id: string,
    lang: AppLanguage = getActiveLanguage()
  ): Promise<RecipeTimeEstimate | null> {
    const canonical = canonicalRecipeID(id);
    if (isExcludedMeal(canonical, null)) return null;
    const cacheKey = `${canonical}_${lang}`;
    const cached = this.timeCache.get(cacheKey);
    if (cached) return cached;

    try {
      const detail = await this.lookup(canonical, lang);
      const estimate = estimateRecipeTime(
        detail.instructions,
        detail.ingredients.length,
        detail.category
      );
      this.timeCache.set(cacheKey, estimate);
      return estimate;
    } catch {
      return null;
    }
  }
}

export const mealDBClient = new MealDBClient();
export { MealDBClient };
