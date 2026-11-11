import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { DiscoveredRecipeDetail } from '../types/models';

export function getRecipeAttribution(
  detail: Pick<DiscoveredRecipeDetail, 'id' | 'sourceURL' | 'area' | 'category'>,
  lang: AppLanguage = getActiveLanguage()
): string {
  const isLocal = detail.id.startsWith('local-');
  let sourceLabel: string;
  if (detail.sourceURL && detail.sourceURL.includes('epicurious.com')) {
    sourceLabel = 'Epicurious';
  } else if (isLocal) {
    sourceLabel = tFor(lang, 'CookieNotes kitchen');
  } else {
    sourceLabel = tFor(lang, 'the meal database');
  }

  const parts = [sourceLabel];
  if (detail.area && detail.area.trim().length > 0) {
    parts.push(tFor(lang, detail.area));
  }
  if (detail.category && detail.category.trim().length > 0) {
    parts.push(tFor(lang, detail.category));
  }
  return parts.join(' · ');
}
