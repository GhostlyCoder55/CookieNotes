import {
  FOOD_PNG_ASSETS,
  FOOD_SVG_ASSETS,
  hasFoodAsset,
  TOTAL_FOOD_ASSETS,
} from '../assets/foodIconRegistry';
import {
  getAllLocalMeals,
  getLocalMealDetail,
} from '../data/localMealCatalog';
import {
  getAllTheMealDBRecords,
  getTheMealDBRecord,
  searchTheMealDBFrenchCatalog,
} from '../data/theMealDBCatalog';
import {
  findMatchingIconID,
  getAllIngredientIcons,
  getIngredientCatalog,
  getIngredientDisplayName,
} from '../utils/ingredientCatalog';
import { isExcludedMeal } from '../utils/mealIdentity';
import { cleanInstructions } from '../utils/recipeSanitizer';
import { getRegionForArea } from '../utils/cuisineTaxonomy';

describe('Assets, Ingredient Catalog, and Bundled Recipe Catalogs', () => {
  test('all 349 food illustrations (114 PNG + 235 SVG) are registered with zero collisions', () => {
    const pngKeys = Object.keys(FOOD_PNG_ASSETS);
    const svgKeys = Object.keys(FOOD_SVG_ASSETS);

    expect(pngKeys.length).toBe(114);
    expect(svgKeys.length).toBe(235);
    expect(pngKeys.length + svgKeys.length).toBe(TOTAL_FOOD_ASSETS);

    const overlap = pngKeys.filter((k) => Boolean(FOOD_SVG_ASSETS[k]));
    expect(overlap).toEqual([]);
  });

  test('ingredient catalog has 12 categories and every referenced icon exists in registry', () => {
    const enIcons = getAllIngredientIcons();
    expect(enIcons.length).toBeGreaterThanOrEqual(310);

    for (const lang of ['en', 'fr', 'es'] as const) {
      const catalog = getIngredientCatalog(lang);
      expect(catalog.categories.length).toBe(12);

      for (const category of catalog.categories) {
        expect(category.icons.length).toBeGreaterThan(0);
        for (const iconID of category.icons) {
          expect(hasFoodAsset(iconID)).toBe(true);
          expect(getIngredientDisplayName(iconID, lang).trim().length).toBeGreaterThan(0);
        }
      }
    }
  });

  test('ingredient icon matching works consistently across EN, FR, ES with accent tolerance', () => {
    const pairs: Array<[string, string, string, string]> = [
      ['apple', 'pomme', 'manzana', 'apple'],
      ['onion', 'oignon', 'cebolla', 'onion'],
      ['garlic', 'ail', 'ajo', 'garlic'],
      ['carrot', 'carotte', 'zanahoria', 'carrot'],
      ['chicken', 'poulet', 'pollo', 'whole_raw_chicken'],
      ['shallot', 'échalote', 'chalote', 'shallot'],
      ['shallot', 'echalote', 'chalote', 'shallot'],
    ];

    for (const [enText, frText, esText, expected] of pairs) {
      expect(findMatchingIconID(enText, 'en')).toBe(expected);
      expect(findMatchingIconID(frText, 'fr')).toBe(expected);
      expect(findMatchingIconID(esText, 'es')).toBe(expected);
    }

    expect(getIngredientDisplayName('apple', 'en')).toBe('Apple');
    expect(getIngredientDisplayName('apple', 'fr')).toBe('Pomme');
    expect(getIngredientDisplayName('apple', 'es')).toBe('Manzana');
  });

  test('LocalMealCatalog matches 1-to-1 across EN (41), FR (41), and ES (41)', () => {
    const enMeals = getAllLocalMeals('en');
    const frMeals = getAllLocalMeals('fr');
    const esMeals = getAllLocalMeals('es');

    expect(enMeals.length).toBe(41);
    expect(frMeals.length).toBe(41);
    expect(esMeals.length).toBe(41);

    const frById = new Map(frMeals.map((m) => [m.id, m]));
    const esById = new Map(esMeals.map((m) => [m.id, m]));
    const seenSources = new Set<string>();
    const seenThumbs = new Set<string>();

    for (const en of enMeals) {
      expect(en.id.startsWith('local-mdb-')).toBe(false);
      expect(getRegionForArea(en.area)).not.toBeNull();
      expect(['side', 'sides', 'snack', 'snacks']).not.toContain(
        en.category.toLowerCase()
      );

      const fr = frById.get(en.id);
      const es = esById.get(en.id);
      expect(fr).toBeDefined();
      expect(es).toBeDefined();
      if (!fr || !es) continue;

      expect(fr.category).toBe(en.category);
      expect(es.category).toBe(en.category);
      expect(fr.area).toBe(en.area);
      expect(es.area).toBe(en.area);
      expect(fr.thumbnailURL).toBe(en.thumbnailURL);
      expect(es.thumbnailURL).toBe(en.thumbnailURL);
      expect(fr.sourceURL).toBe(en.sourceURL);
      expect(es.sourceURL).toBe(en.sourceURL);

      expect(fr.ingredients.length).toBe(en.ingredients.length);
      expect(es.ingredients.length).toBe(en.ingredients.length);
      expect(fr.instructions.length).toBe(en.instructions.length);
      expect(es.instructions.length).toBe(en.instructions.length);

      expect(cleanInstructions(en.instructions, en.name)).toEqual(en.instructions);
      expect(cleanInstructions(fr.instructions, fr.name)).toEqual(fr.instructions);
      expect(cleanInstructions(es.instructions, es.name)).toEqual(es.instructions);

      expect(en.sourceURL).toBeTruthy();
      expect(seenSources.has(en.sourceURL!)).toBe(false);
      seenSources.add(en.sourceURL!);

      expect(en.thumbnailURL?.startsWith('https://')).toBe(true);
      expect(seenThumbs.has(en.thumbnailURL!)).toBe(false);
      seenThumbs.add(en.thumbnailURL!);
    }

    const french = enMeals.find((m) => m.area === 'French')!;
    const frenchDetail = getLocalMealDetail(french.id, 'en')!;
    expect(frenchDetail.tags).toContain('European');
    expect(frenchDetail.tags).not.toContain('African');
  });

  test('TheMealDB_fr catalog has 792 valid clean records and excludes 53284 (Bouzgene)', () => {
    const records = getAllTheMealDBRecords();
    expect(records.length).toBe(792);
    expect(getTheMealDBRecord('53284')).toBeNull();
    expect(getTheMealDBRecord('52885')).not.toBeNull();
    expect(getTheMealDBRecord('53120')).not.toBeNull();
    expect(getTheMealDBRecord('53282')?.name).toBe('Carottes algériennes');

    for (const rec of records) {
      expect(isExcludedMeal(rec.id, rec.name)).toBe(false);
      expect(rec.name.trim().length).toBeGreaterThan(0);
      expect(rec.ingredients.length).toBeGreaterThan(0);
      expect(rec.instructions.length).toBeGreaterThan(0);
      expect(Boolean(rec.thumbnailURL && rec.thumbnailURL.length > 0)).toBe(true);
      for (const ing of rec.ingredients) {
        expect(ing.trim().length).toBeGreaterThan(0);
      }
      for (const step of rec.instructions) {
        expect(step.trim().length).toBeGreaterThan(0);
        expect(step.includes('\u200B')).toBe(false);
        expect(['□', '☐', '◻']).not.toContain(step);
      }
    }

    const chicken = searchTheMealDBFrenchCatalog('poulet');
    expect(chicken.length).toBeGreaterThan(0);
    expect(chicken.every((r) => r.id !== '53284' && Boolean(r.thumbnailURL))).toBe(true);
  });
});
