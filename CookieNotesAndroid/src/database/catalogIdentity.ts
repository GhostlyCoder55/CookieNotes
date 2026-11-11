import {
  getAllLocalMeals,
  getCanonicalIDForSourceURL,
  getLocalMealRecord,
} from '../data/localMealCatalog';
import {
  findUnambiguousTheMealDBID,
  getTheMealDBRecord,
} from '../data/theMealDBCatalog';
import type { Recipe } from '../types/models';
import { normalizeTaxonomyText } from '../utils/cuisineTaxonomy';

interface LegacyCatalogSignature {
  canonicalID: string;
  sourceURL: string;
  englishTitle: string;
  frenchTitle: string;
}

const LEGACY_REMOVED_LOCAL_MDB_SIGNATURES: LegacyCatalogSignature[] = [
  { canonicalID: '52928', sourceURL: 'https://www.tastemade.com/videos/beavertails', englishTitle: 'BeaverTails', frenchTitle: 'Queues de castor (BeaverTails)' },
  { canonicalID: '52965', sourceURL: 'http://www.vodkaandbiscuits.com/2014/03/06/bangin-breakfast-potatoes/', englishTitle: 'Breakfast Potatoes', frenchTitle: "Pommes de terre déjeuner au bacon et sirop d'érable" },
  { canonicalID: '52923', sourceURL: 'https://www.bbcgoodfood.com/recipes/1837/canadian-butter-tarts', englishTitle: 'Canadian Butter Tarts', frenchTitle: 'Tartelettes au beurre canadiennes' },
  { canonicalID: '53343', sourceURL: 'https://canadianfoodfocus.org/recipes/classic-canadian-dish-classic-tourtiere/', englishTitle: 'Classic Tourtière', frenchTitle: 'Tourtière classique québécoise' },
  { canonicalID: '53338', sourceURL: 'https://canadianfoodfocus.org/recipes/classic-canadian-dishes-date-squares/', englishTitle: 'Date squares', frenchTitle: 'Carrés aux dattes' },
  { canonicalID: '53342', sourceURL: 'https://canadianfoodfocus.org/recipes/classic-canadian-dish-figgy-duff/', englishTitle: 'Figgy Duff', frenchTitle: 'Figgy duff de Terre-Neuve' },
  { canonicalID: '52826', sourceURL: 'http://www.telegraph.co.uk/food-and-drink/recipes/braised-beef-chilli-con-carne/', englishTitle: 'Braised Beef Chilli', frenchTitle: 'Chili de bœuf braisé au chorizo' },
  { canonicalID: '52819', sourceURL: 'https://realfood.tesco.com/recipes/cajun-spiced-fish-tacos.html', englishTitle: 'Cajun spiced fish tacos', frenchTitle: 'Tacos de poisson aux épices cajuns' },
  { canonicalID: '52765', sourceURL: 'https://www.themealdb.com/meal/52765', englishTitle: 'Chicken Enchilada Casserole', frenchTitle: "Casserole d'enchiladas au poulet" },
  { canonicalID: '52870', sourceURL: 'https://www.bbcgoodfood.com/recipes/chickpea-fajitas', englishTitle: 'Chickpea Fajitas', frenchTitle: 'Fajitas aux pois chiches' },
  { canonicalID: '52830', sourceURL: 'http://www.nobiggie.net/crock-pot-chicken-baked-tacos/', englishTitle: 'Crock Pot Chicken Baked Tacos', frenchTitle: 'Tacos au poulet à la mijoteuse' },
  { canonicalID: '53067', sourceURL: 'https://www.themealdb.com/meal/53067', englishTitle: 'Stuffed Bell Peppers with Quinoa and Black Beans', frenchTitle: 'Poivrons farcis au quinoa et haricots noirs' },
  { canonicalID: '52940', sourceURL: 'http://www.geniuskitchen.com/recipe/authentic-jamaican-brown-stew-chicken-347996', englishTitle: 'Brown Stew Chicken', frenchTitle: 'Poulet mijoté à la jamaïcaine (brown stew chicken)' },
  { canonicalID: '53361', sourceURL: 'https://www.myforkinglife.com/callaloo-and-saltfish/#recipe', englishTitle: 'Callaloo and SaltFish', frenchTitle: 'Callaloo et morue salée' },
  { canonicalID: '52944', sourceURL: 'https://www.africanbites.com/jamaican-escovitched-fish/', englishTitle: 'Escovitch Fish', frenchTitle: 'Poisson escovitch jamaïcain' },
  { canonicalID: '52939', sourceURL: 'https://www.africanbites.com/callaloo-jamaican-style/', englishTitle: 'Callaloo Jamaican Style', frenchTitle: 'Callaloo à la jamaïcaine' },
  { canonicalID: '53360', sourceURL: 'https://www.myforkinglife.com/tamarind-balls/#recipe', englishTitle: 'Caribbean Tamarind balls', frenchTitle: 'Boules de tamarin antillaises' },
  { canonicalID: '53350', sourceURL: 'https://www.myforkinglife.com/corned-beef-and-cabbage-jamaican-style/#recipe', englishTitle: 'Corned Beef and Cabbage – Jamaican Style', frenchTitle: 'Bœuf salé et chou à la jamaïcaine' },
];

