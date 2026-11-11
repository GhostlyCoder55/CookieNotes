import { getLocalMealDetail, getLocalMealRecord } from '../data/localMealCatalog';
import { getTheMealDBRecord, getTranslatedFrenchName } from '../data/theMealDBCatalog';
import { getActiveLanguage, type AppLanguage } from '../localization/i18n';
import type { DiscoveredRecipeDetail, DiscoveredRecipeSummary } from '../types/models';
import { canonicalRecipeID } from './mealIdentity';
import { cleanInstructions } from './recipeSanitizer';

interface UnitRule {
  pattern: string;
  replacement: string;
  needsConnector: boolean;
}

type PatternPair = [pattern: RegExp, replacement: string];

// MARK: - French Rules (1:1 port of iOS RecipeTranslator.swift)

const FRENCH_UNIT_MAP: UnitRule[] = [
  { pattern: '\\b(?:teaspoons?|tsp\\.?|t\\.)\\b', replacement: 'c. à thé', needsConnector: true },
  { pattern: '\\b(?:tablespoons?|tbsp\\.?|tbs\\.?|tbsps?)\\b', replacement: 'c. à soupe', needsConnector: true },
  { pattern: '\\bcups?\\b', replacement: 'tasse', needsConnector: true },
  { pattern: '\\b(?:pounds?|lbs?\\.?)\\b', replacement: 'lb', needsConnector: true },
  { pattern: '\\b(?:ounces?|oz\\.?)\\b', replacement: 'oz', needsConnector: true },
  { pattern: '\\b(?:grams?|g\\.?)\\b', replacement: 'g', needsConnector: true },
  { pattern: '\\b(?:kilograms?|kg\\.?)\\b', replacement: 'kg', needsConnector: true },
  { pattern: '\\b(?:milliliters?|ml\\.?)\\b', replacement: 'ml', needsConnector: true },
  { pattern: '\\b(?:liters?|litres?|l\\.?)\\b', replacement: 'L', needsConnector: true },
  { pattern: '\\bcloves?\\b', replacement: 'gousse', needsConnector: true },
  { pattern: '\\bslices?\\b', replacement: 'tranche', needsConnector: true },
  { pattern: '\\bpinches?\\b', replacement: 'pincée', needsConnector: true },
  { pattern: '\\bdashes?\\b', replacement: 'filet', needsConnector: true },
  { pattern: '\\bcans?\\b', replacement: 'boîte', needsConnector: true },
  { pattern: '\\b(?:packages?|pkgs?\\.?)\\b', replacement: 'paquet', needsConnector: true },
  { pattern: '\\bsprigs?\\b', replacement: 'brin', needsConnector: true },
  { pattern: '\\bbunches?\\b', replacement: 'botte', needsConnector: true },
  { pattern: '\\bstalks?\\b', replacement: 'branche', needsConnector: true },
  { pattern: '\\bheads?\\b', replacement: 'tête', needsConnector: true },
  { pattern: '\\bpieces?\\b', replacement: 'morceau', needsConnector: true },
];

const FRENCH_PREP_MAP: PatternPair[] = [
  [/\bfinely chopped\b/gi, 'finement haché'],
  [/\bcoarsely chopped\b/gi, 'grossièrement haché'],
  [/\bchopped\b/gi, 'haché'],
  [/\bdiced\b/gi, 'en dés'],
  [/\bminced\b/gi, 'émincé'],
  [/\bthinly sliced\b/gi, 'finement tranché'],
  [/\bsliced\b/gi, 'en tranches'],
  [/\bcrushed\b/gi, 'écrasé'],
  [/\bfinely grated\b/gi, 'finement râpé'],
  [/\bgrated\b/gi, 'râpé'],
  [/\bshredded\b/gi, 'râpé'],
  [/\bmelted\b/gi, 'fondu'],
  [/\bsoftened\b/gi, 'ramolli'],
  [/\bground\b/gi, 'moulu'],
  [/\bfreshly ground\b/gi, 'fraîchement moulu'],
  [/\bfresh\b/gi, 'frais'],
  [/\bdried\b/gi, 'séché'],
  [/\bcooked\b/gi, 'cuit'],
  [/\braw\b/gi, 'cru'],
  [/\bfrozen\b/gi, 'surgelé'],
  [/\bthawed\b/gi, 'décongelé'],
  [/\bboneless\b/gi, 'désossé'],
  [/\bskinless\b/gi, 'sans peau'],
  [/\bpeeled\b/gi, 'pelé'],
  [/\bseeded\b/gi, 'épépiné'],
  [/\bto taste\b/gi, 'au goût'],
  [/\bfor serving\b/gi, 'pour servir'],
  [/\bfor garnish\b/gi, 'pour garnir'],
  [/\bfor frying\b/gi, 'pour la friture'],
  [/\bdivided\b/gi, 'divisé'],
  [/\boptional\b/gi, 'facultatif'],
  [/\bplus more\b/gi, 'et plus'],
  [/\bas needed\b/gi, 'au besoin'],
];

