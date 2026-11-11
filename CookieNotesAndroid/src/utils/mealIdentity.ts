import type { DiscoveredRecipeSummary } from '../types/models';

export function canonicalRecipeID(id: string): string {
  const trimmed = id.trim();
  if (trimmed.startsWith('local-mdb-')) {
    return trimmed.slice('local-mdb-'.length);
  }
  return trimmed;
}

export function isExcludedMeal(id?: string | null, name?: string | null): boolean {
  if (id && canonicalRecipeID(id) === '53284') {
    return true;
  }
  if (name) {
    const folded = name
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase();
    if (folded.includes('bouzgene')) {
      return true;
    }
  }
  return false;
}

export function getCardThumbnailURL(thumbnailURL?: string | null): string | null {
  if (!thumbnailURL) return null;
  try {
    const parsed = new URL(thumbnailURL);
    if (!parsed.hostname.includes('themealdb.com')) {
      return thumbnailURL;
    }
    const cleanPath = parsed.pathname.replace(/\/+$/, '');
    if (cleanPath.endsWith('/medium') || cleanPath === 'medium') {
      return thumbnailURL;
    }
    parsed.pathname = `${cleanPath}/medium`;
    return parsed.toString();
  } catch {
    return thumbnailURL;
  }
}

export function alphabeticallySortedSummaries(
  recipes: readonly DiscoveredRecipeSummary[]
): DiscoveredRecipeSummary[] {
  return [...recipes].sort((lhs, rhs) => {
    const cmp = lhs.name.localeCompare(rhs.name, undefined, { sensitivity: 'base', numeric: true });
    return cmp === 0 ? lhs.id.localeCompare(rhs.id) : cmp;
  });
}

export function mergingDiscoveredSummaries(
  local: readonly DiscoveredRecipeSummary[],
  remote: readonly DiscoveredRecipeSummary[]
): DiscoveredRecipeSummary[] {
  const indexByCanonicalID = new Map<string, number>();
  const merged: DiscoveredRecipeSummary[] = [];

  for (const rawItem of [...local, ...remote]) {
    const canonical = canonicalRecipeID(rawItem.id);
    const normalizedItem: DiscoveredRecipeSummary = {
      id: canonical,
      name: rawItem.name,
      thumbnailURL: rawItem.thumbnailURL ?? null,
      category: rawItem.category && rawItem.category.length > 0 ? rawItem.category : null,
      area: rawItem.area && rawItem.area.length > 0 ? rawItem.area : null,
      illustrationIconID: rawItem.illustrationIconID ?? null,
    };

    const existingIndex = indexByCanonicalID.get(canonical);
    if (existingIndex !== undefined) {
      const existing = merged[existingIndex];
      merged[existingIndex] = {
        id: existing.id,
        name: existing.name.length > 0 ? existing.name : normalizedItem.name,
        thumbnailURL: existing.thumbnailURL ?? normalizedItem.thumbnailURL,
        category: existing.category ?? normalizedItem.category,
        area: existing.area ?? normalizedItem.area,
        illustrationIconID: existing.illustrationIconID ?? normalizedItem.illustrationIconID,
      };
      continue;
    }

    indexByCanonicalID.set(canonical, merged.length);
    merged.push(normalizedItem);
  }

  return merged;
}
