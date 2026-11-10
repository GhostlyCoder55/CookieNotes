//
//  RecipeTranslator.swift
//  CookieNotes
//
//  Translates recipe ingredients, measurements, and cooking instructions into natural French.
//

import Foundation

enum RecipeTranslator {
    // MARK: - Measurement Units Dictionary
    private static let unitMap: [(pattern: String, replacement: String, needsConnector: Bool)] = [
        // Teaspoons
        (#"(?i)\b(?:teaspoons?|tsp\.?|t\.)\b"#, "c. à thé", true),
        // Tablespoons
        (#"(?i)\b(?:tablespoons?|tbsp\.?|tbs\.?|tbsps?)\b"#, "c. à soupe", true),
        // Cups
        (#"(?i)\bcups?\b"#, "tasse", true),
        // Pounds
        (#"(?i)\b(?:pounds?|lbs?\.?)\b"#, "lb", true),
        // Ounces
        (#"(?i)\b(?:ounces?|oz\.?)\b"#, "oz", true),
        // Grams
        (#"(?i)\b(?:grams?|g\.?)\b"#, "g", true),
        // Kilograms
        (#"(?i)\b(?:kilograms?|kg\.?)\b"#, "kg", true),
        // Milliliters
        (#"(?i)\b(?:milliliters?|ml\.?)\b"#, "ml", true),
        // Liters
        (#"(?i)\b(?:liters?|litres?|l\.?)\b"#, "L", true),
        // Cloves
        (#"(?i)\bcloves?\b"#, "gousse", true),
        // Slices
        (#"(?i)\bslices?\b"#, "tranche", true),
        // Pinches
        (#"(?i)\bpinches?\b"#, "pincée", true),
        // Dashes
        (#"(?i)\bdashes?\b"#, "filet", true),
        // Cans
        (#"(?i)\bcans?\b"#, "boîte", true),
        // Packages
        (#"(?i)\b(?:packages?|pkgs?\.?)\b"#, "paquet", true),
        // Sprigs
        (#"(?i)\bsprigs?\b"#, "brin", true),
        // Bunches
        (#"(?i)\bbunches?\b"#, "botte", true),
        // Stalks
        (#"(?i)\bstalks?\b"#, "branche", true),
        // Heads
        (#"(?i)\bheads?\b"#, "tête", true),
        // Pieces
        (#"(?i)\bpieces?\b"#, "morceau", true)
    ]

    // MARK: - Preparation Adjectives & Qualifiers
    private static let prepMap: [(pattern: String, replacement: String)] = [
        (#"(?i)\bfinely chopped\b"#, "finement haché"),
        (#"(?i)\bcoarsely chopped\b"#, "grossièrement haché"),
        (#"(?i)\bchopped\b"#, "haché"),
        (#"(?i)\bdiced\b"#, "en dés"),
        (#"(?i)\bminced\b"#, "émincé"),
        (#"(?i)\bthinly sliced\b"#, "finement tranché"),
        (#"(?i)\bsliced\b"#, "en tranches"),
        (#"(?i)\bcrushed\b"#, "écrasé"),
        (#"(?i)\bfinely grated\b"#, "finement râpé"),
        (#"(?i)\bgrated\b"#, "râpé"),
        (#"(?i)\bshredded\b"#, "râpé"),
        (#"(?i)\bmelted\b"#, "fondu"),
        (#"(?i)\bsoftened\b"#, "ramolli"),
        (#"(?i)\bground\b"#, "moulu"),
        (#"(?i)\bfreshly ground\b"#, "fraîchement moulu"),
        (#"(?i)\bfresh\b"#, "frais"),
        (#"(?i)\bdried\b"#, "séché"),
        (#"(?i)\bcooked\b"#, "cuit"),
        (#"(?i)\braw\b"#, "cru"),
        (#"(?i)\bfrozen\b"#, "surgelé"),
        (#"(?i)\bthawed\b"#, "décongelé"),
        (#"(?i)\bboneless\b"#, "désossé"),
        (#"(?i)\bskinless\b"#, "sans peau"),
        (#"(?i)\bpeeled\b"#, "pelé"),
        (#"(?i)\bseeded\b"#, "épépiné"),
        (#"(?i)\bto taste\b"#, "au goût"),
        (#"(?i)\bfor serving\b"#, "pour servir"),
        (#"(?i)\bfor garnish\b"#, "pour garnir"),
        (#"(?i)\bfor frying\b"#, "pour la friture"),
        (#"(?i)\bdivided\b"#, "divisé"),
        (#"(?i)\boptional\b"#, "facultatif"),
        (#"(?i)\bplus more\b"#, "et plus"),
        (#"(?i)\bas needed\b"#, "au besoin")
    ]

    // MARK: - Ingredient Glossary
    private static let ingredientGlossary: [(pattern: String, replacement: String)] = [
        // Produce & Herbs
        (#"(?i)\bwater\b"#, "eau"),
        (#"(?i)\bcarrots?\b"#, "carottes"),
        (#"(?i)\bthyme\b"#, "thym"),
        (#"(?i)\bbay leaves?\b"#, "feuilles de laurier"),
        (#"(?i)\bbay leaf\b"#, "feuille de laurier"),
        (#"(?i)\blemon juice\b"#, "jus de citron"),
        (#"(?i)\blime juice\b"#, "jus de lime"),
        (#"(?i)\blemon zest\b"#, "zeste de citron"),
        (#"(?i)\blime zest\b"#, "zeste de lime"),
        (#"(?i)\borange juice\b"#, "jus d'orange"),
        (#"(?i)\blemons?\b"#, "citron"),
        (#"(?i)\blimes?\b"#, "lime"),
        (#"(?i)\bcrushed garlic\b"#, "ail écrasé"),
        (#"(?i)\bminced garlic\b"#, "ail haché"),
        (#"(?i)\bchopped garlic\b"#, "ail émincé"),
        (#"(?i)\bgarlic cloves?\b"#, "gousses d'ail"),
        (#"(?i)\bgarlic\b"#, "ail"),
        (#"(?i)\byellow onions?\b"#, "oignon jaune"),
        (#"(?i)\bred onions?\b"#, "oignon rouge"),
        (#"(?i)\bwhite onions?\b"#, "oignon blanc"),
        (#"(?i)\bgreen onions?\b"#, "oignons verts"),
        (#"(?i)\bspring onions?\b"#, "oignons verts"),
        (#"(?i)\bscallions?\b"#, "échalotes vertes"),
        (#"(?i)\bshallots?\b"#, "échalotes"),
        (#"(?i)\bonions?\b"#, "oignon"),
        (#"(?i)\bginger\b"#, "gingembre"),
        (#"(?i)\bpotatoes?\b"#, "pommes de terre"),
        (#"(?i)\bsweet potatoes?\b"#, "patates douces"),
        (#"(?i)\btomatoes?\b"#, "tomates"),
        (#"(?i)\bcherry tomatoes?\b"#, "tomates cerises"),
        (#"(?i)\btomato paste\b"#, "pâte de tomate"),
        (#"(?i)\btomato sauce\b"#, "sauce tomate"),
        (#"(?i)\bcanned tomatoes?\b"#, "tomates en boîte"),
        (#"(?i)\bcrushed tomatoes?\b"#, "tomates broyées"),
        (#"(?i)\bdiced tomatoes?\b"#, "tomates en dés"),
        (#"(?i)\bcelery\b"#, "céleri"),
        (#"(?i)\bcucumbers?\b"#, "concombre"),
        (#"(?i)\bzucchinis?\b"#, "courgette"),
        (#"(?i)\bcourgettes?\b"#, "courgette"),
        (#"(?i)\bavocados?\b"#, "avocat"),
        (#"(?i)\bspinach\b"#, "épinards"),
        (#"(?i)\blettuce\b"#, "laitue"),
        (#"(?i)\bkale\b"#, "chou frisé"),
        (#"(?i)\bcabbage\b"#, "chou"),
        (#"(?i)\bcauliflower\b"#, "chou-fleur"),
        (#"(?i)\bbroccoli\b"#, "brocoli"),
        (#"(?i)\bmushrooms?\b"#, "champignons"),
        (#"(?i)\bpeppers?\b"#, "poivrons"),
        (#"(?i)\bbell peppers?\b"#, "poivrons"),
        (#"(?i)\bred bell peppers?\b"#, "poivron rouge"),
        (#"(?i)\bgreen bell peppers?\b"#, "poivron vert"),
        (#"(?i)\byellow bell peppers?\b"#, "poivron jaune"),
        (#"(?i)\bjalape[nñ]os?\b"#, "jalapeño"),
        (#"(?i)\bchili peppers?\b"#, "piments"),
        (#"(?i)\bchili\b"#, "piment"),
        (#"(?i)\bpeas?\b"#, "pois"),
        (#"(?i)\bgreen peas?\b"#, "petits pois"),
        (#"(?i)\bcorn\b"#, "maïs"),
        (#"(?i)\bgreen beans?\b"#, "haricots verts"),
        (#"(?i)\basparagus\b"#, "asperges"),
        (#"(?i)\beggplants?\b"#, "aubergine"),
        (#"(?i)\baubergines?\b"#, "aubergine"),
        (#"(?i)\bparsley\b"#, "persil"),
        (#"(?i)\bcilantro\b"#, "coriandre"),
        (#"(?i)\bcoriander\b"#, "coriandre"),
        (#"(?i)\bbasil\b"#, "basilic"),
        (#"(?i)\brosemary\b"#, "romarin"),
        (#"(?i)\boregano\b"#, "origan"),
        (#"(?i)\bmint\b"#, "menthe"),
        (#"(?i)\bdill\b"#, "aneth"),
        (#"(?i)\btarragon\b"#, "estragon"),
        (#"(?i)\bchives\b"#, "ciboulette"),
        (#"(?i)\bsage\b"#, "sauge"),

        // Spices & Seasonings
        (#"(?i)\bblack pepper\b"#, "poivre noir"),
        (#"(?i)\bwhite pepper\b"#, "poivre blanc"),
        (#"(?i)\bcayenne pepper\b"#, "poivre de Cayenne"),
        (#"(?i)\bred pepper flakes\b"#, "flocons de piment fort"),
        (#"(?i)\bchili powder\b"#, "poudre de chili"),
        (#"(?i)\bcurry powder\b"#, "poudre de cari"),
        (#"(?i)\bground cinnamon\b"#, "cannelle moulue"),
        (#"(?i)\bcinnamon stick\b"#, "bâton de cannelle"),
        (#"(?i)\bcinnamon\b"#, "cannelle"),
        (#"(?i)\bground cumin\b"#, "cumin moulu"),
        (#"(?i)\bcumin seeds?\b"#, "graines de cumin"),
        (#"(?i)\bcumin\b"#, "cumin"),
        (#"(?i)\bpaprika\b"#, "paprika"),
        (#"(?i)\bsmoked paprika\b"#, "paprika fumé"),
        (#"(?i)\bturmeric\b"#, "curcuma"),
        (#"(?i)\bground nutmeg\b"#, "muscade moulue"),
        (#"(?i)\bnutmeg\b"#, "muscade"),
        (#"(?i)\bground cloves?\b"#, "clou de girofle moulu"),
        (#"(?i)\bwhole cloves?\b"#, "clous de girofle entiers"),
        (#"(?i)\bcardamom\b"#, "cardamome"),
        (#"(?i)\bcoriander seeds?\b"#, "graines de coriandre"),
        (#"(?i)\bfennel seeds?\b"#, "graines de fenouil"),
        (#"(?i)\bsalt and black pepper\b"#, "sel et poivre noir"),
        (#"(?i)\bsalt and pepper\b"#, "sel et poivre"),
        (#"(?i)\bsea salt\b"#, "sel de mer"),
        (#"(?i)\bkosher salt\b"#, "sel casher"),
        (#"(?i)\bsalt\b"#, "sel"),

        // Oils & Condiments
        (#"(?i)\bextra virgin olive oil\b"#, "huile d'olive extra-vierge"),
        (#"(?i)\bolive oil\b"#, "huile d'olive"),
        (#"(?i)\bvegetable oil\b"#, "huile végétale"),
        (#"(?i)\bcanola oil\b"#, "huile de canola"),
        (#"(?i)\bsesame oil\b"#, "huile de sésame"),
        (#"(?i)\bcooking oil\b"#, "huile de cuisson"),
        (#"(?i)\bsoy sauce\b"#, "sauce soja"),
        (#"(?i)\bdark soy sauce\b"#, "sauce soja foncée"),
        (#"(?i)\blight soy sauce\b"#, "sauce soja claire"),
        (#"(?i)\bfish sauce\b"#, "sauce de poisson"),
        (#"(?i)\boyster sauce\b"#, "sauce aux huîtres"),
        (#"(?i)\bworcestershire sauce\b"#, "sauce Worcestershire"),
        (#"(?i)\bhot sauce\b"#, "sauce piquante"),
        (#"(?i)\bdijon mustard\b"#, "moutarde de Dijon"),
        (#"(?i)\bmustard\b"#, "moutarde"),
        (#"(?i)\bmayonnaise\b"#, "mayonnaise"),
        (#"(?i)\bketchup\b"#, "ketchup"),
        (#"(?i)\bvinegar\b"#, "vinaigre"),
        (#"(?i)\bapple cider vinegar\b"#, "vinaigre de cidre de pomme"),
        (#"(?i)\bred wine vinegar\b"#, "vinaigre de vin rouge"),
        (#"(?i)\bwhite wine vinegar\b"#, "vinaigre de vin blanc"),
        (#"(?i)\brice vinegar\b"#, "vinaigre de riz"),
        (#"(?i)\bbalsamic vinegar\b"#, "vinaigre balsamique"),
        (#"(?i)\bhoney\b"#, "miel"),
        (#"(?i)\bmaple syrup\b"#, "sirop d'érable"),

        // Dairy & Eggs
        (#"(?i)\bunsalted butter\b"#, "beurre non salé"),
        (#"(?i)\bsalted butter\b"#, "beurre salé"),
        (#"(?i)\bbutter\b"#, "beurre"),
        (#"(?i)\beggs?\b"#, "œufs"),
        (#"(?i)\begg yolks?\b"#, "jaunes d'œufs"),
        (#"(?i)\begg whites?\b"#, "blancs d'œufs"),
        (#"(?i)\bmilk\b"#, "lait"),
        (#"(?i)\bwhole milk\b"#, "lait entier"),
        (#"(?i)\bheavy cream\b"#, "crème épaisse"),
        (#"(?i)\bwhipping cream\b"#, "crème à fouetter"),
        (#"(?i)\bsour cream\b"#, "crème sure"),
        (#"(?i)\byogurt\b"#, "yogourt"),
        (#"(?i)\bgreek yogurt\b"#, "yogourt grec"),
        (#"(?i)\bparmesan cheese\b"#, "parmesan"),
        (#"(?i)\bparmesan\b"#, "parmesan"),
        (#"(?i)\bcheddar cheese\b"#, "fromage cheddar"),
        (#"(?i)\bcheddar\b"#, "cheddar"),
        (#"(?i)\bmozzarella cheese\b"#, "mozzarella"),
        (#"(?i)\bmozzarella\b"#, "mozzarella"),
        (#"(?i)\bcream cheese\b"#, "fromage à la crème"),
        (#"(?i)\bfeta cheese\b"#, "fromage feta"),
        (#"(?i)\bfeta\b"#, "feta"),
        (#"(?i)\bricotta\b"#, "ricotta"),

        // Meat & Seafood
        (#"(?i)\bchicken breasts?\b"#, "poitrines de poulet"),
        (#"(?i)\bchicken thighs?\b"#, "hauts de cuisse de poulet"),
        (#"(?i)\bchicken legs?\b"#, "cuisses de poulet"),
        (#"(?i)\bchicken wings?\b"#, "ailes de poulet"),
        (#"(?i)\bchicken broth\b"#, "bouillon de poulet"),
        (#"(?i)\bchicken stock\b"#, "fond de poulet"),
        (#"(?i)\bwhole chicken\b"#, "poulet entier"),
        (#"(?i)\bchicken\b"#, "poulet"),
        (#"(?i)\bground beef\b"#, "bœuf haché"),
        (#"(?i)\bbeef broth\b"#, "bouillon de bœuf"),
        (#"(?i)\bbeef stock\b"#, "fond de bœuf"),
        (#"(?i)\bbeef\b"#, "bœuf"),
        (#"(?i)\bsteak\b"#, "steak"),
        (#"(?i)\bpork chops?\b"#, "côtelettes de porc"),
        (#"(?i)\bground pork\b"#, "porc haché"),
        (#"(?i)\bpork\b"#, "porc"),
        (#"(?i)\bbacon\b"#, "bacon"),
        (#"(?i)\bham\b"#, "jambon"),
        (#"(?i)\bsausages?\b"#, "saucisses"),
        (#"(?i)\blamb\b"#, "agneau"),
        (#"(?i)\bturkey\b"#, "dinde"),
        (#"(?i)\bground turkey\b"#, "dinde hachée"),
        (#"(?i)\bshrimps?\b"#, "crevettes"),
        (#"(?i)\bprawns?\b"#, "grosses crevettes"),
        (#"(?i)\bsalmon\b"#, "saumon"),
        (#"(?i)\btuna\b"#, "thon"),
        (#"(?i)\bcod\b"#, "morue"),
        (#"(?i)\bwhite fish\b"#, "poisson blanc"),
        (#"(?i)\bfish fillets?\b"#, "filets de poisson"),

        // Pantry & Baking
        (#"(?i)\ball-purpose flour\b"#, "farine tout usage"),
        (#"(?i)\bflour\b"#, "farine"),
        (#"(?i)\bbread crumbs?\b"#, "chapelure"),
        (#"(?i)\bpanko bread crumbs?\b"#, "chapelure panko"),
        (#"(?i)\bpanko\b"#, "panko"),
        (#"(?i)\bgranulated sugar\b"#, "sucre granulé"),
        (#"(?i)\bbrown sugar\b"#, "cassonade"),
        (#"(?i)\bpowdered sugar\b"#, "sucre à glacer"),
        (#"(?i)\bicing sugar\b"#, "sucre à glacer"),
        (#"(?i)\bsugar\b"#, "sucre"),
        (#"(?i)\bbaking powder\b"#, "poudre à pâte"),
        (#"(?i)\bbaking soda\b"#, "bicarbonate de soude"),
        (#"(?i)\bactive dry yeast\b"#, "levure sèche active"),
        (#"(?i)\byeast\b"#, "levure"),
        (#"(?i)\bvanilla extract\b"#, "extrait de vanille"),
        (#"(?i)\bvanilla\b"#, "vanille"),
        (#"(?i)\bcocoa powder\b"#, "poudre de cacao"),
        (#"(?i)\bchocolate chips?\b"#, "pépites de chocolat"),
        (#"(?i)\bdark chocolate\b"#, "chocolat noir"),
        (#"(?i)\bchocolate\b"#, "chocolat"),
        (#"(?i)\bcornstarch\b"#, "fécule de maïs"),
        (#"(?i)\bwhite rice\b"#, "riz blanc"),
        (#"(?i)\bbrown rice\b"#, "riz brun"),
        (#"(?i)\bjasmine rice\b"#, "riz jasmin"),
        (#"(?i)\bbasmati rice\b"#, "riz basmati"),
        (#"(?i)\brice\b"#, "riz"),
        (#"(?i)\bpasta\b"#, "pâtes"),
        (#"(?i)\bspaghetti\b"#, "spaghetti"),
        (#"(?i)\bnoodles?\b"#, "nouilles"),
        (#"(?i)\brolled oats\b"#, "flocons d'avoine"),
        (#"(?i)\boats\b"#, "avoine"),
        (#"(?i)\bvegetable broth\b"#, "bouillon de légumes"),
        (#"(?i)\bvegetable stock\b"#, "fond de légumes"),
        (#"(?i)\bwater\b"#, "eau"),
        (#"(?i)\bcoconut milk\b"#, "lait de coco"),
        (#"(?i)\bcoconut cream\b"#, "crème de coco"),
        (#"(?i)\bchickpeas?\b"#, "pois chiches"),
        (#"(?i)\bblack beans?\b"#, "haricots noirs"),
        (#"(?i)\bkidney beans?\b"#, "haricots rouges"),
        (#"(?i)\blentils?\b"#, "lentilles"),
        (#"(?i)\bpeanuts?\b"#, "arachides"),
        (#"(?i)\balmonds?\b"#, "amandes"),
        (#"(?i)\bwalnuts?\b"#, "noix"),
        (#"(?i)\bcashews?\b"#, "noix de cajou"),
        (#"(?i)\bpeanut butter\b"#, "beurre d'arachide")
    ]

    // MARK: - Instruction Culinary Actions
    private static let instructionGlossary: [(pattern: String, replacement: String)] = [
        (#"(?i)\bplace a steamer insert into a saucepan\b"#, "Placer un panier vapeur dans une casserole"),
        (#"(?i)\bbring to a boil over high heat\b"#, "porter à ébullition à feu vif"),
        (#"(?i)\bbring the water to a boil over high heat\b"#, "porter l'eau à ébullition à feu vif"),
        (#"(?i)\bbring to a boil\b"#, "porter à ébullition"),
        (#"(?i)\bbring to a simmer\b"#, "amener à frémissement"),
        (#"(?i)\breduce the heat to medium\b"#, "réduire le feu à moyen"),
        (#"(?i)\breduce heat to medium\b"#, "réduire le feu à moyen"),
        (#"(?i)\breduce the heat to low\b"#, "réduire le feu à doux"),
        (#"(?i)\breduce heat to low\b"#, "réduire le feu à doux"),
        (#"(?i)\breduce the heat\b"#, "réduire le feu"),
        (#"(?i)\breduce heat\b"#, "réduire le feu"),
        (#"(?i)\bheat the olive oil in a skillet over medium heat\b"#, "Faire chauffer l'huile d'olive dans une poêle à feu moyen"),
        (#"(?i)\bheat the oil in a skillet\b"#, "Faire chauffer l'huile dans une poêle"),
        (#"(?i)\bheat the oil in a large skillet\b"#, "Faire chauffer l'huile dans une grande poêle"),
        (#"(?i)\bheat olive oil in a\b"#, "faire chauffer l'huile d'olive dans"),
        (#"(?i)\bheat the oil\b"#, "faire chauffer l'huile"),
        (#"(?i)\bpreheat oven to (\d+) degrees\b"#, "Préchauffer le four à $1 degrés"),
        (#"(?i)\bpreheat the oven to\b"#, "Préchauffer le four à"),
        (#"(?i)\bsteam until tender but not mushy\b"#, "Cuire à la vapeur jusqu'à tendreté mais sans écraser"),
        (#"(?i)\bsteam until tender\b"#, "Cuire à la vapeur jusqu'à ce que ce soit tendre"),
        (#"(?i)\bcover and simmer for (\d+) minutes\b"#, "couvrir et laisser mijoter pendant $1 minutes"),
        (#"(?i)\bcover and simmer\b"#, "couvrir et laisser mijoter"),
        (#"(?i)\bsimmer for (\d+) minutes\b"#, "laisser mijoter pendant $1 minutes"),
        (#"(?i)\buntil fragrant, about (\d+) minutes\b"#, "jusqu'à ce que ce soit parfumé, environ $1 minutes"),
        (#"(?i)\buntil fragrant\b"#, "jusqu'à ce que ce soit parfumé"),
        (#"(?i)\buntil golden brown\b"#, "jusqu'à coloration dorée"),
        (#"(?i)\buntil tender\b"#, "jusqu'à tendreté"),
        (#"(?i)\bstirring frequently\b"#, "en remuant fréquemment"),
        (#"(?i)\bstirring occasionally\b"#, "en remuant de temps en temps"),
        (#"(?i)\bstir in the\b"#, "incorporer le"),
        (#"(?i)\bseason with salt and pepper\b"#, "assaisonner de sel et de poivre"),
        (#"(?i)\bseason to taste\b"#, "assaisonner au goût"),
        (#"(?i)\bremove from heat\b"#, "retirer du feu"),
        (#"(?i)\bset aside\b"#, "réserver"),
        (#"(?i)\bbefore serving\b"#, "avant de servir"),
        (#"(?i)\bserve immediately\b"#, "servir immédiatement"),
        (#"(?i)\bserve hot\b"#, "servir chaud"),
        (#"(?i)\bserve warm\b"#, "servir tiède"),
        (#"(?i)\bgarnish with\b"#, "garnir de"),
        (#"(?i)\bsprinkle with lemon juice\b"#, "arroser de jus de citron"),
        (#"(?i)\bsprinkle with\b"#, "saupoudrer de"),
        (#"(?i)\bremove the bay leaf\b"#, "retirer la feuille de laurier"),
        (#"(?i)\bdrain and rinse\b"#, "égoutter et rincer"),
        (#"(?i)\bin a large bowl\b"#, "dans un grand bol"),
        (#"(?i)\bin a medium bowl\b"#, "dans un bol moyen"),
        (#"(?i)\bin a small bowl\b"#, "dans un petit bol"),
        (#"(?i)\bin a saucepan\b"#, "dans une casserole"),
        (#"(?i)\bin a skillet\b"#, "dans une poêle"),
        (#"(?i)\bin a baking dish\b"#, "dans un plat de cuisson"),
        (#"(?i)\bwhisk together\b"#, "fouetter ensemble"),
        (#"(?i)\bmix well\b"#, "bien mélanger"),
        (#"(?i)\btoss to coat\b"#, "remuer pour bien enrober"),
        (#"(?i)\btossing well to coat\b"#, "en remuant bien pour enrober")
    ]

    // MARK: - Public Translation API

    /// Translates an ingredient string to French, adjusting units, names, and French connectors.
    static func translateIngredient(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

        // If it already contains French terms, don't re-translate
        let frenchMarkers = [
            "c. à thé", "c. à soupe", "tasse", "gousse", "pincée", "tranche", "botte", "boîte",
            "d'ail", "d'huile", "huile d'", "huile de ", "de sel", "poudre de ", "jus de ", "bouillon de "
        ]
        if frenchMarkers.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
            return trimmed
        }

        var result = trimmed

        // 1. Translate preps/qualifiers
        for (pattern, repl) in prepMap {
            result = result.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
        }

        // 2. Translate base ingredients
        for (pattern, repl) in ingredientGlossary {
            result = result.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
        }

        // 3. Translate units & fix connectors (e.g. "1/2 c. à thé de thym", "1 tasse d'eau")
        for (pattern, repl, needsConnector) in unitMap {
            let regex = try? NSRegularExpression(pattern: #"(\d+(?:/\d+)?(?:\s+\d+/\d+)?|\d+(?:\.\d+)?)\s*"# + pattern, options: .caseInsensitive)
            if let match = regex?.firstMatch(in: result, options: [], range: NSRange(result.startIndex..., in: result)) {
                let amountRange = Range(match.range(at: 1), in: result)!
                let amount = String(result[amountRange])
                let fullRange = Range(match.range, in: result)!

                let remainder = String(result[fullRange.upperBound...]).trimmingCharacters(in: .whitespaces)

                var unit = repl
                if (amount != "1" && amount != "1/2" && amount != "1/4" && amount != "1/3" && amount != "3/4") {
                    if repl == "gousse" { unit = "gousses" }
                    else if repl == "tasse" { unit = "tasses" }
                    else if repl == "tranche" { unit = "tranches" }
                    else if repl == "boîte" { unit = "boîtes" }
                    else if repl == "morceau" { unit = "morceaux" }
                }

                if needsConnector && !remainder.isEmpty && !remainder.hasPrefix("de ") && !remainder.hasPrefix("d'") {
                    let firstChar = remainder.lowercased().prefix(1)
                    let isVowel = "aeiouyhéèêà".contains(firstChar)
                    let connector = isVowel ? "d'" : "de "
                    result = "\(amount) \(unit) \(connector)\(remainder)"
                } else {
                    result = "\(amount) \(unit) \(remainder)"
                }
                break
            }
        }

        // 4. Minor cleanups
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: "de d'", with: "d'")
        result = result.replacingOccurrences(of: "de de ", with: "de ")
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Translates a single instruction step using the culinary glossary.
    static func translateInstruction(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

        var result = trimmed
        for (pattern, repl) in instructionGlossary {
            result = result.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
        }
        return result
    }

    /// Translates a discovered recipe summary into French if in French mode.
    static func translatedSummary(_ summary: DiscoveredRecipeSummary) -> DiscoveredRecipeSummary {
        guard AppLanguageManager.shared.activeLanguage == .french else { return summary }
        let translatedName = TheMealDBCatalog.translatedName(for: summary.id) ?? summary.name
        return DiscoveredRecipeSummary(
            id: summary.id,
            name: translatedName,
            thumbnailURL: summary.thumbnailURL,
            category: summary.category,
            area: summary.area,
            illustrationIconID: summary.illustrationIconID
        )
    }

    /// Translates a full DiscoveredRecipeDetail into French if in French mode.
    static func translateDetail(_ detail: DiscoveredRecipeDetail) -> DiscoveredRecipeDetail {
        guard AppLanguageManager.shared.activeLanguage == .french else { return detail }

        // Check if catalog has pre-translated record
        if let record = TheMealDBCatalog.record(for: detail.id) {
            return DiscoveredRecipeDetail(
                id: detail.id,
                name: record.name,
                category: detail.category,
                area: detail.area,
                instructions: RecipeSanitizer.cleanInstructions(record.instructions, recipeName: record.name),
                ingredients: record.ingredients,
                thumbnailURL: detail.thumbnailURL,
                sourceURL: detail.sourceURL,
                youtubeURL: detail.youtubeURL,
                tags: detail.tags,
                illustrationIconID: detail.illustrationIconID
            )
        }

        // Fallback to dynamic translation
        let translatedIngredients = detail.ingredients.map(translateIngredient)
        let translatedInstructions = detail.instructions.map(translateInstruction)

        return DiscoveredRecipeDetail(
            id: detail.id,
            name: detail.name,
            category: detail.category,
            area: detail.area,
            instructions: RecipeSanitizer.cleanInstructions(translatedInstructions, recipeName: detail.name),
            ingredients: translatedIngredients,
            thumbnailURL: detail.thumbnailURL,
            sourceURL: detail.sourceURL,
            youtubeURL: detail.youtubeURL,
            tags: detail.tags,
            illustrationIconID: detail.illustrationIconID
        )
    }
}