const FRENCH_INGREDIENT_GLOSSARY: PatternPair[] = [
  [/\bwater\b/gi, 'eau'],
  [/\bcarrots?\b/gi, 'carottes'],
  [/\bthyme\b/gi, 'thym'],
  [/\bbay leaves?\b/gi, 'feuilles de laurier'],
  [/\bbay leaf\b/gi, 'feuille de laurier'],
  [/\blemon juice\b/gi, 'jus de citron'],
  [/\blime juice\b/gi, 'jus de lime'],
  [/\blemon zest\b/gi, 'zeste de citron'],
  [/\blime zest\b/gi, 'zeste de lime'],
  [/\borange juice\b/gi, "jus d'orange"],
  [/\blemons?\b/gi, 'citron'],
  [/\blimes?\b/gi, 'lime'],
  [/\bcrushed garlic\b/gi, 'ail écrasé'],
  [/\bminced garlic\b/gi, 'ail haché'],
  [/\bchopped garlic\b/gi, 'ail émincé'],
  [/\bgarlic cloves?\b/gi, "gousses d'ail"],
  [/\bgarlic\b/gi, 'ail'],
  [/\byellow onions?\b/gi, 'oignon jaune'],
  [/\bred onions?\b/gi, 'oignon rouge'],
  [/\bwhite onions?\b/gi, 'oignon blanc'],
  [/\bgreen onions?\b/gi, 'oignons verts'],
  [/\bspring onions?\b/gi, 'oignons verts'],
  [/\bscallions?\b/gi, 'échalotes vertes'],
  [/\bshallots?\b/gi, 'échalotes'],
  [/\bonions?\b/gi, 'oignon'],
  [/\bginger\b/gi, 'gingembre'],
  [/\bpotatoes?\b/gi, 'pommes de terre'],
  [/\bsweet potatoes?\b/gi, 'patates douces'],
  [/\btomatoes?\b/gi, 'tomates'],
  [/\bcherry tomatoes?\b/gi, 'tomates cerises'],
  [/\btomato paste\b/gi, 'pâte de tomate'],
  [/\btomato sauce\b/gi, 'sauce tomate'],
  [/\bcanned tomatoes?\b/gi, 'tomates en boîte'],
  [/\bcrushed tomatoes?\b/gi, 'tomates broyées'],
  [/\bdiced tomatoes?\b/gi, 'tomates en dés'],
  [/\bcelery\b/gi, 'céleri'],
  [/\bcucumbers?\b/gi, 'concombre'],
  [/\bzucchinis?\b/gi, 'courgette'],
  [/\bcourgettes?\b/gi, 'courgette'],
  [/\bavocados?\b/gi, 'avocat'],
  [/\bspinach\b/gi, 'épinards'],
  [/\blettuce\b/gi, 'laitue'],
  [/\bkale\b/gi, 'chou frisé'],
  [/\bcabbage\b/gi, 'chou'],
  [/\bcauliflower\b/gi, 'chou-fleur'],
  [/\bbroccoli\b/gi, 'brocoli'],
  [/\bmushrooms?\b/gi, 'champignons'],
  [/\bpeppers?\b/gi, 'poivrons'],
  [/\bbell peppers?\b/gi, 'poivrons'],
  [/\bred bell peppers?\b/gi, 'poivron rouge'],
  [/\bgreen bell peppers?\b/gi, 'poivron vert'],
  [/\byellow bell peppers?\b/gi, 'poivron jaune'],
  [/\bjalape[nñ]os?\b/gi, 'jalapeño'],
  [/\bchili peppers?\b/gi, 'piments'],
  [/\bchili\b/gi, 'piment'],
  [/\bpeas?\b/gi, 'pois'],
  [/\bgreen peas?\b/gi, 'petits pois'],
  [/\bcorn\b/gi, 'maïs'],
  [/\bgreen beans?\b/gi, 'haricots verts'],
  [/\basparagus\b/gi, 'asperges'],
  [/\beggplants?\b/gi, 'aubergine'],
  [/\baubergines?\b/gi, 'aubergine'],
  [/\bparsley\b/gi, 'persil'],
  [/\bcilantro\b/gi, 'coriandre'],
  [/\bcoriander\b/gi, 'coriandre'],
  [/\bbasil\b/gi, 'basilic'],
  [/\brosemary\b/gi, 'romarin'],
  [/\boregano\b/gi, 'origan'],
  [/\bmint\b/gi, 'menthe'],
  [/\bdill\b/gi, 'aneth'],
  [/\btarragon\b/gi, 'estragon'],
  [/\bchives\b/gi, 'ciboulette'],
  [/\bsage\b/gi, 'sauge'],
  [/\bblack pepper\b/gi, 'poivre noir'],
  [/\bwhite pepper\b/gi, 'poivre blanc'],
  [/\bcayenne pepper\b/gi, 'poivre de Cayenne'],
  [/\bred pepper flakes\b/gi, 'flocons de piment fort'],
  [/\bchili powder\b/gi, 'poudre de chili'],
  [/\bcurry powder\b/gi, 'poudre de cari'],
  [/\bground cinnamon\b/gi, 'cannelle moulue'],
  [/\bcinnamon stick\b/gi, 'bâton de cannelle'],
  [/\bcinnamon\b/gi, 'cannelle'],
  [/\bground cumin\b/gi, 'cumin moulu'],
  [/\bcumin seeds?\b/gi, 'graines de cumin'],
  [/\bcumin\b/gi, 'cumin'],
  [/\bpaprika\b/gi, 'paprika'],
  [/\bsmoked paprika\b/gi, 'paprika fumé'],
  [/\bturmeric\b/gi, 'curcuma'],
  [/\bground nutmeg\b/gi, 'muscade moulue'],
  [/\bnutmeg\b/gi, 'muscade'],
  [/\bground cloves?\b/gi, 'clou de girofle moulu'],
  [/\bwhole cloves?\b/gi, 'clous de girofle entiers'],
  [/\bcardamom\b/gi, 'cardamome'],
  [/\bcoriander seeds?\b/gi, 'graines de coriandre'],
  [/\bfennel seeds?\b/gi, 'graines de fenouil'],
  [/\bsalt and black pepper\b/gi, 'sel et poivre noir'],
  [/\bsalt and pepper\b/gi, 'sel et poivre'],
  [/\bsea salt\b/gi, 'sel de mer'],
  [/\bkosher salt\b/gi, 'sel casher'],
  [/\bsalt\b/gi, 'sel'],
  [/\bextra virgin olive oil\b/gi, "huile d'olive extra-vierge"],
  [/\bolive oil\b/gi, "huile d'olive"],
  [/\bvegetable oil\b/gi, 'huile végétale'],
  [/\bcanola oil\b/gi, 'huile de canola'],
  [/\bsesame oil\b/gi, 'huile de sésame'],
  [/\bcooking oil\b/gi, 'huile de cuisson'],
  [/\bsoy sauce\b/gi, 'sauce soja'],
  [/\bdark soy sauce\b/gi, 'sauce soja foncée'],
  [/\blight soy sauce\b/gi, 'sauce soja claire'],
  [/\bfish sauce\b/gi, 'sauce de poisson'],
  [/\boyster sauce\b/gi, 'sauce aux huîtres'],
  [/\bworcestershire sauce\b/gi, 'sauce Worcestershire'],
  [/\bhot sauce\b/gi, 'sauce piquante'],
  [/\bdijon mustard\b/gi, 'moutarde de Dijon'],
  [/\bmustard\b/gi, 'moutarde'],
  [/\bmayonnaise\b/gi, 'mayonnaise'],
  [/\bketchup\b/gi, 'ketchup'],
  [/\bvinegar\b/gi, 'vinaigre'],
  [/\bapple cider vinegar\b/gi, 'vinaigre de cidre de pomme'],
  [/\bred wine vinegar\b/gi, 'vinaigre de vin rouge'],
  [/\bwhite wine vinegar\b/gi, 'vinaigre de vin blanc'],
  [/\brice vinegar\b/gi, 'vinaigre de riz'],
  [/\bbalsamic vinegar\b/gi, 'vinaigre balsamique'],
  [/\bhoney\b/gi, 'miel'],
  [/\bmaple syrup\b/gi, "sirop d'érable"],
  [/\bunsalted butter\b/gi, 'beurre non salé'],
  [/\bsalted butter\b/gi, 'beurre salé'],
  [/\bbutter\b/gi, 'beurre'],
  [/\beggs?\b/gi, 'œufs'],
  [/\begg yolks?\b/gi, "jaunes d'œufs"],
  [/\begg whites?\b/gi, "blancs d'œufs"],
  [/\bmilk\b/gi, 'lait'],
  [/\bwhole milk\b/gi, 'lait entier'],
  [/\bheavy cream\b/gi, 'crème épaisse'],
  [/\bwhipping cream\b/gi, 'crème à fouetter'],
  [/\bsour cream\b/gi, 'crème sure'],
  [/\byogurt\b/gi, 'yogourt'],
  [/\bgreek yogurt\b/gi, 'yogourt grec'],
  [/\bparmesan cheese\b/gi, 'parmesan'],
  [/\bparmesan\b/gi, 'parmesan'],
  [/\bcheddar cheese\b/gi, 'fromage cheddar'],
  [/\bcheddar\b/gi, 'cheddar'],
  [/\bmozzarella cheese\b/gi, 'mozzarella'],
  [/\bmozzarella\b/gi, 'mozzarella'],
  [/\bcream cheese\b/gi, 'fromage à la crème'],
  [/\bfeta cheese\b/gi, 'fromage feta'],
  [/\bfeta\b/gi, 'feta'],
  [/\bricotta\b/gi, 'ricotta'],
  [/\bchicken breasts?\b/gi, 'poitrines de poulet'],
  [/\bchicken thighs?\b/gi, 'hauts de cuisse de poulet'],
  [/\bchicken legs?\b/gi, 'cuisses de poulet'],
  [/\bchicken wings?\b/gi, 'ailes de poulet'],
  [/\bchicken broth\b/gi, 'bouillon de poulet'],
  [/\bchicken stock\b/gi, 'fond de poulet'],
  [/\bwhole chicken\b/gi, 'poulet entier'],
  [/\bchicken\b/gi, 'poulet'],
  [/\bground beef\b/gi, 'bœuf haché'],
  [/\bbeef broth\b/gi, 'bouillon de bœuf'],
  [/\bbeef stock\b/gi, 'fond de bœuf'],
  [/\bbeef\b/gi, 'bœuf'],
  [/\bsteak\b/gi, 'steak'],
  [/\bpork chops?\b/gi, 'côtelettes de porc'],
  [/\bground pork\b/gi, 'porc haché'],
  [/\bpork\b/gi, 'porc'],
  [/\bbacon\b/gi, 'bacon'],
  [/\bham\b/gi, 'jambon'],
  [/\bsausages?\b/gi, 'saucisses'],
  [/\blamb\b/gi, 'agneau'],
  [/\bturkey\b/gi, 'dinde'],
  [/\bground turkey\b/gi, 'dinde hachée'],
  [/\bshrimps?\b/gi, 'crevettes'],
  [/\bprawns?\b/gi, 'grosses crevettes'],
  [/\bsalmon\b/gi, 'saumon'],
  [/\btuna\b/gi, 'thon'],
  [/\bcod\b/gi, 'morue'],
  [/\bwhite fish\b/gi, 'poisson blanc'],
  [/\bfish fillets?\b/gi, 'filets de poisson'],
  [/\ball-purpose flour\b/gi, 'farine tout usage'],
  [/\bflour\b/gi, 'farine'],
  [/\bbread crumbs?\b/gi, 'chapelure'],
  [/\bpanko bread crumbs?\b/gi, 'chapelure panko'],
  [/\bpanko\b/gi, 'panko'],
  [/\bgranulated sugar\b/gi, 'sucre granulé'],
  [/\bbrown sugar\b/gi, 'cassonade'],
  [/\bpowdered sugar\b/gi, 'sucre à glacer'],
  [/\bicing sugar\b/gi, 'sucre à glacer'],
  [/\bsugar\b/gi, 'sucre'],
  [/\bbaking powder\b/gi, 'poudre à pâte'],
  [/\bbaking soda\b/gi, 'bicarbonate de soude'],
  [/\bactive dry yeast\b/gi, 'levure sèche active'],
  [/\byeast\b/gi, 'levure'],
  [/\bvanilla extract\b/gi, 'extrait de vanille'],
  [/\bvanilla\b/gi, 'vanille'],
  [/\bcocoa powder\b/gi, 'poudre de cacao'],
  [/\bchocolate chips?\b/gi, 'pépites de chocolat'],
  [/\bdark chocolate\b/gi, 'chocolat noir'],
  [/\bchocolate\b/gi, 'chocolat'],
  [/\bcornstarch\b/gi, 'fécule de maïs'],
  [/\bwhite rice\b/gi, 'riz blanc'],
  [/\bbrown rice\b/gi, 'riz brun'],
  [/\bjasmine rice\b/gi, 'riz jasmin'],
  [/\bbasmati rice\b/gi, 'riz basmati'],
  [/\brice\b/gi, 'riz'],
  [/\bpasta\b/gi, 'pâtes'],
  [/\bspaghetti\b/gi, 'spaghetti'],
  [/\bnoodles?\b/gi, 'nouilles'],
  [/\brolled oats\b/gi, "flocons d'avoine"],
  [/\boats\b/gi, 'avoine'],
  [/\bvegetable broth\b/gi, 'bouillon de légumes'],
  [/\bvegetable stock\b/gi, 'fond de légumes'],
  [/\bcoconut milk\b/gi, 'lait de coco'],
  [/\bcoconut cream\b/gi, 'crème de coco'],
  [/\bchickpeas?\b/gi, 'pois chiches'],
  [/\bblack beans?\b/gi, 'haricots noirs'],
  [/\bkidney beans?\b/gi, 'haricots rouges'],
  [/\blentils?\b/gi, 'lentilles'],
  [/\bpeanuts?\b/gi, 'arachides'],
  [/\balmonds?\b/gi, 'amandes'],
  [/\bwalnuts?\b/gi, 'noix'],
  [/\bcashews?\b/gi, 'noix de cajou'],
  [/\bpeanut butter\b/gi, "beurre d'arachide"],
];

