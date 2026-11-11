import { RecipeInputLimits } from '../constants/limits';
import { setActiveLanguage } from '../localization/i18n';
import type { GroceryItem, Recipe } from '../types/models';
import {
  nextGrocerySortOrder,
  sanitizeGroceryName,
  sortGroceryItems,
} from '../utils/groceryListLogic';
import { parseRecipeCategory } from '../utils/recipeCategory';
import {
  buildRecipeShareText,
  prepareLibraryRecipes,
  resolveLocalizedIngredients,
  resolveLocalizedInstructions,
  resolveLocalizedRecipeName,
} from '../utils/recipeLibrary';
import {
  cleanInstructions,
  cleanRecipeDraft,
  sanitizeMinutes,
  sanitizeServings,
  sanitizeWebURL,
} from '../utils/recipeSanitizer';
import { parseRecipeText } from '../utils/recipeTextParser';
import { estimateRecipeTime } from '../utils/recipeTimeEstimator';
import { buildSharedRecipeDraft } from '../utils/sharedRecipeBuilder';

function makeRecipe(overrides: Partial<Recipe> = {}): Recipe {
  const now = '2026-10-01T12:00:00.000Z';
  return {
    recipeID: 'r-1',
    name: 'Test Recipe',
    ingredients: ['salt'],
    instructions: ['Cook'],
    notes: '',
    source: '',
    prepTime: 10,
    cookTime: 20,
    servings: 2,
    isSample: false,
    isImported: false,
    isFavorite: false,
    categoryRaw: 'uncategorized',
    ingredientIconIDs: [''],
    coverIconID: '',
    usesCategoryCover: false,
    catalogRecipeID: '',
    isCatalogSynced: false,
    syncedEnglishName: '',
    syncedEnglishIngredients: [],
    syncedEnglishInstructions: [],
    dateCreated: now,
    dateModified: now,
    photos: [],
    ...overrides,
  };
}

