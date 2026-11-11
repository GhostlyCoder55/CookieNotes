import rawCatalogEN from '../data/IngredientCatalog.json';
import rawCatalogFR from '../data/IngredientCatalog_fr.json';
import rawCatalogES from '../data/IngredientCatalog_es.json';
import { getActiveLanguage, type AppLanguage } from '../localization/i18n';
import type { IngredientCatalogFile } from '../types/models';

interface SortedEntry {
  key: string;
  icon: string;
}

interface CatalogBundle {
  catalog: IngredientCatalogFile;
  aliasesByLength: SortedEntry[];
  namesByLength: SortedEntry[];
}

function cleanCatalog(raw: IngredientCatalogFile): IngredientCatalogFile {
  return {
    categories: (raw.categories ?? []).filter((cat) => (cat.icons ?? []).length > 0),
    displayNames: raw.displayNames ?? {},
    aliases: raw.aliases ?? {},
  };
}

function sortAliases(dict: Record<string, string>): SortedEntry[] {
  return Object.entries(dict)
    .map(([key, icon]) => ({ key: key.toLowerCase(), icon }))
    .filter((entry) => entry.key.length > 0)
    .sort((a, b) =>
      a.key.length !== b.key.length ? b.key.length - a.key.length : a.key.localeCompare(b.key)
    );
}

function sortDisplayNames(dict: Record<string, string>): SortedEntry[] {
  return Object.entries(dict)
    .map(([icon, name]) => ({ key: name.toLowerCase(), icon }))
    .filter((entry) => entry.key.length > 0)
    .sort((a, b) =>
      a.key.length !== b.key.length ? b.key.length - a.key.length : a.key.localeCompare(b.key)
    );
}

function makeBundle(raw: IngredientCatalogFile): CatalogBundle {
  const catalog = cleanCatalog(raw);
  return {
    catalog,
    aliasesByLength: sortAliases(catalog.aliases),
    namesByLength: sortDisplayNames(catalog.displayNames),
  };
}

const BUNDLES: Record<AppLanguage, CatalogBundle> = {
  en: makeBundle(rawCatalogEN as IngredientCatalogFile),
  fr: makeBundle(rawCatalogFR as IngredientCatalogFile),
  es: makeBundle(rawCatalogES as IngredientCatalogFile),
};

const ALL_ICONS: string[] = Array.from(
  new Set(BUNDLES.en.catalog.categories.flatMap((cat) => cat.icons))
).sort();

const PICKABLE_ICONS: string[] = ALL_ICONS.filter(
  (id) => !id.startsWith('cat_') && !id.startsWith('extra_')
);

const matchCache = new Map<string, string>();

function foldDiacritics(value: string): string {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

function matchInBundle(bundle: CatalogBundle, term: string): string | null {
  const directAlias = bundle.catalog.aliases[term];
  if (directAlias) return directAlias;

  for (const entry of bundle.aliasesByLength) {
    if (term.includes(entry.key)) return entry.icon;
  }

  for (const entry of bundle.namesByLength) {
    if (term.includes(entry.key)) return entry.icon;
  }

  return null;
}

export function getIngredientCatalog(lang: AppLanguage = getActiveLanguage()): IngredientCatalogFile {
  return BUNDLES[lang].catalog;
}

export function getAllIngredientIcons(): string[] {
  return ALL_ICONS;
}

export function getAllPickableIngredientIcons(): string[] {
  return PICKABLE_ICONS;
}

export function getIngredientDisplayName(
  iconID: string,
  lang: AppLanguage = getActiveLanguage()
): string {
  return (
    BUNDLES[lang].catalog.displayNames[iconID] ??
    BUNDLES.en.catalog.displayNames[iconID] ??
    iconID
      .split('_')
      .map((part) => (part ? part[0].toUpperCase() + part.slice(1) : ''))
      .join(' ')
  );
}

export function findMatchingIconID(
  text: string,
  lang: AppLanguage = getActiveLanguage()
): string | null {
  const trimmed = text.trim().toLowerCase();
  if (!trimmed) return null;

  const cacheKey = `${lang}|${trimmed}`;
  const cached = matchCache.get(cacheKey);
  if (cached !== undefined) {
    return cached.length > 0 ? cached : null;
  }

  const fallbackOrder: AppLanguage[] =
    lang === 'en' ? ['en', 'fr', 'es'] : lang === 'fr' ? ['fr', 'en', 'es'] : ['es', 'en', 'fr'];

  const folded = foldDiacritics(trimmed);
  let matched: string | null = null;

  for (const candidateLang of fallbackOrder) {
    const bundle = BUNDLES[candidateLang];
    matched = matchInBundle(bundle, trimmed);
    if (!matched && folded !== trimmed) {
      matched = matchInBundle(bundle, folded);
    }
    if (matched) break;
  }

  matchCache.set(cacheKey, matched ?? '');
  return matched;
}