const FRENCH_INSTRUCTION_GLOSSARY: PatternPair[] = [
  [/\bplace a steamer insert into a saucepan\b/gi, 'Placer un panier vapeur dans une casserole'],
  [/\bbring the water to a boil over high heat\b/gi, "porter l'eau à ébullition à feu vif"],
  [/\bbring to a boil over high heat\b/gi, 'porter à ébullition à feu vif'],
  [/\bbring to a boil\b/gi, 'porter à ébullition'],
  [/\bbring to a simmer\b/gi, 'amener à frémissement'],
  [/\breduce the heat to medium\b/gi, 'réduire le feu à moyen'],
  [/\breduce heat to medium\b/gi, 'réduire le feu à moyen'],
  [/\breduce the heat to low\b/gi, 'réduire le feu à doux'],
  [/\breduce heat to low\b/gi, 'réduire le feu à doux'],
  [/\breduce the heat\b/gi, 'réduire le feu'],
  [/\breduce heat\b/gi, 'réduire le feu'],
  [/\bheat the olive oil in a skillet over medium heat\b/gi, "Faire chauffer l'huile d'olive dans une poêle à feu moyen"],
  [/\bheat the oil in a large skillet\b/gi, "Faire chauffer l'huile dans une grande poêle"],
  [/\bheat the oil in a skillet\b/gi, "Faire chauffer l'huile dans une poêle"],
  [/\bheat olive oil in a\b/gi, "faire chauffer l'huile d'olive dans"],
  [/\bheat the oil\b/gi, "faire chauffer l'huile"],
  [/\bpreheat oven to (\d+) degrees\b/gi, 'Préchauffer le four à $1 degrés'],
  [/\bpreheat the oven to\b/gi, 'Préchauffer le four à'],
  [/\bsteam until tender but not mushy\b/gi, "Cuire à la vapeur jusqu'à tendreté mais sans écraser"],
  [/\bsteam until tender\b/gi, "Cuire à la vapeur jusqu'à ce que ce soit tendre"],
  [/\bcover and simmer for (\d+) minutes\b/gi, 'couvrir et laisser mijoter pendant $1 minutes'],
  [/\bcover and simmer\b/gi, 'couvrir et laisser mijoter'],
  [/\bsimmer for (\d+) minutes\b/gi, 'laisser mijoter pendant $1 minutes'],
  [/\buntil fragrant, about (\d+) minutes\b/gi, "jusqu'à ce que ce soit parfumé, environ $1 minutes"],
  [/\buntil fragrant\b/gi, "jusqu'à ce que ce soit parfumé"],
  [/\buntil golden brown\b/gi, "jusqu'à coloration dorée"],
  [/\buntil tender\b/gi, "jusqu'à tendreté"],
  [/\bstirring frequently\b/gi, 'en remuant fréquemment'],
  [/\bstirring occasionally\b/gi, 'en remuant de temps en temps'],
  [/\bstir in the\b/gi, 'incorporer le'],
  [/\bseason with salt and pepper\b/gi, 'assaisonner de sel et de poivre'],
  [/\bseason to taste\b/gi, 'assaisonner au goût'],
  [/\bremove from heat\b/gi, 'retirer du feu'],
  [/\bset aside\b/gi, 'réserver'],
  [/\bbefore serving\b/gi, 'avant de servir'],
  [/\bserve immediately\b/gi, 'servir immédiatement'],
  [/\bserve hot\b/gi, 'servir chaud'],
  [/\bserve warm\b/gi, 'servir tiède'],
  [/\bgarnish with\b/gi, 'garnir de'],
  [/\bsprinkle with lemon juice\b/gi, 'arroser de jus de citron'],
  [/\bsprinkle with\b/gi, 'saupoudrer de'],
  [/\bremove the bay leaf\b/gi, 'retirer la feuille de laurier'],
  [/\bdrain and rinse\b/gi, 'égoutter et rincer'],
  [/\bin a large bowl\b/gi, 'dans un grand bol'],
  [/\bin a medium bowl\b/gi, 'dans un bol moyen'],
  [/\bin a small bowl\b/gi, 'dans un petit bol'],
  [/\bin a saucepan\b/gi, 'dans une casserole'],
  [/\bin a skillet\b/gi, 'dans une poêle'],
  [/\bin a baking dish\b/gi, 'dans un plat de cuisson'],
  [/\bwhisk together\b/gi, 'fouetter ensemble'],
  [/\bmix well\b/gi, 'bien mélanger'],
  [/\btoss to coat\b/gi, 'remuer pour bien enrober'],
  [/\btossing well to coat\b/gi, 'en remuant bien pour enrober'],
];

