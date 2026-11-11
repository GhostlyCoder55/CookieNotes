import rawCatalogFR from '../data/TheMealDB_fr.json';
import { tFor } from '../localization/i18n';
import type { DiscoveredRecipeSummary, TheMealDBRecord } from '../types/models';
import { normalizeTaxonomyText } from '../utils/cuisineTaxonomy';
import {
  alphabeticallySortedSummaries,
  canonicalRecipeID,
  isExcludedMeal,
} from '../utils/mealIdentity';

const RECORDS: Record<string, TheMealDBRecord> = rawCatalogFR as Record<string, TheMealDBRecord>;

export function getAllTheMealDBRecords(): TheMealDBRecord[] {
  return Object.values(RECORDS).filter((record) => !isExcludedMeal(record.id, record.name));
}

export function getTheMealDBRecord(id: string): TheMealDBRecord | null {
  const canonical = canonicalRecipeID(id);
  if (isExcludedMeal(canonical, null)) return null;
  const record = RECORDS[canonical];
  if (!record || isExcludedMeal(record.id, record.name)) return null;
  return record;
}

export function getTranslatedFrenchName(id: string): string | null {
  return getTheMealDBRecord(id)?.name ?? null;
}

export function findUnambiguousTheMealDBID(title: string): string | null {
  const normalizedTitle = normalizeTaxonomyText(title);
  if (!normalizedTitle) return null;
  const matches = getAllTheMealDBRecords().filter(
    (record) => normalizeTaxonomyText(record.name) === normalizedTitle
  );
  return matches.length === 1 ? matches[0].id : null;
}

export function toTheMealDBSummary(record: TheMealDBRecord): DiscoveredRecipeSummary {
  return {
    id: record.id,
    name: record.name,
    thumbnailURL: record.thumbnailURL || null,
    category: record.category && record.category.length > 0 ? record.category : null,
    area: record.area && record.area.length > 0 ? record.area : null,
    illustrationIconID: null,
  };
}

export function searchTheMealDBFrenchCatalog(query: string): DiscoveredRecipeSummary[] {
  const terms = normalizeTaxonomyText(query)
    .split(' ')
    .filter((t) => t.length > 0);
  if (terms.length === 0) return [];

  const matched = getAllTheMealDBRecords().filter((record) => {
    const areaLabel = record.area ? tFor('fr', record.area) : '';
    const categoryLabel = record.category ? tFor('fr', record.category) : '';
    const searchableWords = [
      record.name,
      record.category ?? '',
      categoryLabel,
      record.area ?? '',
      areaLabel,
      ...record.ingredients,
    ]
      .map(normalizeTaxonomyText)
      .join(' ')
      .split(' ')
      .filter((w) => w.length > 0);

    return terms.every((queryTerm) =>
      searchableWords.some((word) => word === queryTerm || word.startsWith(queryTerm))
    );
  });

  return alphabeticallySortedSummaries(matched.map(toTheMealDBSummary));
}
