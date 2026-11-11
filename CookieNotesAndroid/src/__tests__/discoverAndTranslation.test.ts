import { MealDBClient, mealDBClient } from '../api/mealDBClient';
import {
  filterLocalMealsByArea,
  filterLocalMealsByRegion,
  resolvedAreaForQuery,
  searchLocalMeals,
} from '../data/localMealCatalog';
import { findUnambiguousTheMealDBID } from '../data/theMealDBCatalog';
import { setActiveLanguage } from '../localization/i18n';
import type { DiscoveredRecipeSummary } from '../types/models';
import { ALL_CUISINE_REGIONS, getCanonicalArea, getRegionForArea } from '../utils/cuisineTaxonomy';
import { findMatchingIconID } from '../utils/ingredientCatalog';
import {
  alphabeticallySortedSummaries,
  canonicalRecipeID,
  getCardThumbnailURL,
  isExcludedMeal,
  mergingDiscoveredSummaries,
} from '../utils/mealIdentity';
import { translateDiscoveredDetail, translateIngredient } from '../utils/recipeTranslator';

describe('Discover, Cuisine Taxonomy, MealDB Client, and Translation', () => {
  afterEach(() => {
    setActiveLanguage('en');
    mealDBClient.clearMemoryCache();
    jest.restoreAllMocks();
  });

  test('cuisine taxonomy maps EN/FR/ES areas and 8 geographic regions reliably', () => {
    expect(ALL_CUISINE_REGIONS).toEqual([
      'African',
      'Asian',
      'Caribbean',
      'European',
      'Middle Eastern',
      'North American',
      'Oceania',
      'South American',
    ]);

    expect(resolvedAreaForQuery('Japan')).toBe('Japanese');
    expect(resolvedAreaForQuery('Vietnam')).toBe('Vietnamese');
    expect(resolvedAreaForQuery('Yemen')).toBe('Yemeni');

    expect(getCanonicalArea('mexicain')).toBe('Mexican');
    expect(getCanonicalArea('française')).toBe('French');
    expect(getCanonicalArea('japonais')).toBe('Japanese');
    expect(getCanonicalArea('español')).toBe('Spanish');

    expect(getRegionForArea('Japanese', 'Japan')).toBe('Asian');
    expect(getRegionForArea('Yemeni', 'Yemen')).toBe('Middle Eastern');
    expect(filterLocalMealsByRegion('African').some((m) => m.area === 'Nigerian')).toBe(true);
    expect(filterLocalMealsByArea('French', 'en').length).toBeGreaterThan(0);

    const nigeria = searchLocalMeals('Nigeria', 'en');
    expect(nigeria.some((m) => m.id === 'local-jollof-rice')).toBe(true);
    const japan = searchLocalMeals('Japan', 'en');
    expect(japan.some((m) => m.id === 'local-jollof-rice')).toBe(false);
  });

  test('mealIdentity canonicalizes IDs, appends /medium thumbnails, excludes 53284, and merges without dropping same-name IDs', () => {
    expect(canonicalRecipeID('local-mdb-52928')).toBe('52928');
    expect(canonicalRecipeID('local-jollof-rice')).toBe('local-jollof-rice');

    expect(isExcludedMeal('53284', null)).toBe(true);
    expect(isExcludedMeal(null, 'Pain berbère algérien bouzgène')).toBe(true);
    expect(isExcludedMeal(null, 'Algerian Bouzgene Berber Bread')).toBe(true);

    expect(
      getCardThumbnailURL('https://www.themealdb.com/images/media/meals/abc.jpg')
    ).toBe('https://www.themealdb.com/images/media/meals/abc.jpg/medium');
    expect(
      getCardThumbnailURL('https://www.themealdb.com/images/media/meals/abc.jpg/medium')
    ).toBe('https://www.themealdb.com/images/media/meals/abc.jpg/medium');
    expect(getCardThumbnailURL('https://cdn.example.com/photo.jpg')).toBe(
      'https://cdn.example.com/photo.jpg'
    );

    const localDup: DiscoveredRecipeSummary = {
      id: 'local-mdb-52928',
      name: 'BeaverTails',
      thumbnailURL: 'https://www.themealdb.com/images/media/meals/beavertails.jpg',
      category: 'Dessert',
      area: 'Canadian',
      illustrationIconID: 'pancakes',
    };
    const remoteCanonical: DiscoveredRecipeSummary = {
      id: '52928',
      name: 'Queues de castor',
      thumbnailURL: null,
      category: null,
      area: '',
    };
    const merged = mergingDiscoveredSummaries([localDup], [remoteCanonical]);
    expect(merged.length).toBe(1);
    expect(merged[0].id).toBe('52928');
    expect(merged[0].category).toBe('Dessert');
    expect(merged[0].area).toBe('Canadian');
    expect(merged[0].thumbnailURL).toBe(localDup.thumbnailURL);

    // Distinct IDs with identical title must both survive
    const sameName = mergingDiscoveredSummaries(
      [],
      [
        { id: '53064', name: 'Fettuccine Alfredo', thumbnailURL: null, category: 'Pasta', area: 'Italian' },
        { id: '52835', name: 'Fettuccine Alfredo', thumbnailURL: null, category: 'Pasta', area: 'Italian' },
      ]
    );
    expect(sameName.map((s) => s.id)).toEqual(['53064', '52835']);

    expect(findUnambiguousTheMealDBID('Fettuccine Alfredo')).toBeNull();
    expect(findUnambiguousTheMealDBID('Carottes algériennes')).toBe('53282');

    expect(
      alphabeticallySortedSummaries([
        { id: '3', name: 'Jollof Rice', thumbnailURL: null, category: null, area: null },
        { id: '1', name: 'Apple Pie', thumbnailURL: null, category: null, area: null },
        { id: '2', name: 'Beef Stew', thumbnailURL: null, category: null, area: null },
      ]).map((s) => s.name)
    ).toEqual(['Apple Pie', 'Beef Stew', 'Jollof Rice']);
  });

  test('RecipeTranslator translates ingredients and catalog details to French & Spanish accurately', async () => {
    const thymeFR = translateIngredient('1/2 teaspoon Thyme', 'fr');
    expect(thymeFR).toContain('c. à thé');
    expect(thymeFR.toLowerCase()).toContain('thym');
    expect(findMatchingIconID(thymeFR, 'fr')).toBe('thyme');

    const oilFR = translateIngredient('5 tablespoons Olive Oil', 'fr');
    expect(oilFR).toContain('c. à soupe');
    expect(findMatchingIconID(oilFR, 'fr')).toBe('olive_oil');

    const garlicES = translateIngredient('3 Cloves Crushed Garlic', 'es');
    expect(garlicES.toLowerCase()).toContain('dientes');
    expect(garlicES.toLowerCase()).toContain('ajo');
    expect(findMatchingIconID(garlicES, 'es')).toBe('garlic');

    const frDetail = translateDiscoveredDetail(
      {
        id: '53282',
        name: 'Algerian Carrots',
        category: 'Vegetarian',
        area: 'Algerian',
        instructions: ['Steam carrots.'],
        ingredients: ['4 Carrots', '1 tsp Thyme', '1 Bay Leaf'],
        thumbnailURL: null,
        sourceURL: null,
        youtubeURL: null,
        tags: [],
      },
      'fr'
    );
    expect(frDetail.name).toBe('Carottes algériennes');
    expect(frDetail.ingredients.some((i) => i.includes('thym'))).toBe(true);

    // Excluded meal lookup rejects immediately
    await expect(mealDBClient.lookup('53284', 'en')).rejects.toThrow();
  });

  test('MealDBClient key builders and offline catalog lookup fallback work when network is unavailable', async () => {
    expect(MealDBClient.listKeyRegion('African')).toBe('r:african');
    expect(MealDBClient.listKeySearch('  Jollof ')).toBe('s:jollof');

    // Curated local recipe always resolves offline without hitting fetch
    const fetchSpy = jest.spyOn(globalThis, 'fetch');
    const jollofES = await mealDBClient.lookup('local-jollof-rice', 'es');
    expect(jollofES.ingredients.length).toBeGreaterThan(0);
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