const FRENCH_MARKERS = [
  'c. à thé',
  'c. à soupe',
  'tasse',
  'gousse',
  'pincée',
  'tranche',
  'botte',
  'boîte',
  "d'ail",
  "d'huile",
  "huile d'",
  'huile de ',
  'de sel',
  'poudre de ',
  'jus de ',
  'bouillon de ',
];

// MARK: - Spanish Rules (Complete parallel translation engine for Spanish)

const SPANISH_UNIT_MAP: UnitRule[] = [
  { pattern: '\\b(?:teaspoons?|tsp\\.?|t\\.)\\b', replacement: 'cucharadita', needsConnector: true },
  { pattern: '\\b(?:tablespoons?|tbsp\\.?|tbs\\.?|tbsps?)\\b', replacement: 'cucharada', needsConnector: true },
  { pattern: '\\bcups?\\b', replacement: 'taza', needsConnector: true },
  { pattern: '\\b(?:pounds?|lbs?\\.?)\\b', replacement: 'libra', needsConnector: true },
  { pattern: '\\b(?:ounces?|oz\\.?)\\b', replacement: 'oz', needsConnector: true },
  { pattern: '\\b(?:grams?|g\\.?)\\b', replacement: 'g', needsConnector: true },
  { pattern: '\\b(?:kilograms?|kg\\.?)\\b', replacement: 'kg', needsConnector: true },
  { pattern: '\\b(?:milliliters?|ml\\.?)\\b', replacement: 'ml', needsConnector: true },
  { pattern: '\\b(?:liters?|litres?|l\\.?)\\b', replacement: 'L', needsConnector: true },
  { pattern: '\\bcloves?\\b', replacement: 'diente', needsConnector: true },
  { pattern: '\\bslices?\\b', replacement: 'rebanada', needsConnector: true },
  { pattern: '\\bpinches?\\b', replacement: 'pizca', needsConnector: true },
  { pattern: '\\bdashes?\\b', replacement: 'chorrito', needsConnector: true },
  { pattern: '\\bcans?\\b', replacement: 'lata', needsConnector: true },
  { pattern: '\\b(?:packages?|pkgs?\\.?)\\b', replacement: 'paquete', needsConnector: true },
  { pattern: '\\bsprigs?\\b', replacement: 'ramita', needsConnector: true },
  { pattern: '\\bbunches?\\b', replacement: 'manojo', needsConnector: true },
  { pattern: '\\bstalks?\\b', replacement: 'tallo', needsConnector: true },
  { pattern: '\\bheads?\\b', replacement: 'cabeza', needsConnector: true },
  { pattern: '\\bpieces?\\b', replacement: 'trozo', needsConnector: true },
];

const SPANISH_PLURALS: Record<string, string> = {
  cucharadita: 'cucharaditas',
  cucharada: 'cucharadas',
  taza: 'tazas',
  libra: 'libras',
  diente: 'dientes',
  rebanada: 'rebanadas',
  pizca: 'pizcas',
  chorrito: 'chorritos',
  lata: 'latas',
  paquete: 'paquetes',
  ramita: 'ramitas',
  manojo: 'manojos',
  tallo: 'tallos',
  cabeza: 'cabezas',
  trozo: 'trozos',
};

