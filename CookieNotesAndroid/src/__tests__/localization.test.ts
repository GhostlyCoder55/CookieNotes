import en from '../localization/en.json';
import fr from '../localization/fr.json';
import es from '../localization/es.json';
import {
  DEFAULT_LANGUAGE,
  formatTemplate,
  formatRecipeCount,
  getActiveLanguage,
  getLanguageOption,
  normalizeLanguageCode,
  setActiveLanguage,
  SUPPORTED_LANGUAGES,
  t,
  tFor,
} from '../localization/i18n';
import { getCategoryTitle, getFilterTitle, RECIPE_CATEGORIES, RECIPE_FILTERS } from '../utils/recipeCategory';
import { getGrocerySortTitle } from '../utils/groceryListLogic';
import { formatDurationShort } from '../utils/recipeTimeEstimator';

describe('Localization System (EN / FR / ES)', () => {
  const originalLang = getActiveLanguage();

  afterEach(() => {
    setActiveLanguage(originalLang);
  });

  test('defaults to English and supports English, French, and Spanish', () => {
    expect(DEFAULT_LANGUAGE).toBe('en');
    expect(SUPPORTED_LANGUAGES.map((l) => l.code)).toEqual(['en', 'fr', 'es']);
    expect(getLanguageOption('en').localeIdentifier).toBe('en-US');
    expect(getLanguageOption('fr').localeIdentifier).toBe('fr-FR');
    expect(getLanguageOption('es').localeIdentifier).toBe('es-ES');

    expect(normalizeLanguageCode('fr-CA')).toBe('fr');
    expect(normalizeLanguageCode('es_MX')).toBe('es');
    expect(normalizeLanguageCode('en-GB')).toBe('en');
    expect(normalizeLanguageCode(undefined)).toBe('en');
  });

  test('en.json, fr.json, and es.json have 100% key parity and no empty values', () => {
    const enKeys = Object.keys(en).sort();
    const frKeys = Object.keys(fr).sort();
    const esKeys = Object.keys(es).sort();

    expect(enKeys.length).toBeGreaterThanOrEqual(300);
    expect(frKeys).toEqual(enKeys);
    expect(esKeys).toEqual(enKeys);

    for (const key of enKeys) {
      expect((en as Record<string, string>)[key].trim().length).toBeGreaterThan(0);
      expect((fr as Record<string, string>)[key].trim().length).toBeGreaterThan(0);
      expect((es as Record<string, string>)[key].trim().length).toBeGreaterThan(0);
    }
  });

  test('formatTemplate handles positional, sequential %@ and %lld placeholders', () => {
    expect(formatTemplate('Added %@', ['Milk'])).toBe('Added Milk');
    expect(formatTemplate('%@ ajouté', ['Lait'])).toBe('Lait ajouté');
    expect(formatTemplate('Step %lld of %lld', [2, 5])).toBe('Step 2 of 5');
    expect(formatTemplate('%lld hr %lld min', [1, 15])).toBe('1 hr 15 min');
    expect(formatTemplate('%2$@ then %1$@', ['first', 'second'])).toBe('second then first');
  });

  test('live language switching updates t() and tFor() across EN, FR, ES', () => {
    setActiveLanguage('fr');
    expect(getActiveLanguage()).toBe('fr');
    expect(t('Library')).toBe('Bibliothèque');
    expect(t('Added %@', 'Lait')).toBe('Lait ajouté');

    setActiveLanguage('es');
    expect(getActiveLanguage()).toBe('es');
    expect(t('Library')).toBe('Biblioteca');
    expect(t('Discover')).toBe('Descubrir');
    expect(t('Added %@', 'Leche')).toBe('Añadido: Leche');

    setActiveLanguage('en');
    expect(t('Library')).toBe('Library');
    expect(tFor('es', 'List')).toBe('Lista');
    expect(tFor('fr', 'List')).toBe('Liste');
  });

  test('categories, filters, grocery sorts, and time units localize accurately', () => {
    expect(RECIPE_CATEGORIES).not.toContain('snack');
    expect(RECIPE_CATEGORIES).not.toContain('snacks');
    expect(RECIPE_CATEGORIES).not.toContain('sides');
    expect(RECIPE_FILTERS).not.toContain('snack');
    expect(RECIPE_FILTERS).not.toContain('sides');

    expect(getCategoryTitle('dinner', 'en')).toBe('Dinner');
    expect(getCategoryTitle('dinner', 'fr')).toBe('Souper');
    expect(getCategoryTitle('dinner', 'es')).toBe('Cena');

    expect(getCategoryTitle('breakfast', 'fr')).toBe('Déjeuner');
    expect(getCategoryTitle('lunch', 'fr')).toBe('Dîner');
    expect(getFilterTitle('favorites', 'es')).toBe('Favoritas');

    expect(getGrocerySortTitle('default', 'fr')).toBe('Par défaut');
    expect(getGrocerySortTitle('uncheckedFirst', 'fr')).toBe("Non cochés d'abord");
    expect(getGrocerySortTitle('uncheckedFirst', 'es')).toBe('Sin marcar primero');
    expect(getGrocerySortTitle('alphabetical', 'es')).toBe('A–Z');

    expect(formatDurationShort(45, 'fr')).toBe('45 min');
    expect(formatDurationShort(60, 'fr')).toBe('1 h');
    expect(formatDurationShort(75, 'en')).toBe('1 hr 15 min');
    expect(formatDurationShort(75, 'es')).toBe('1 h 15 min');

    expect(formatRecipeCount(1, 'en')).toBe('1 recipe');
    expect(formatRecipeCount(3, 'fr')).toBe('3 recettes');
    expect(formatRecipeCount(2, 'es')).toBe('2 recetas');
  });
});