const MEALDB_URL_REGEX = /themealdb\.com\/meal\/(\d+)/i;

function extractMealDBIDFromURL(sourceLowercased: string): string | null {
  const match = MEALDB_URL_REGEX.exec(sourceLowercased);
  return match ? match[1] : null;
}

function isCookieNotesSource(normalizedSource: string): boolean {
  return (
    normalizedSource.includes('epicurious.com') ||
    normalizedSource.includes('cookienotes kitchen') ||
    normalizedSource.includes('cuisine cookienotes') ||
    normalizedSource.includes('cocina de cookienotes')
  );
}

function isMealDBAttributionSource(normalizedSource: string): boolean {
  return (
    normalizedSource.includes('the meal database') ||
    normalizedSource.includes('la base de recettes') ||
    normalizedSource.includes('la base de recetas') ||
    normalizedSource.includes('themealdb.com')
  );
}

function isCatalogAttributionSource(normalizedSource: string): boolean {
  return isCookieNotesSource(normalizedSource) || isMealDBAttributionSource(normalizedSource);
}

export function inferredLegacyCatalogID(
  recipe: Pick<Recipe, 'name' | 'source'>
): string | null {
  const trimmedSource = recipe.source.trim();
  const normalizedSource = trimmedSource.toLowerCase();
  const normalizedName = normalizeTaxonomyText(recipe.name);

  const byURL = getCanonicalIDForSourceURL(trimmedSource);
  if (byURL) return byURL;

  const byMealDBURL = extractMealDBIDFromURL(normalizedSource);
  if (byMealDBURL) return byMealDBURL;

  for (const sig of LEGACY_REMOVED_LOCAL_MDB_SIGNATURES) {
    if (normalizedSource && normalizedSource === sig.sourceURL.toLowerCase()) {
      return sig.canonicalID;
    }
    const matchesTitle =
      normalizedName === normalizeTaxonomyText(sig.englishTitle) ||
      normalizedName === normalizeTaxonomyText(sig.frenchTitle);
    if (matchesTitle && isCatalogAttributionSource(normalizedSource)) {
      return sig.canonicalID;
    }
  }

  if (isCookieNotesSource(normalizedSource)) {
    for (const lang of ['en', 'fr', 'es'] as const) {
      const matches = getAllLocalMeals(lang).filter(
        (m) => normalizeTaxonomyText(m.name) === normalizedName
      );
      if (matches.length === 1) return matches[0].id;
    }
  }

  if (isMealDBAttributionSource(normalizedSource)) {
    const unambiguousID = findUnambiguousTheMealDBID(recipe.name);
    if (unambiguousID) return unambiguousID;
  }

  return null;
}

export function matchesExpectedCatalogShape(
  recipe: Pick<Recipe, 'ingredients'>,
  canonicalID: string
): boolean {
  const localEN = getLocalMealRecord(canonicalID, 'en');
  if (localEN && recipe.ingredients.length === localEN.ingredients.length) {
    return true;
  }
  const mdbFR = getTheMealDBRecord(canonicalID);
  if (mdbFR && recipe.ingredients.length === mdbFR.ingredients.length) {
    return true;
  }
  return false;
}