const SPANISH_PREP_MAP: PatternPair[] = [
  [/\bfinely chopped\b/gi, 'finamente picado'],
  [/\bcoarsely chopped\b/gi, 'picado grueso'],
  [/\bchopped\b/gi, 'picado'],
  [/\bdiced\b/gi, 'en cubos'],
  [/\bminced\b/gi, 'picado fino'],
  [/\bthinly sliced\b/gi, 'en rodajas finas'],
  [/\bsliced\b/gi, 'en rodajas'],
  [/\bcrushed\b/gi, 'triturado'],
  [/\bfinely grated\b/gi, 'finamente rallado'],
  [/\bgrated\b/gi, 'rallado'],
  [/\bshredded\b/gi, 'desmenuzado'],
  [/\bmelted\b/gi, 'derretido'],
  [/\bsoftened\b/gi, 'ablandado'],
  [/\bfreshly ground\b/gi, 'recién molido'],
  [/\bground\b/gi, 'molido'],
  [/\bfresh\b/gi, 'fresco'],
  [/\bdried\b/gi, 'seco'],
  [/\bcooked\b/gi, 'cocido'],
  [/\braw\b/gi, 'crudo'],
  [/\bfrozen\b/gi, 'congelado'],
  [/\bthawed\b/gi, 'descongelado'],
  [/\bboneless\b/gi, 'sin hueso'],
  [/\bskinless\b/gi, 'sin piel'],
  [/\bpeeled\b/gi, 'pelado'],
  [/\bseeded\b/gi, 'sin semillas'],
  [/\bto taste\b/gi, 'al gusto'],
  [/\bfor serving\b/gi, 'para servir'],
  [/\bfor garnish\b/gi, 'para decorar'],
  [/\bfor frying\b/gi, 'para freír'],
  [/\bdivided\b/gi, 'dividido'],
  [/\boptional\b/gi, 'opcional'],
  [/\bplus more\b/gi, 'y un poco más'],
  [/\bas needed\b/gi, 'según sea necesario'],
];

