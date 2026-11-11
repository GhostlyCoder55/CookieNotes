import rawEN from '../data/LocalMealCatalog.json';
import rawFR from '../data/LocalMealCatalog_fr.json';
import rawES from '../data/LocalMealCatalog_es.json';
import { getActiveLanguage, type AppLanguage } from '../localization/i18n';
import type {
  CuisineRegion,
  DiscoveredRecipeDetail,
  DiscoveredRecipeSummary,
  LocalMealRecord,
} from '../types/models';
import {
  getCanonicalArea,
  getRegionForArea,
  getSearchTermsForArea,
  normalizeTaxonomyText,
} from '../utils/cuisineTaxonomy';
import { canonicalRecipeID } from '../utils/mealIdentity';

interface LocalMealFile {
  meals: LocalMealRecord[];
}

const MEALS_BY_LANGUAGE: Record<AppLanguage, LocalMealRecord[]> = {
  en: (rawEN as LocalMealFile).meals ?? [],
  fr: (rawFR as LocalMealFile).meals ?? [],
  es: (rawES as LocalMealFile).meals ?? [],
};

export function toLocalMealSummary(record: LocalMealRecord): DiscoveredRecipeSummary {
  return {
    id: record.id,
    name: record.name,
    thumbnailURL: record.thumbnailURL || null,
    category: record.category || null,
    area: record.area || null,
    illustrationIconID: record.illustration || null,
  };
}

export function toLocalMealDetail(record: LocalMealRecord): DiscoveredRecipeDetail {
  const region = getRegionForArea(record.area);
  const tags = [record.area, region ?? ''].filter((v) => v.length > 0);
  return {
    id: record.id,
    name: record.name,
    category: record.category || null,
    area: record.area || null,
    instructions: record.instructions,
    ingredients: record.ingredients,
    thumbnailURL: record.thumbnailURL || null,
    sourceURL: record.sourceURL || null,
    youtubeURL: null,
    tags,
    illustrationIconID: record.illustration || null,
  };
}

function recordMatchesSearch(record: LocalMealRecord, query: string): boolean {
  const terms = normalizeTaxonomyText(query)
    .split(' ')
    .filter((t) => t.length > 0);
  if (terms.length === 0) return false;

  const cuisineTerms = [
    ...getSearchTermsForArea(record.area),
    getRegionForArea(record.area) ?? '',
  ];
  const searchableText = [
    record.name,
    record.category,
    record.area,
    record.sourceURL ?? '',
    ...record.ingredients,
    ...record.instructions,
    ...cuisineTerms,
  ]
    .map(normalizeTaxonomyText)
    .join(' ');

  const searchableWords = searchableText.split(' ').filter((w) => w.length > 0);
  return terms.every((queryTerm) =>
    searchableWords.some((word) => word === queryTerm || word.startsWith(queryTerm))
  );
}

export function getAllLocalMeals(lang: AppLanguage = getActiveLanguage()): LocalMealRecord[] {
  return MEALS_BY_LANGUAGE[lang] ?? MEALS_BY_LANGUAGE.en;
}

export function getLocalMealRecord(
  id: string,
  lang: AppLanguage = getActiveLanguage()
): LocalMealRecord | null {
  const canonical = canonicalRecipeID(id);
  const pool = getAllLocalMeals(lang);
  return pool.find((item) => item.id === canonical) ?? null;
}

export function getCanonicalIDForSourceURL(sourceURL: string): string | null {
  const normalized = sourceURL.trim().toLowerCase();
  if (!normalized) return null;
  const match = MEALS_BY_LANGUAGE.en.find(
    (item) => (item.sourceURL ?? '').trim().toLowerCase() === normalized
  );
  return match?.id ?? null;
}

export function getLocalMealDetail(
  id: string,
  lang: AppLanguage = getActiveLanguage()
): DiscoveredRecipeDetail | null {
  const record = getLocalMealRecord(id, lang);
  return record ? toLocalMealDetail(record) : null;
}

export function searchLocalMeals(
  query: string,
  lang: AppLanguage = getActiveLanguage()
): DiscoveredRecipeSummary[] {
  return getAllLocalMeals(lang)
    .filter((record) => recordMatchesSearch(record, query))
    .map(toLocalMealSummary);
}

export function filterLocalMealsByArea(
  area: string,
  lang: AppLanguage = getActiveLanguage()
): DiscoveredRecipeSummary[] {
  const key = normalizeTaxonomyText(area);
  return getAllLocalMeals(lang)
    .filter((record) => normalizeTaxonomyText(record.area) === key)
    .map(toLocalMealSummary);
}

export function filterLocalMealsByRegion(
  region: CuisineRegion,
  lang: AppLanguage = getActiveLanguage()
): DiscoveredRecipeSummary[] {
  return getAllLocalMeals(lang)
    .filter((record) => getRegionForArea(record.area) === region)
    .map(toLocalMealSummary);
}

export function resolvedAreaForQuery(query: string): string | null {
  return getCanonicalArea(query);
}
