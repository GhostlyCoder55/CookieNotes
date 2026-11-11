import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { CuisineRegion } from '../types/models';

export const ALL_CUISINE_REGIONS: readonly CuisineRegion[] = [
  'African',
  'Asian',
  'Caribbean',
  'European',
  'Middle Eastern',
  'North American',
  'Oceania',
  'South American',
] as const;

export function getRegionTitle(region: CuisineRegion, lang: AppLanguage = getActiveLanguage()): string {
  return tFor(lang, region);
}

export function normalizeTaxonomyText(value: string): string {
  const withoutDiacritics = value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ');
  const tokens = withoutDiacritics.match(/[\p{L}\p{N}]+/gu);
  return tokens ? tokens.join(' ') : '';
}

const COUNTRY_AND_AREA_ALIASES: Record<string, string> = {
  // Africa
  algeria: 'Algerian', algerian: 'Algerian', algerie: 'Algerian', algerien: 'Algerian', algerienne: 'Algerian',
  argelia: 'Algerian', argelino: 'Algerian', argelina: 'Algerian',
  nigeria: 'Nigerian', nigerian: 'Nigerian', nigeriane: 'Nigerian', nigeriano: 'Nigerian', nigeriana: 'Nigerian',
  ghana: 'Ghanaian', ghanaian: 'Ghanaian', ghaneen: 'Ghanaian', ghaneenne: 'Ghanaian', ghanes: 'Ghanaian', ghanesa: 'Ghanaian',
  senegal: 'Senegalese', senegalese: 'Senegalese', senegalais: 'Senegalese', senegalaise: 'Senegalese', senegales: 'Senegalese', senegalesa: 'Senegalese',
  mali: 'Malian', malian: 'Malian', malien: 'Malian', malienne: 'Malian', maliense: 'Malian',
  cameroon: 'Cameroonian', cameroonian: 'Cameroonian', cameroun: 'Cameroonian', camerounais: 'Cameroonian', camerounaise: 'Cameroonian',
  camerun: 'Cameroonian', camerunes: 'Cameroonian', camerunesa: 'Cameroonian',
  'ivory coast': 'Ivorian', 'cote d ivoire': 'Ivorian', 'costa de marfil': 'Ivorian', ivorian: 'Ivorian', ivoirien: 'Ivorian', ivoirienne: 'Ivorian', marfileno: 'Ivorian',
  gambia: 'Gambian', gambian: 'Gambian', gambien: 'Gambian', gambiano: 'Gambian',
  egypt: 'Egyptian', egyptian: 'Egyptian', egypte: 'Egyptian', egyptien: 'Egyptian', egyptienne: 'Egyptian',
  egipto: 'Egyptian', egipcio: 'Egyptian', egipcia: 'Egyptian',
  morocco: 'Moroccan', moroccan: 'Moroccan', maroc: 'Moroccan', marocain: 'Moroccan', marocaine: 'Moroccan',
  marruecos: 'Moroccan', marroqui: 'Moroccan',
  tunisia: 'Tunisian', tunisian: 'Tunisian', tunisie: 'Tunisian', tunisien: 'Tunisian', tunisienne: 'Tunisian',
  tunez: 'Tunisian', tunecino: 'Tunisian', tunecina: 'Tunisian',
  kenya: 'Kenyan', kenyan: 'Kenyan', kenia: 'Kenyan', kenyanne: 'Kenyan', keniata: 'Kenyan',

  // Asia
  china: 'Chinese', chinese: 'Chinese', chine: 'Chinese', chinois: 'Chinese', chinoise: 'Chinese', chino: 'Chinese',
  japan: 'Japanese', japanese: 'Japanese', japon: 'Japanese', japonais: 'Japanese', japonaise: 'Japanese', japones: 'Japanese', japonesa: 'Japanese',
  thailand: 'Thai', thai: 'Thai', thailande: 'Thai', thailandais: 'Thai', thailandaise: 'Thai', tailandia: 'Thai', tailandes: 'Thai', tailandesa: 'Thai',
  vietnam: 'Vietnamese', vietnamese: 'Vietnamese', vietnamien: 'Vietnamese', vietnamienne: 'Vietnamese', vietnamita: 'Vietnamese',
  malaysia: 'Malaysian', malaysian: 'Malaysian', malaisie: 'Malaysian', malaisien: 'Malaysian', malasia: 'Malaysian', malasio: 'Malaysian',
  philippines: 'Filipino', filipino: 'Filipino', philippin: 'Filipino', philippine: 'Filipino', filipinas: 'Filipino', filipina: 'Filipino',
  india: 'Indian', indian: 'Indian', inde: 'Indian', indien: 'Indian', indienne: 'Indian', indio: 'Indian',
  korea: 'Korean', korean: 'Korean', corea: 'Korean', coreano: 'Korean', coreana: 'Korean', coree: 'Korean', coreen: 'Korean',

  // Middle East
  turkey: 'Turkish', turkish: 'Turkish', turquie: 'Turkish', turc: 'Turkish', turque: 'Turkish', turquia: 'Turkish', turco: 'Turkish', turca: 'Turkish',
  syria: 'Syrian', syrian: 'Syrian', syrie: 'Syrian', syrien: 'Syrian', siria: 'Syrian', sirio: 'Syrian',
  yemen: 'Yemeni', yemeni: 'Yemeni', yemenite: 'Yemeni', yemeni_es: 'Yemeni',
  saudi: 'Saudi Arabian', 'saudi arabia': 'Saudi Arabian', 'arabie saoudite': 'Saudi Arabian', saoudien: 'Saudi Arabian',
  'arabia saudita': 'Saudi Arabian', 'arabia saudi': 'Saudi Arabian', saudita: 'Saudi Arabian',

  // North America
  mexico: 'Mexican', mexican: 'Mexican', mexique: 'Mexican', mexicain: 'Mexican', mexicaine: 'Mexican', mexicano: 'Mexican', mexicana: 'Mexican',
  america: 'American', american: 'American', 'etats unis': 'American', 'etats-unis': 'American', americain: 'American', americaine: 'American',
  usa: 'American', 'united states': 'American', 'estados unidos': 'American', eeuu: 'American', estadounidense: 'American', americano: 'American', americana: 'American',
  canada: 'Canadian', canadian: 'Canadian', canadien: 'Canadian', canadienne: 'Canadian', canadiense: 'Canadian',

  // South America
  argentina: 'Argentinian', argentinian: 'Argentinian', argentine: 'Argentinian', argentino: 'Argentinian',
  uruguay: 'Uruguayan', uruguayan: 'Uruguayan', uruguayen: 'Uruguayan', uruguayenne: 'Uruguayan', uruguayo: 'Uruguayan', uruguaya: 'Uruguayan',
  venezuela: 'Venezuelan', venezuelan: 'Venezuelan', venezolano: 'Venezuelan', venezolana: 'Venezuelan',

  // Caribbean
  jamaica: 'Jamaican', jamaican: 'Jamaican', jamaique: 'Jamaican', jamaicain: 'Jamaican', jamaicaine: 'Jamaican', jamaicano: 'Jamaican', jamaicana: 'Jamaican',
  caribbean: 'Caribbean', caraibes: 'Caribbean', caribeen: 'Caribbean', caribeenne: 'Caribbean', caribe: 'Caribbean', caribeno: 'Caribbean', caribena: 'Caribbean',
  'puerto rico': 'Puerto Rican', 'puerto rican': 'Puerto Rican', puertorriqueno: 'Puerto Rican',
  cuba: 'Cuban', cuban: 'Cuban', cubain: 'Cuban', cubaine: 'Cuban', cubano: 'Cuban', cubana: 'Cuban',
  haiti: 'Haitian', haitian: 'Haitian', haitien: 'Haitian', haitienne: 'Haitian', haitiano: 'Haitian', haitiana: 'Haitian',

  // Europe
  italy: 'Italian', italian: 'Italian', italie: 'Italian', italien: 'Italian', italienne: 'Italian', italia: 'Italian', italiano: 'Italian', italiana: 'Italian',
  france: 'French', french: 'French', francais: 'French', francaise: 'French', francia: 'French', frances: 'French', francesa: 'French',
  uk: 'British', british: 'British', england: 'British', 'united kingdom': 'British', 'reino unido': 'British', inglaterra: 'British',
  britannique: 'British', angleterre: 'British', anglais: 'British', anglaise: 'British', britanico: 'British', britanica: 'British', ingles: 'British', inglesa: 'British',
  spain: 'Spanish', spanish: 'Spanish', espagne: 'Spanish', espagnol: 'Spanish', espagnole: 'Spanish', espana: 'Spanish', espanol: 'Spanish', espanola: 'Spanish',
  greece: 'Greek', greek: 'Greek', grece: 'Greek', grec: 'Greek', grecque: 'Greek', grecia: 'Greek', griego: 'Greek', griega: 'Greek',
  croatia: 'Croatian', croatian: 'Croatian', croatie: 'Croatian', croate: 'Croatian', croacia: 'Croatian', croata: 'Croatian',
  ireland: 'Irish', irish: 'Irish', irlande: 'Irish', irlandais: 'Irish', irlandaise: 'Irish', irlanda: 'Irish', irlandes: 'Irish', irlandesa: 'Irish',
  dutch: 'Dutch', holland: 'Dutch', netherlands: 'Dutch', 'pays bas': 'Dutch', neerlandais: 'Dutch', neerlandaise: 'Dutch',
  'paises bajos': 'Dutch', holanda: 'Dutch', holandes: 'Dutch', neerlandes: 'Dutch',
  poland: 'Polish', polish: 'Polish', pologne: 'Polish', polonais: 'Polish', polonaise: 'Polish', polonia: 'Polish', polaco: 'Polish', polaca: 'Polish',
  portugal: 'Portuguese', portuguese: 'Portuguese', portugais: 'Portuguese', portugaise: 'Portuguese', portugues: 'Portuguese', portuguesa: 'Portuguese',
  russia: 'Russian', russian: 'Russian', russie: 'Russian', russe: 'Russian', rusia: 'Russian', ruso: 'Russian', rusa: 'Russian',
  ukraine: 'Ukrainian', ukrainian: 'Ukrainian', ukrainien: 'Ukrainian', ukrainienne: 'Ukrainian', ucrania: 'Ukrainian', ucraniano: 'Ukrainian', ucraniana: 'Ukrainian',
  norway: 'Norwegian', norwegian: 'Norwegian', norvege: 'Norwegian', noruega: 'Norwegian', noruego: 'Norwegian',
  slovakia: 'Slovak', slovak: 'Slovak', slovaquie: 'Slovak', eslovaquia: 'Slovak', eslovaco: 'Slovak',

  // Oceania
  australia: 'Australian', australian: 'Australian', australie: 'Australian', australien: 'Australian', australienne: 'Australian', australiano: 'Australian', australiana: 'Australian',
};