const SPANISH_INGREDIENT_GLOSSARY: PatternPair[] = [
  [/\bwater\b/gi, 'agua'],
  [/\bcarrots?\b/gi, 'zanahorias'],
  [/\bthyme\b/gi, 'tomillo'],
  [/\bbay leaves?\b/gi, 'hojas de laurel'],
  [/\bbay leaf\b/gi, 'hoja de laurel'],
  [/\blemon juice\b/gi, 'jugo de limón'],
  [/\blime juice\b/gi, 'jugo de lima'],
  [/\blemon zest\b/gi, 'ralladura de limón'],
  [/\blime zest\b/gi, 'ralladura de lima'],
  [/\borange juice\b/gi, 'jugo de naranja'],
  [/\blemons?\b/gi, 'limón'],
  [/\blimes?\b/gi, 'lima'],
  [/\bcrushed garlic\b/gi, 'ajo machacado'],
  [/\bminced garlic\b/gi, 'ajo picado'],
  [/\bchopped garlic\b/gi, 'ajo picado'],
  [/\bgarlic cloves?\b/gi, 'dientes de ajo'],
  [/\bgarlic\b/gi, 'ajo'],
  [/\byellow onions?\b/gi, 'cebolla amarilla'],
  [/\bred onions?\b/gi, 'cebolla morada'],
  [/\bwhite onions?\b/gi, 'cebolla blanca'],
  [/\bgreen onions?\b/gi, 'cebolletas'],
  [/\bspring onions?\b/gi, 'cebolletas'],
  [/\bscallions?\b/gi, 'cebollín'],
  [/\bshallots?\b/gi, 'chalotas'],
  [/\bonions?\b/gi, 'cebolla'],
  [/\bginger\b/gi, 'jengibre'],
  [/\bsweet potatoes?\b/gi, 'camote'],
  [/\bpotatoes?\b/gi, 'papas'],
  [/\bcherry tomatoes?\b/gi, 'tomates cherry'],
  [/\btomato paste\b/gi, 'pasta de tomate'],
  [/\btomato sauce\b/gi, 'salsa de tomate'],
  [/\bcanned tomatoes?\b/gi, 'tomates enlatados'],
  [/\bcrushed tomatoes?\b/gi, 'tomates triturados'],
  [/\bdiced tomatoes?\b/gi, 'tomates en cubos'],
  [/\btomatoes?\b/gi, 'tomates'],
  [/\bcelery\b/gi, 'apio'],
  [/\bcucumbers?\b/gi, 'pepino'],
  [/\bzucchinis?\b/gi, 'calabacín'],
  [/\bcourgettes?\b/gi, 'calabacín'],
  [/\bavocados?\b/gi, 'aguacate'],
  [/\bspinach\b/gi, 'espinacas'],
  [/\blettuce\b/gi, 'lechuga'],
  [/\bkale\b/gi, 'col rizada'],
  [/\bcabbage\b/gi, 'repollo'],
  [/\bcauliflower\b/gi, 'coliflor'],
  [/\bbroccoli\b/gi, 'brócoli'],
  [/\bmushrooms?\b/gi, 'champiñones'],
  [/\bred bell peppers?\b/gi, 'pimiento rojo'],
  [/\bgreen bell peppers?\b/gi, 'pimiento verde'],
  [/\byellow bell peppers?\b/gi, 'pimiento amarillo'],
  [/\bbell peppers?\b/gi, 'pimientos'],
  [/\bpeppers?\b/gi, 'pimientos'],
  [/\bjalape[nñ]os?\b/gi, 'jalapeño'],
  [/\bchili peppers?\b/gi, 'chiles'],
  [/\bchili\b/gi, 'chile'],
  [/\bgreen peas?\b/gi, 'guisantes'],
  [/\bpeas?\b/gi, 'guisantes'],
  [/\bcorn\b/gi, 'maíz'],
  [/\bgreen beans?\b/gi, 'ejotes'],
  [/\basparagus\b/gi, 'espárragos'],
  [/\beggplants?\b/gi, 'berenjena'],
  [/\baubergines?\b/gi, 'berenjena'],
  [/\bparsley\b/gi, 'perejil'],
  [/\bcilantro\b/gi, 'cilantro'],
  [/\bcoriander\b/gi, 'cilantro'],
  [/\bbasil\b/gi, 'albahaca'],
  [/\brosemary\b/gi, 'romero'],
  [/\boregano\b/gi, 'orégano'],
  [/\bmint\b/gi, 'menta'],
  [/\bdill\b/gi, 'eneldo'],
  [/\btarragon\b/gi, 'estragón'],
  [/\bchives\b/gi, 'cebollino'],
  [/\bsage\b/gi, 'salvia'],
  [/\bblack pepper\b/gi, 'pimienta negra'],
  [/\bwhite pepper\b/gi, 'pimienta blanca'],
  [/\bcayenne pepper\b/gi, 'pimienta de cayena'],
  [/\bred pepper flakes\b/gi, 'hojuelas de chile rojo'],
  [/\bchili powder\b/gi, 'chile en polvo'],
  [/\bcurry powder\b/gi, 'curry en polvo'],
  [/\bground cinnamon\b/gi, 'canela molida'],
  [/\bcinnamon stick\b/gi, 'rama de canela'],
  [/\bcinnamon\b/gi, 'canela'],
  [/\bground cumin\b/gi, 'comino molido'],
  [/\bcumin seeds?\b/gi, 'semillas de comino'],
  [/\bcumin\b/gi, 'comino'],
  [/\bsmoked paprika\b/gi, 'pimentón ahumado'],
  [/\bpaprika\b/gi, 'pimentón'],
  [/\bturmeric\b/gi, 'cúrcuma'],
  [/\bground nutmeg\b/gi, 'nuez moscada molida'],
  [/\bnutmeg\b/gi, 'nuez moscada'],
  [/\bground cloves?\b/gi, 'clavo molido'],
  [/\bwhole cloves?\b/gi, 'clavos de olor enteros'],
  [/\bcardamom\b/gi, 'cardamomo'],
  [/\bcoriander seeds?\b/gi, 'semillas de cilantro'],
  [/\bfennel seeds?\b/gi, 'semillas de hinojo'],
  [/\bsalt and black pepper\b/gi, 'sal y pimienta negra'],
  [/\bsalt and pepper\b/gi, 'sal y pimienta'],
  [/\bsea salt\b/gi, 'sal marina'],
  [/\bkosher salt\b/gi, 'sal kosher'],
  [/\bsalt\b/gi, 'sal'],
  [/\bextra virgin olive oil\b/gi, 'aceite de oliva virgen extra'],
  [/\bolive oil\b/gi, 'aceite de oliva'],
  [/\bvegetable oil\b/gi, 'aceite vegetal'],
  [/\bcanola oil\b/gi, 'aceite de canola'],
  [/\bsesame oil\b/gi, 'aceite de sésame'],
  [/\bcooking oil\b/gi, 'aceite de cocina'],
  [/\bdark soy sauce\b/gi, 'salsa de soya oscura'],
  [/\blight soy sauce\b/gi, 'salsa de soya clara'],
  [/\bsoy sauce\b/gi, 'salsa de soya'],
  [/\bfish sauce\b/gi, 'salsa de pescado'],
  [/\boyster sauce\b/gi, 'salsa de ostras'],
  [/\bworcestershire sauce\b/gi, 'salsa inglesa'],
  [/\bhot sauce\b/gi, 'salsa picante'],
  [/\bdijon mustard\b/gi, 'mostaza Dijon'],
  [/\bmustard\b/gi, 'mostaza'],
  [/\bmayonnaise\b/gi, 'mayonesa'],
  [/\bketchup\b/gi, 'kétchup'],
  [/\bapple cider vinegar\b/gi, 'vinagre de manzana'],
  [/\bred wine vinegar\b/gi, 'vinagre de vino tinto'],
  [/\bwhite wine vinegar\b/gi, 'vinagre de vino blanco'],
  [/\brice vinegar\b/gi, 'vinagre de arroz'],
  [/\bbalsamic vinegar\b/gi, 'vinagre balsámico'],
  [/\bvinegar\b/gi, 'vinagre'],
  [/\bhoney\b/gi, 'miel'],
  [/\bmaple syrup\b/gi, 'jarabe de arce'],
  [/\bunsalted butter\b/gi, 'mantequilla sin sal'],
  [/\bsalted butter\b/gi, 'mantequilla con sal'],
  [/\bbutter\b/gi, 'mantequilla'],
  [/\begg yolks?\b/gi, 'yemas de huevo'],
  [/\begg whites?\b/gi, 'claras de huevo'],
  [/\beggs?\b/gi, 'huevos'],
  [/\bwhole milk\b/gi, 'leche entera'],
  [/\bmilk\b/gi, 'leche'],
  [/\bheavy cream\b/gi, 'crema espesa'],
  [/\bwhipping cream\b/gi, 'crema para batir'],
  [/\bsour cream\b/gi, 'crema agria'],
  [/\bgreek yogurt\b/gi, 'yogur griego'],
  [/\byogurt\b/gi, 'yogur'],
  [/\bparmesan cheese\b/gi, 'queso parmesano'],
  [/\bparmesan\b/gi, 'parmesano'],
  [/\bcheddar cheese\b/gi, 'queso cheddar'],
  [/\bcheddar\b/gi, 'cheddar'],
  [/\bmozzarella cheese\b/gi, 'mozzarella'],
  [/\bmozzarella\b/gi, 'mozzarella'],
  [/\bcream cheese\b/gi, 'queso crema'],
  [/\bfeta cheese\b/gi, 'queso feta'],
  [/\bfeta\b/gi, 'feta'],
  [/\bricotta\b/gi, 'ricotta'],
  [/\bchicken breasts?\b/gi, 'pechugas de pollo'],
  [/\bchicken thighs?\b/gi, 'muslos de pollo'],
  [/\bchicken legs?\b/gi, 'piernas de pollo'],
  [/\bchicken wings?\b/gi, 'alitas de pollo'],
  [/\bchicken broth\b/gi, 'caldo de pollo'],
  [/\bchicken stock\b/gi, 'caldo de pollo'],
  [/\bwhole chicken\b/gi, 'pollo entero'],
  [/\bchicken\b/gi, 'pollo'],
  [/\bground beef\b/gi, 'carne molida de res'],
  [/\bbeef broth\b/gi, 'caldo de res'],
  [/\bbeef stock\b/gi, 'caldo de res'],
  [/\bbeef\b/gi, 'carne de res'],
  [/\bsteak\b/gi, 'bistec'],
  [/\bpork chops?\b/gi, 'chuletas de cerdo'],
  [/\bground pork\b/gi, 'carne molida de cerdo'],
  [/\bpork\b/gi, 'cerdo'],
  [/\bbacon\b/gi, 'tocino'],
  [/\bham\b/gi, 'jamón'],
  [/\bsausages?\b/gi, 'salchichas'],
  [/\blamb\b/gi, 'cordero'],
  [/\bground turkey\b/gi, 'pavo molido'],
  [/\bturkey\b/gi, 'pavo'],
  [/\bshrimps?\b/gi, 'camarones'],
  [/\bprawns?\b/gi, 'langostinos'],
  [/\bsalmon\b/gi, 'salmón'],
  [/\btuna\b/gi, 'atún'],
  [/\bcod\b/gi, 'bacalao'],
  [/\bwhite fish\b/gi, 'pescado blanco'],
  [/\bfish fillets?\b/gi, 'filetes de pescado'],
  [/\ball-purpose flour\b/gi, 'harina todo uso'],
  [/\bflour\b/gi, 'harina'],
  [/\bpanko bread crumbs?\b/gi, 'pan rallado panko'],
  [/\bbread crumbs?\b/gi, 'pan rallado'],
  [/\bpanko\b/gi, 'panko'],
  [/\bgranulated sugar\b/gi, 'azúcar granulada'],
  [/\bbrown sugar\b/gi, 'azúcar morena'],
  [/\bpowdered sugar\b/gi, 'azúcar glas'],
  [/\bicing sugar\b/gi, 'azúcar glas'],
  [/\bsugar\b/gi, 'azúcar'],
  [/\bbaking powder\b/gi, 'polvo para hornear'],
  [/\bbaking soda\b/gi, 'bicarbonato de sodio'],
  [/\bactive dry yeast\b/gi, 'levadura seca activa'],
  [/\byeast\b/gi, 'levadura'],
  [/\bvanilla extract\b/gi, 'extracto de vainilla'],
  [/\bvanilla\b/gi, 'vainilla'],
  [/\bcocoa powder\b/gi, 'cacao en polvo'],
  [/\bchocolate chips?\b/gi, 'chispas de chocolate'],
  [/\bdark chocolate\b/gi, 'chocolate amargo'],
  [/\bchocolate\b/gi, 'chocolate'],
  [/\bcornstarch\b/gi, 'maicena'],
  [/\bwhite rice\b/gi, 'arroz blanco'],
  [/\bbrown rice\b/gi, 'arroz integral'],
  [/\bjasmine rice\b/gi, 'arroz jazmín'],
  [/\bbasmati rice\b/gi, 'arroz basmati'],
  [/\brice\b/gi, 'arroz'],
  [/\bpasta\b/gi, 'pasta'],
  [/\bspaghetti\b/gi, 'espaguetis'],
  [/\bnoodles?\b/gi, 'fideos'],
  [/\brolled oats\b/gi, 'hojuelas de avena'],
  [/\boats\b/gi, 'avena'],
  [/\bvegetable broth\b/gi, 'caldo de verduras'],
  [/\bvegetable stock\b/gi, 'caldo de verduras'],
  [/\bcoconut milk\b/gi, 'leche de coco'],
  [/\bcoconut cream\b/gi, 'crema de coco'],
  [/\bchickpeas?\b/gi, 'garbanzos'],
  [/\bblack beans?\b/gi, 'frijoles negros'],
  [/\bkidney beans?\b/gi, 'frijoles rojos'],
  [/\blentils?\b/gi, 'lentejas'],
  [/\bpeanuts?\b/gi, 'cacahuates'],
  [/\balmonds?\b/gi, 'almendras'],
  [/\bwalnuts?\b/gi, 'nueces'],
  [/\bcashews?\b/gi, 'nueces de la India'],
  [/\bpeanut butter\b/gi, 'mantequilla de maní'],
];