describe('Recipe Library, Sanitizer, Text Parser, Grocery List, and Estimator', () => {
  afterEach(() => {
    setActiveLanguage('en');
  });

  test('RecipeSanitizer enforces field length limits, time caps, and clean instruction formatting', () => {
    const cleaned = cleanRecipeDraft({
      name: 'a'.repeat(RecipeInputLimits.name + 50),
      ingredients: ['  salt  ', '', 'pepper\n'],
      instructions: ['\nBake\n'],
      notes: '  note  ',
      source: 'Grandma',
    });

    expect(cleaned.name.length).toBe(RecipeInputLimits.name);
    expect(cleaned.ingredients).toEqual(['salt', 'pepper']);
    expect(cleaned.instructions).toEqual(['Bake']);
    expect(cleaned.notes).toBe('note');
    expect(cleaned.source).toBe('Grandma');
    expect(sanitizeMinutes(-4)).toBe(0);
    expect(sanitizeMinutes(10000)).toBe(RecipeInputLimits.maxMinutes);
    expect(sanitizeServings(200)).toBe(RecipeInputLimits.maxServings);

    expect(sanitizeWebURL('javascript:alert(1)')).toBeNull();
    expect(sanitizeWebURL('https://example.com/recipe')).toBe('https://example.com/recipe');

    const steps = cleanInstructions([
      'STEP 1',
      '0. Marinate the beef.',
      '1. Heat the pan.',
      '1 Put the fennel and aubergine in a roasting tray.',
      'STEP 2: Add broth.',
      'ÉTAPE 3',
      'Étape 4 : Incorporer la sauce.',
      'Préparation :',
      'Paso 5: Servir caliente.',
      '1',
      '2',
      'Steps:',
      '□',
      '☐ Serve with sauce.',
      '7) Let rest before serving.',
    ]);

    expect(steps).toEqual([
      'Marinate the beef.',
      'Heat the pan.',
      'Put the fennel and aubergine in a roasting tray.',
      'Add broth.',
      'Incorporer la sauce.',
      'Servir caliente.',
      'Serve with sauce.',
      'Let rest before serving.',
    ]);
  });

  test('Karbonader placeholder checkbox rows expand into full cooking directions idempotently', () => {
    const name = 'Karbonader (Lean Beef Patties) with Caramelized Onions';
    const raw = [
      'Grate half an onion and set aside. Slice the rest of the onions and fry in butter on low/medium heat until caramelized.',
      '☐',
      'In a bowl, mix together ground beef, grated onion, salt, pepper, nutmeg, potato/corn starch, and water.',
      '□',
      'Form into a sausage and cut 6 patties. Using a knife make a light grid pattern in each patty.',
      '☐',
      'Brown both sides of the karbonader in butter on high heat, then turn down to low heat and fry for another 2-3 minutes.',
      '☐',
      'Serve the karbonader and onions with potatoes, stewed peas, and brown sauce for dinner.',
    ];

    const cleaned = cleanInstructions(raw, name);
    expect(cleaned.length).toBe(9);
    expect(cleaned[1]).toContain('Transfer the caramelized onions');
    expect(cleaned[3]).toContain('Mix gently');
    expect(cleaned[5]).toContain('even thickness');
    expect(cleaned[7]).toContain('160°F');
    expect(cleanInstructions(cleaned, name)).toEqual(cleaned);
  });

  test('RecipeTextParser parses English, French, and Spanish structured shared recipes', () => {
    const enParsed = parseRecipeText(`
      Sunday Stew

      Ingredients
      - beef
      • carrots

      Directions
      1. Brown the beef
      2) Add the carrots

      Notes
      Better the next day
    `);
    expect(enParsed.name).toBe('Sunday Stew');
    expect(enParsed.ingredients).toEqual(['beef', 'carrots']);
    expect(enParsed.instructions).toEqual(['Brown the beef', 'Add the carrots']);
    expect(enParsed.notes).toBe('Better the next day');
    expect(enParsed.hasStructuredContent).toBe(true);

    const frParsed = parseRecipeText(`
      Soupe du dimanche

      Ingrédients :
      - 2 carottes
      • 1 oignon

      Préparation :
      1. Couper les légumes.
      2) Faire mijoter 20 minutes.

      Astuces :
      Encore meilleur le lendemain.
    `);
    expect(frParsed.name).toBe('Soupe du dimanche');
    expect(frParsed.ingredients).toEqual(['2 carottes', '1 oignon']);
    expect(frParsed.instructions).toEqual(['Couper les légumes.', 'Faire mijoter 20 minutes.']);
    expect(frParsed.notes).toBe('Encore meilleur le lendemain.');

    const esParsed = parseRecipeText(`
      Sopa casera

      Ingredientes:
      - 2 tomates

      Instrucciones:
      1. Cocinar a fuego lento.
    `);
    expect(esParsed.name).toBe('Sopa casera');
    expect(esParsed.ingredients).toEqual(['2 tomates']);
    expect(esParsed.instructions).toEqual(['Cocinar a fuego lento.']);
  });

  test('buildSharedRecipeDraft uses host fallback, localizes fallback text, and rejects unsafe links', () => {
    const webOnly = buildSharedRecipeDraft(
      {
        title: '',
        text: 'https://example.com/stew',
        url: 'https://example.com/stew',
      },
      'en'
    );
    expect(webOnly.name).toBe('example.com');
    expect(webOnly.source).toBe('https://example.com/stew');
    expect(webOnly.notes).toContain('Saved from the web');

    const unsafe = buildSharedRecipeDraft(
      {
        title: 'Card',
        text: '',
        url: 'javascript:alert(1)',
      },
      'en'
    );
    expect(unsafe.name).toBe('Card');
    expect(unsafe.source).toBe('');

    const frUntitled = buildSharedRecipeDraft({ title: '', text: '', url: '' }, 'fr');
    expect(frUntitled.name).toBe('Recette enregistrée');

    const esUntitled = buildSharedRecipeDraft({ title: '', text: '', url: '' }, 'es');
    expect(esUntitled.name).toBe('Receta guardada');
  });

  test('RecipeLibrary search, filter, sort, legacy category fallback, and in-place catalog sync', () => {
    const soup = makeRecipe({
      recipeID: 'soup',
      name: 'Tomato Soup',
      ingredients: ['tomatoes', 'basil'],
      instructions: ['Simmer until sweet'],
      notes: 'Freeze the extra',
      source: 'family card',
      categoryRaw: 'lunch',
      dateCreated: '2026-10-02T12:00:00.000Z',
    });
    const cake = makeRecipe({
      recipeID: 'cake',
      name: 'Banana Cake',
      ingredients: ['bananas', 'flour'],
      instructions: ['Bake'],
      categoryRaw: 'dessert',
      isFavorite: true,
      dateCreated: '2026-10-01T12:00:00.000Z',
    });
    const sample = makeRecipe({ recipeID: 'sample', name: 'Sample', isSample: true });

    expect(prepareLibraryRecipes([soup, cake, sample], { query: 'freeze' }).map((r) => r.name)).toEqual([
      'Tomato Soup',
    ]);
    expect(prepareLibraryRecipes([soup, cake, sample], { query: 'SIMMER' }).map((r) => r.name)).toEqual([
      'Tomato Soup',
    ]);
    expect(prepareLibraryRecipes([soup, cake, sample], { filter: 'favorites' }).map((r) => r.name)).toEqual([
      'Banana Cake',
    ]);
    expect(prepareLibraryRecipes([soup, cake, sample], { sort: 'name' }).map((r) => r.name)).toEqual([
      'Banana Cake',
      'Tomato Soup',
    ]);
    expect(prepareLibraryRecipes([soup, cake, sample], { sort: 'newest' }).map((r) => r.name)).toEqual([
      'Tomato Soup',
      'Banana Cake',
    ]);

    expect(parseRecipeCategory('sides')).toBe('uncategorized');
    expect(parseRecipeCategory('snack')).toBe('uncategorized');

    // Synced local catalog recipe resolves in place across EN / FR / ES without duplicating DB rows
    const jollof = makeRecipe({
      recipeID: 'jollof',
      name: 'Jollof Rice',
      catalogRecipeID: 'local-jollof-rice',
      isCatalogSynced: true,
      isImported: true,
      prepTime: 25,
      cookTime: 45,
      servings: 6,
    });
    expect(resolveLocalizedRecipeName(jollof, 'en')).toBe('Jollof Rice');
    expect(resolveLocalizedRecipeName(jollof, 'fr')).toBe('Riz jollof');
    expect(resolveLocalizedIngredients(jollof, 'fr').some((l) => l.toLowerCase().includes('riz'))).toBe(true);
    expect(resolveLocalizedInstructions(jollof, 'es').length).toBeGreaterThan(0);

    const shared = buildRecipeShareText(jollof, 'fr');
    expect(shared).toContain('Riz jollof');
    expect(shared).toContain('Ingrédients');
  });

  test('GroceryListLogic sanitizes names, sorts across 3 modes, and increments sortOrder', () => {
    expect(sanitizeGroceryName('  \n Oat milk \r\n ')).toBe('Oat milk');
    expect(sanitizeGroceryName('Greek\nyogurt')).toBe('Greek yogurt');
    expect(sanitizeGroceryName('   \n\t  ')).toBe('');
    expect(sanitizeGroceryName('x'.repeat(RecipeInputLimits.name + 30)).length).toBe(
      RecipeInputLimits.name
    );

    const items: GroceryItem[] = [
      { itemID: '1', name: 'Zucchini', isChecked: true, sortOrder: 0, dateCreated: '2026-10-01T00:00:00Z', dateModified: '2026-10-01T00:00:00Z' },
      { itemID: '2', name: 'Apples', isChecked: false, sortOrder: 1, dateCreated: '2026-10-01T00:01:00Z', dateModified: '2026-10-01T00:01:00Z' },
      { itemID: '3', name: 'Milk', isChecked: true, sortOrder: 4, dateCreated: '2026-10-01T00:02:00Z', dateModified: '2026-10-01T00:02:00Z' },
      { itemID: '4', name: 'Bread', isChecked: false, sortOrder: 2, dateCreated: '2026-10-01T00:03:00Z', dateModified: '2026-10-01T00:03:00Z' },
    ];

    expect(sortGroceryItems(items, 'default').map((i) => i.name)).toEqual([
      'Zucchini',
      'Apples',
      'Bread',
      'Milk',
    ]);
    expect(sortGroceryItems(items, 'uncheckedFirst').map((i) => i.name)).toEqual([
      'Apples',
      'Bread',
      'Zucchini',
      'Milk',
    ]);
    expect(sortGroceryItems(items, 'alphabetical').map((i) => i.name)).toEqual([
      'Apples',
      'Bread',
      'Milk',
      'Zucchini',
    ]);
    expect(nextGrocerySortOrder([])).toBe(0);
    expect(nextGrocerySortOrder(items)).toBe(5);
  });

  test('RecipeTimeEstimator estimates English, French, and Spanish durations', () => {
    const frEstimate = estimateRecipeTime(
      [
        'Laisser mariner toute la nuit au réfrigérateur.',
        'Faire cuire au four pendant 1 heure et 15 minutes jusqu’à coloration dorée.',
      ],
      6,
      'Beef'
    );
    expect(frEstimate.prep).toBeGreaterThanOrEqual(8 * 60);
    expect(frEstimate.cook).toBeGreaterThanOrEqual(75);

    const esEstimate = estimateRecipeTime(
      ['Hervir a fuego lento durante 25 minutos.'],
      4,
      'Chicken'
    );
    expect(esEstimate.cook).toBe(25);
  });
});