const LOCAL_AREA_COUNTRIES: Record<string, string> = {
  american: 'united states',
  canadian: 'canada',
  french: 'france',
  ghanaian: 'ghana',
  jamaican: 'jamaica',
  mexican: 'mexico',
  nigerian: 'nigeria',
  senegalese: 'senegal',
  caribbean: 'caribbean',
};

const LOCAL_AREA_REGIONS: Record<string, CuisineRegion> = {
  algerian: 'African',
  american: 'North American',
  canadian: 'North American',
  mexican: 'North American',
  french: 'European',
  ghanaian: 'African',
  nigerian: 'African',
  senegalese: 'African',
  jamaican: 'Caribbean',
  caribbean: 'Caribbean',
  cameroonian: 'African',
  egyptian: 'African',
  moroccan: 'African',
  tunisian: 'African',
  kenyan: 'African',
  ethiopian: 'African',
  'south african': 'African',
  chinese: 'Asian',
  japanese: 'Asian',
  thai: 'Asian',
  vietnamese: 'Asian',
  malaysian: 'Asian',
  filipino: 'Asian',
  indian: 'Asian',
  korean: 'Asian',
  turkish: 'Middle Eastern',
  syrian: 'Middle Eastern',
  'saudi arabian': 'Middle Eastern',
  yemeni: 'Middle Eastern',
  lebanese: 'Middle Eastern',
  iraqi: 'Middle Eastern',
  iranian: 'Middle Eastern',
  british: 'European',
  argentinian: 'South American',
  uruguayan: 'South American',
  venezuelan: 'South American',
  norwegian: 'European',
  slovak: 'European',
};