const SPANISH_INSTRUCTION_GLOSSARY: PatternPair[] = [
  [/\bplace a steamer insert into a saucepan\b/gi, 'Colocar una vaporera en una cacerola'],
  [/\bbring the water to a boil over high heat\b/gi, 'llevar el agua a ebullición a fuego alto'],
  [/\bbring to a boil over high heat\b/gi, 'llevar a ebullición a fuego alto'],
  [/\bbring to a boil\b/gi, 'llevar a ebullición'],
  [/\bbring to a simmer\b/gi, 'llevar a fuego lento'],
  [/\breduce the heat to medium\b/gi, 'reducir el fuego a medio'],
  [/\breduce heat to medium\b/gi, 'reducir el fuego a medio'],
  [/\breduce the heat to low\b/gi, 'reducir el fuego a bajo'],
  [/\breduce heat to low\b/gi, 'reducir el fuego a bajo'],
  [/\breduce the heat\b/gi, 'reducir el fuego'],
  [/\breduce heat\b/gi, 'reducir el fuego'],
  [/\bheat the olive oil in a skillet over medium heat\b/gi, 'Calentar el aceite de oliva en una sartén a fuego medio'],
  [/\bheat the oil in a large skillet\b/gi, 'Calentar el aceite en una sartén grande'],
  [/\bheat the oil in a skillet\b/gi, 'Calentar el aceite en una sartén'],
  [/\bheat olive oil in a\b/gi, 'calentar aceite de oliva en'],
  [/\bheat the oil\b/gi, 'calentar el aceite'],
  [/\bpreheat oven to (\d+) degrees\b/gi, 'Precalentar el horno a $1 grados'],
  [/\bpreheat the oven to\b/gi, 'Precalentar el horno a'],
  [/\bsteam until tender but not mushy\b/gi, 'Cocinar al vapor hasta que esté tierno sin deshacerse'],
  [/\bsteam until tender\b/gi, 'Cocinar al vapor hasta que esté tierno'],
  [/\bcover and simmer for (\d+) minutes\b/gi, 'tapar y cocinar a fuego lento durante $1 minutos'],
  [/\bcover and simmer\b/gi, 'tapar y cocinar a fuego lento'],
  [/\bsimmer for (\d+) minutes\b/gi, 'cocinar a fuego lento durante $1 minutos'],
  [/\buntil fragrant, about (\d+) minutes\b/gi, 'hasta que suelte aroma, unos $1 minutos'],
  [/\buntil fragrant\b/gi, 'hasta que suelte aroma'],
  [/\buntil golden brown\b/gi, 'hasta que esté dorado'],
  [/\buntil tender\b/gi, 'hasta que esté tierno'],
  [/\bstirring frequently\b/gi, 'removiendo con frecuencia'],
  [/\bstirring occasionally\b/gi, 'removiendo de vez en cuando'],
  [/\bstir in the\b/gi, 'incorporar'],
  [/\bseason with salt and pepper\b/gi, 'sazonar con sal y pimienta'],
  [/\bseason to taste\b/gi, 'sazonar al gusto'],
  [/\bremove from heat\b/gi, 'retirar del fuego'],
  [/\bset aside\b/gi, 'reservar'],
  [/\bbefore serving\b/gi, 'antes de servir'],
  [/\bserve immediately\b/gi, 'servir de inmediato'],
  [/\bserve hot\b/gi, 'servir caliente'],
  [/\bserve warm\b/gi, 'servir tibio'],
  [/\bgarnish with\b/gi, 'decorar con'],
  [/\bsprinkle with lemon juice\b/gi, 'rociar con jugo de limón'],
  [/\bsprinkle with\b/gi, 'espolvorear con'],
  [/\bremove the bay leaf\b/gi, 'retirar la hoja de laurel'],
  [/\bdrain and rinse\b/gi, 'escurrir y enjuagar'],
  [/\bin a large bowl\b/gi, 'en un tazón grande'],
  [/\bin a medium bowl\b/gi, 'en un tazón mediano'],
  [/\bin a small bowl\b/gi, 'en un tazón pequeño'],
  [/\bin a saucepan\b/gi, 'en una cacerola'],
  [/\bin a skillet\b/gi, 'en una sartén'],
  [/\bin a baking dish\b/gi, 'en un molde para hornear'],
  [/\bwhisk together\b/gi, 'batir juntos'],
  [/\bmix well\b/gi, 'mezclar bien'],
  [/\btoss to coat\b/gi, 'mezclar para cubrir bien'],
  [/\btossing well to coat\b/gi, 'mezclando bien para cubrir'],
];

const SPANISH_MARKERS = [
  'cucharadita',
  'cucharada',
  'taza',
  'diente de ',
  'dientes de ',
  'pizca de ',
  'chorrito de ',
  'rebanada',
  'aceite de ',
  'caldo de ',
  'jugo de ',
  'polvo de ',
];

