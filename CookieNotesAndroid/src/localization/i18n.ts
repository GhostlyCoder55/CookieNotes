import en from './en.json';
import fr from './fr.json';
import es from './es.json';

export type AppLanguage = 'en' | 'fr' | 'es';

export interface LanguageOption {
  id: AppLanguage;
  code: AppLanguage;
  displayName: string;
  englishName: string;
  flagKind: 'uk' | 'fr' | 'es';
  localeIdentifier: string;
}

export const SUPPORTED_LANGUAGES: readonly LanguageOption[] = [
  {
    id: 'en',
    code: 'en',
    displayName: 'English',
    englishName: 'English',
    flagKind: 'uk',
    localeIdentifier: 'en-US',
  },
  {
    id: 'fr',
    code: 'fr',
    displayName: 'Français',
    englishName: 'French',
    flagKind: 'fr',
    localeIdentifier: 'fr-FR',
  },
  {
    id: 'es',
    code: 'es',
    displayName: 'Español',
    englishName: 'Spanish',
    flagKind: 'es',
    localeIdentifier: 'es-ES',
  },
] as const;

export const DEFAULT_LANGUAGE: AppLanguage = 'en';

export type TranslationTable = Record<string, string>;

const TABLES: Record<AppLanguage, TranslationTable> = {
  en: en as TranslationTable,
  fr: fr as TranslationTable,
  es: es as TranslationTable,
};

let activeLanguage: AppLanguage = DEFAULT_LANGUAGE;
const listeners = new Set<(lang: AppLanguage) => void>();

export function normalizeLanguageCode(raw?: string | null): AppLanguage {
  if (!raw) return DEFAULT_LANGUAGE;
  const trimmed = raw.trim().toLowerCase();
  if (trimmed === 'fr' || trimmed.startsWith('fr-') || trimmed.startsWith('fr_') || trimmed === 'french' || trimmed === 'français') {
    return 'fr';
  }
  if (trimmed === 'es' || trimmed.startsWith('es-') || trimmed.startsWith('es_') || trimmed === 'spanish' || trimmed === 'español') {
    return 'es';
  }
  return 'en';
}

export function getActiveLanguage(): AppLanguage {
  return activeLanguage;
}

export function setActiveLanguage(lang: AppLanguage): void {
  const normalized = normalizeLanguageCode(lang);
  if (activeLanguage === normalized) return;
  activeLanguage = normalized;
  for (const listener of listeners) {
    listener(normalized);
  }
}

export function subscribeLanguage(listener: (lang: AppLanguage) => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function getLanguageOption(lang: AppLanguage): LanguageOption {
  return SUPPORTED_LANGUAGES.find((item) => item.id === lang) ?? SUPPORTED_LANGUAGES[0];
}

export function getTranslations(lang: AppLanguage): TranslationTable {
  return TABLES[lang] ?? TABLES.en;
}

/**
 * Formats Swift-style `%@`, `%lld`, `%d`, and `%1$@` placeholders sequentially.
 */
export function formatTemplate(template: string, args: Array<string | number>): string {
  if (args.length === 0) return template;
  let index = 0;
  let result = template.replace(/%(\d+)\$(@|lld|ld|d|s)/g, (_match, posStr: string) => {
    const pos = Math.max(1, Number.parseInt(posStr, 10)) - 1;
    const value = args[pos];
    return value !== undefined ? String(value) : '';
  });
  result = result.replace(/%(@|lld|ld|d|s)/g, () => {
    const value = args[index];
    index += 1;
    return value !== undefined ? String(value) : '';
  });
  return result;
}

export function tFor(
  lang: AppLanguage,
  key: string,
  ...args: Array<string | number>
): string {
  const table = TABLES[lang] ?? TABLES.en;
  const fallback = TABLES.en[key] ?? key;
  const raw = table[key] ?? fallback;
  return formatTemplate(raw, args);
}

export function t(key: string, ...args: Array<string | number>): string {
  return tFor(activeLanguage, key, ...args);
}

export function localizedDatabaseSourceName(lang: AppLanguage = activeLanguage): string {
  return tFor(lang, 'the meal database');
}

export function formatRecipeCount(count: number, lang: AppLanguage = activeLanguage): string {
  if (lang === 'fr') {
    return count === 1 ? '1 recette' : `${count} recettes`;
  }
  if (lang === 'es') {
    return count === 1 ? '1 receta' : `${count} recetas`;
  }
  return count === 1 ? '1 recipe' : `${count} recipes`;
}