const REGION_COUNTRY_ASSIGNMENTS: Array<[CuisineRegion, string[]]> = [
  [
    'African',
    [
      'Algeria', 'Benin', 'Burkina Faso', 'Burundi', 'Cameroon', 'Cape Verde', 'Central African Republic',
      'Chad', 'Comoros', "Côte d'Ivoire", 'Djibouti', 'DR Congo', 'Egypt', 'Equatorial Guinea',
      'Eritrea', 'Eswatini', 'Ethiopia', 'Gabon', 'Gambia', 'Ghana', 'Guinea',
      'Guinea-Bissau', 'Kenya', 'Lesotho', 'Liberia', 'Libya', 'Madagascar', 'Malawi',
      'Mali', 'Mauritania', 'Mauritius', 'Morocco', 'Mozambique', 'Namibia', 'Niger',
      'Nigeria', 'Republic of the Congo', 'Rwanda', 'São Tomé and Príncipe', 'Senegal',
      'Seychelles', 'Sierra Leone', 'Somalia', 'South Africa', 'South Sudan', 'Sudan',
      'Tanzania', 'Togo', 'Tunisia', 'Uganda', 'Zambia', 'Zimbabwe', 'Angola', 'Botswana',
    ],
  ],
  [
    'Asian',
    [
      'Afghanistan', 'Armenia', 'Azerbaijan', 'Bangladesh', 'Bhutan', 'Brunei', 'Cambodia',
      'China', 'Georgia', 'Hong Kong', 'India', 'Indonesia', 'Japan', 'Kazakhstan',
      'Kyrgyzstan', 'Laos', 'Malaysia', 'Maldives', 'Mongolia', 'Myanmar', 'Nepal',
      'North Korea', 'Pakistan', 'Philippines', 'Singapore', 'South Korea', 'Sri Lanka',
      'Taiwan', 'Tajikistan', 'Thailand', 'Timor-Leste', 'Turkmenistan', 'Uzbekistan', 'Vietnam',
    ],
  ],
  [
    'Middle Eastern',
    [
      'Bahrain', 'Iran', 'Iraq', 'Israel', 'Jordan', 'Kuwait', 'Lebanon', 'Oman',
      'Palestine', 'Qatar', 'Saudi Arabia', 'Syria', 'Turkey', 'United Arab Emirates', 'Yemen',
    ],
  ],
  [
    'European',
    [
      'Albania', 'Andorra', 'Austria', 'Belarus', 'Belgium', 'Bosnia and Herzegovina',
      'Bulgaria', 'Croatia', 'Cyprus', 'Czechia', 'Denmark', 'Estonia', 'Faroe Islands', 'Finland',
      'France', 'Germany', 'Greece', 'Hungary', 'Iceland', 'Ireland', 'Italy', 'Kosovo',
      'Gibraltar', 'Guernsey', 'Jersey', 'Latvia', 'Liechtenstein', 'Lithuania', 'Luxembourg',
      'Malta', 'Moldova', 'Monaco', 'Montenegro', 'Netherlands', 'North Macedonia', 'Norway', 'Poland', 'Portugal',
      'Romania', 'Russia', 'San Marino', 'Serbia', 'Slovakia', 'Slovenia', 'Spain',
      'Sweden', 'Switzerland', 'Ukraine', 'United Kingdom', 'Vatican City',
    ],
  ],
  [
    'North American',
    [
      'Belize', 'Bermuda', 'Canada', 'Costa Rica', 'El Salvador', 'Greenland', 'Guatemala',
      'Honduras', 'Mexico', 'Nicaragua', 'Panama', 'United States',
    ],
  ],
  [
    'South American',
    [
      'Argentina', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Ecuador', 'French Guiana',
      'Guyana', 'Paraguay', 'Peru', 'Suriname', 'Uruguay', 'Venezuela',
    ],
  ],
  [
    'Caribbean',
    [
      'Antigua and Barbuda', 'Anguilla', 'Aruba', 'Bahamas', 'Barbados', 'Cayman Islands',
      'Cuba', 'Dominica', 'Dominican Republic', 'Grenada', 'Guadeloupe', 'Haiti', 'Jamaica',
      'Martinique', 'Puerto Rico', 'Saint Lucia', 'Saint Vincent and the Grenadines',
      'Trinidad and Tobago',
    ],
  ],
  [
    'Oceania',
    [
      'Australia', 'Fiji', 'Guam', 'New Zealand', 'Papua New Guinea', 'Samoa',
      'Solomon Islands', 'Tonga', 'Tuvalu', 'Vanuatu',
    ],
  ],
];