const SINGULAR_FRACTIONS = new Set(['1', '1/2', '1/4', '1/3', '3/4']);

function applyPatternPairs(value: string, pairs: PatternPair[]): string {
  let result = value;
  for (const [pattern, replacement] of pairs) {
    result = result.replace(pattern, replacement);
  }
  return result;
}

export function translateIngredient(
  raw: string,
  targetLang: AppLanguage = getActiveLanguage()
): string {
  if (targetLang === 'en') return raw;
  const trimmed = raw.trim();
  if (!trimmed) return raw;

  if (targetLang === 'fr') {
    const lowered = trimmed.toLowerCase();
    if (FRENCH_MARKERS.some((marker) => lowered.includes(marker))) {
      return trimmed;
    }

    let result = applyPatternPairs(trimmed, FRENCH_PREP_MAP);
    result = applyPatternPairs(result, FRENCH_INGREDIENT_GLOSSARY);

    for (const rule of FRENCH_UNIT_MAP) {
      const regex = new RegExp(
        `(\\d+(?:/\\d+)?(?:\\s+\\d+/\\d+)?|\\d+(?:\\.\\d+)?)\\s*${rule.pattern}`,
        'i'
      );
      const match = regex.exec(result);
      if (!match || match.index === undefined) continue;

      const amount = match[1];
      const remainder = result.slice(match.index + match[0].length).trim();

      let unit = rule.replacement;
      if (!SINGULAR_FRACTIONS.has(amount)) {
        if (unit === 'gousse') unit = 'gousses';
        else if (unit === 'tasse') unit = 'tasses';
        else if (unit === 'tranche') unit = 'tranches';
        else if (unit === 'boîte') unit = 'boîtes';
        else if (unit === 'morceau') unit = 'morceaux';
      }

      if (
        rule.needsConnector &&
        remainder.length > 0 &&
        !remainder.toLowerCase().startsWith('de ') &&
        !remainder.toLowerCase().startsWith("d'")
      ) {
        const firstChar = remainder[0].toLowerCase();
        const isVowelOrSilentH = 'aeiouyhéèêàœ'.includes(firstChar);
        const connector = isVowelOrSilentH ? "d'" : 'de ';
        result = `${amount} ${unit} ${connector}${remainder}`;
      } else {
        result = `${amount} ${unit} ${remainder}`.trim();
      }
      break;
    }

    return result
      .replace(/\s{2,}/g, ' ')
      .replace(/de d'/gi, "d'")
      .replace(/de de /gi, 'de ')
      .trim();
  }

  // Spanish
  const lowered = trimmed.toLowerCase();
  if (SPANISH_MARKERS.some((marker) => lowered.includes(marker))) {
    return trimmed;
  }

  let result = applyPatternPairs(trimmed, SPANISH_PREP_MAP);
  result = applyPatternPairs(result, SPANISH_INGREDIENT_GLOSSARY);

  for (const rule of SPANISH_UNIT_MAP) {
    const regex = new RegExp(
      `(\\d+(?:/\\d+)?(?:\\s+\\d+/\\d+)?|\\d+(?:\\.\\d+)?)\\s*${rule.pattern}`,
      'i'
    );
    const match = regex.exec(result);
    if (!match || match.index === undefined) continue;

    const amount = match[1];
    const remainder = result.slice(match.index + match[0].length).trim();
    let unit = rule.replacement;

    if (!SINGULAR_FRACTIONS.has(amount) && SPANISH_PLURALS[unit]) {
      unit = SPANISH_PLURALS[unit];
    }

    if (
      rule.needsConnector &&
      remainder.length > 0 &&
      !remainder.toLowerCase().startsWith('de ')
    ) {
      result = `${amount} ${unit} de ${remainder}`;
    } else {
      result = `${amount} ${unit} ${remainder}`.trim();
    }
    break;
  }

  return result
    .replace(/\s{2,}/g, ' ')
    .replace(/de de /gi, 'de ')
    .trim();
}

export function translateInstruction(
  raw: string,
  targetLang: AppLanguage = getActiveLanguage()
): string {
  if (targetLang === 'en') return raw;
  const trimmed = raw.trim();
  if (!trimmed) return raw;
  if (targetLang === 'fr') {
    return applyPatternPairs(trimmed, FRENCH_INSTRUCTION_GLOSSARY);
  }
  return applyPatternPairs(trimmed, SPANISH_INSTRUCTION_GLOSSARY);
}

export function translateDiscoveredSummary(
  summary: DiscoveredRecipeSummary,
  lang: AppLanguage = getActiveLanguage()
): DiscoveredRecipeSummary {
  const canonicalID = canonicalRecipeID(summary.id);
  if (lang === 'en') {
    return {
      ...summary,
      id: canonicalID,
    };
  }

  const localRecord = getLocalMealRecord(canonicalID, lang);
  if (localRecord) {
    return {
      id: canonicalID,
      name: localRecord.name,
      thumbnailURL: summary.thumbnailURL ?? (localRecord.thumbnailURL || null),
      category: summary.category ?? (localRecord.category || null),
      area: summary.area ?? (localRecord.area || null),
      illustrationIconID: summary.illustrationIconID ?? (localRecord.illustration || null),
    };
  }

  if (lang === 'fr') {
    const frenchTitle = getTranslatedFrenchName(canonicalID);
    if (frenchTitle) {
      return {
        ...summary,
        id: canonicalID,
        name: frenchTitle,
      };
    }
  }

  return {
    ...summary,
    id: canonicalID,
  };
}

export function translateDiscoveredDetail(
  detail: DiscoveredRecipeDetail,
  lang: AppLanguage = getActiveLanguage()
): DiscoveredRecipeDetail {
  const canonicalID = canonicalRecipeID(detail.id);
  if (lang === 'en') return { ...detail, id: canonicalID };

  const localRecord = getLocalMealDetail(canonicalID, lang);
  if (localRecord) {
    return localRecord;
  }

  if (lang === 'fr') {
    const record = getTheMealDBRecord(canonicalID);
    if (record) {
      return {
        id: canonicalID,
        name: record.name,
        category: detail.category ?? (record.category || null),
        area: detail.area ?? (record.area || null),
        instructions: cleanInstructions(record.instructions, record.name),
        ingredients: record.ingredients,
        thumbnailURL: detail.thumbnailURL ?? (record.thumbnailURL || null),
        sourceURL: detail.sourceURL ?? null,
        youtubeURL: detail.youtubeURL ?? null,
        tags: detail.tags,
        illustrationIconID: detail.illustrationIconID ?? null,
      };
    }
  }

  const translatedIngredients = detail.ingredients.map((line) => translateIngredient(line, lang));
  const translatedInstructions = detail.instructions.map((step) => translateInstruction(step, lang));

  return {
    ...detail,
    id: canonicalID,
    instructions: cleanInstructions(translatedInstructions, detail.name),
    ingredients: translatedIngredients,
  };
}