const COUNTRY_REGIONS: Record<string, CuisineRegion> = (() => {
  const result: Record<string, CuisineRegion> = {};
  for (const [region, countries] of REGION_COUNTRY_ASSIGNMENTS) {
    for (const country of countries) {
      result[normalizeTaxonomyText(country)] = region;
    }
  }
  result['ivory coast'] = 'African';
  result['cote d ivoire'] = 'African';
  result['dr congo'] = 'African';
  result['republic of the congo'] = 'African';
  result['united states of america'] = 'North American';
  result['uk'] = 'European';
  return result;
})();

export function getRegionForArea(area: string, country?: string | null): CuisineRegion | null {
  if (country) {
    const byCountry = COUNTRY_REGIONS[normalizeTaxonomyText(country)];
    if (byCountry) return byCountry;
  }
  const areaKey = normalizeTaxonomyText(area);
  if (LOCAL_AREA_REGIONS[areaKey]) {
    return LOCAL_AREA_REGIONS[areaKey];
  }
  const localCountry = LOCAL_AREA_COUNTRIES[areaKey];
  if (localCountry && COUNTRY_REGIONS[normalizeTaxonomyText(localCountry)]) {
    return COUNTRY_REGIONS[normalizeTaxonomyText(localCountry)];
  }
  const canonicalArea = COUNTRY_AND_AREA_ALIASES[areaKey];
  if (canonicalArea) {
    const canonicalKey = normalizeTaxonomyText(canonicalArea);
    if (LOCAL_AREA_REGIONS[canonicalKey]) {
      return LOCAL_AREA_REGIONS[canonicalKey];
    }
    const mappedCountry = LOCAL_AREA_COUNTRIES[canonicalKey];
    if (mappedCountry && COUNTRY_REGIONS[normalizeTaxonomyText(mappedCountry)]) {
      return COUNTRY_REGIONS[normalizeTaxonomyText(mappedCountry)];
    }
  }
  return null;
}

export function getCanonicalArea(query: string): string | null {
  return COUNTRY_AND_AREA_ALIASES[normalizeTaxonomyText(query)] ?? null;
}

export function getSearchTermsForArea(area: string): string[] {
  const key = normalizeTaxonomyText(area);
  if (!LOCAL_AREA_COUNTRIES[key]) return [area];
  const terms = [area];
  for (const [alias, canonical] of Object.entries(COUNTRY_AND_AREA_ALIASES)) {
    if (canonical === area) {
      terms.push(alias);
    }
  }
  return terms;
}
