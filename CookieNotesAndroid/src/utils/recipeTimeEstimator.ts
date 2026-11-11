import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { RecipeTimeEstimate } from '../types/models';

const PASSIVE_WORDS = new Set([
  // English
  'marinate', 'marinated', 'marinating', 'chill', 'chilled', 'chilling',
  'refrigerate', 'refrigerated', 'refrigerator', 'fridge', 'freeze', 'freezer',
  'rest', 'resting', 'soak', 'soaking', 'stand', 'standing', 'cool', 'cooling',
  'prove', 'proving', 'rise', 'steep', 'steeping', 'overnight',
  // French
  'marinade', 'mariner', 'refroidir', 'refroidissez', 'tiédir',
  'réfrigérer', 'réfrigérez', 'frigo', 'réfrigérateur', 'congeler', 'congelez', 'congélateur',
  'repos', 'reposer', 'reposez', 'tremper', 'trempez', 'macérer', 'lever', 'pousser',
  'infuser', 'infusez',
  // Spanish
  'marinar', 'marinado', 'enfriar', 'enfríe', 'enfriando',
  'refrigerar', 'refrigera', 'refrigerador', 'nevera', 'congelar', 'congela', 'congelador',
  'reposar', 'reposando', 'reposo', 'remojar', 'remojando', 'infusionar',
]);

const HEAT_PREFIXES = [
  // English
  'bak', 'boil', 'simmer', 'fry', 'fried', 'roast', 'grill', 'cook', 'saut',
  'sear', 'brown', 'oven', 'heat', 'steam', 'poach', 'broil', 'toast', 'stew',
  // French
  'cuir', 'cuis', 'bouill', 'mijot', 'frir', 'rôt', 'gril', 'sais', 'dor', 'four', 'chauff', 'vapeur', 'poch', 'brais',
  // Spanish
  'horne', 'herv', 'hirv', 'cocin', 'cocer', 'cuec', 'freir', 'frit', 'asar', 'asand', 'parrill', 'planch',
  'salte', 'calent', 'vapor', 'escalf', 'estof', 'guis',
];

const NUMBER_WORDS: Record<string, number> = {
  // English
  a: 1, an: 1, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6,
  seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12,
  fifteen: 15, twenty: 20, thirty: 30, forty: 40, 'forty-five': 45,
  sixty: 60, few: 3, 'a few': 3, 'couple of': 2, 'a couple of': 2, several: 4,
  'half an': 0.5, 'half a': 0.5,
  // French
  un: 1, une: 1, deux: 2, trois: 3, quatre: 4, cinq: 5,
  sept: 7, huit: 8, neuf: 9, dix: 10, onze: 11, douze: 12,
  quinze: 15, vingt: 20, trente: 30, quarante: 40, 'quarante-cinq': 45,
  soixante: 60, quelques: 3, plusieurs: 4, demi: 0.5, 'une demi': 0.5,
  // Spanish
  uno: 1, una: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5, seis: 6,
  siete: 7, ocho: 8, nueve: 9, diez: 10, once: 11, doce: 12,
  quince: 15, veinte: 20, treinta: 30, cuarenta: 40, 'cuarenta y cinco': 45,
  sesenta: 60, algunos: 3, unas: 3, varios: 4, media: 0.5, medio: 0.5, 'un par de': 2,
};

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const DURATION_REGEX: RegExp = (() => {
  const words = Object.keys(NUMBER_WORDS)
    .sort((a, b) => b.length - a.length)
    .map(escapeRegExp)
    .join('|');
  const numExpr = `(\\d+(?:[.,]\\d+)?|${words})`;
  const pattern = `(?:^|[^\\w-])(${numExpr})(?:\\s*(?:-|–|to|or|à|a|y|et)\\s*(${numExpr}))?\\s*(?:more\\s+|extra\\s+|further\\s+|de\\s+plus\\s+|environ\\s+|más\\s+|aproximadamente\\s+)?(hours?|heures?|horas?|hrs?|h|minutes?|minutos?|mins?)\\b`;
  return new RegExp(pattern, 'gi');
})();

function tokenValue(token?: string): number | null {
  if (!token) return null;
  const cleaned = token.trim().replace(',', '.').toLowerCase();
  if (cleaned in NUMBER_WORDS) return NUMBER_WORDS[cleaned];
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

function extractDurations(sentence: string): number[] {
  const results: number[] = [];
  DURATION_REGEX.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = DURATION_REGEX.exec(sentence)) !== null) {
    const low = match[1];
    const high = match[3];
    const unit = (match[5] ?? '').toLowerCase();
    const amount = tokenValue(high) ?? tokenValue(low);
    if (amount === null) continue;
    const minutes = unit.startsWith('h') ? amount * 60 : amount;
    if (minutes > 0 && minutes <= 24 * 60) {
      results.push(Math.round(minutes));
    }
  }
  return results;
}

function splitSentences(instructions: string[]): string[] {
  const result: string[] = [];
  for (const step of instructions) {
    const parts = step.split(/[.!?;\n]/);
    for (const part of parts) {
      const trimmed = part.trim();
      if (trimmed) result.push(trimmed);
    }
  }
  return result;
}

function fallbackCookMinutes(category?: string | null): number {
  switch (category?.trim().toLowerCase()) {
    case 'beef':
    case 'lamb':
    case 'goat':
      return 60;
    case 'pork':
      return 45;
    case 'chicken':
      return 40;
    case 'seafood':
    case 'pasta':
      return 20;
    case 'breakfast':
      return 15;
    case 'dessert':
    case 'vegetarian':
    case 'vegan':
      return 30;
    default:
      return 30;
  }
}

function roundToFive(minutes: number): number {
  if (minutes <= 0) return 0;
  return Math.max(5, Math.round(minutes / 5) * 5);
}

export function estimateRecipeTime(
  instructions: string[],
  ingredientCount: number,
  category?: string | null
): RecipeTimeEstimate {
  let passive = 0;
  let cook = 0;
  let mentionsHeat = false;
  const allSentences = splitSentences(instructions);

  for (const sentence of allSentences) {
    const lowered = sentence.toLowerCase();
    let minutes = extractDurations(lowered).reduce((acc, cur) => acc + cur, 0);

    if (
      minutes === 0 &&
      ((lowered.includes('according to') &&
        (lowered.includes('pack') || lowered.includes('instruction') || lowered.includes('directions'))) ||
        (lowered.includes('selon') &&
          (lowered.includes('emballage') || lowered.includes('paquet') || lowered.includes('instructions'))) ||
        ((lowered.includes('según') || lowered.includes('segun')) &&
          (lowered.includes('paquete') || lowered.includes('envase') || lowered.includes('instrucciones'))))
    ) {
      minutes = 10;
    }

    const words = lowered.match(/\p{L}+/gu) ?? [];
    const isPassive =
      words.some((word) => PASSIVE_WORDS.has(word)) &&
      !lowered.includes('rest of') &&
      !lowered.includes('reste de') &&
      !lowered.includes('reste du') &&
      !lowered.includes('reste des') &&
      !lowered.includes('resto de');

    if (words.some((word) => HEAT_PREFIXES.some((prefix) => word.startsWith(prefix)))) {
      mentionsHeat = true;
    }

    if (
      lowered.includes('overnight') ||
      lowered.includes('toute la nuit') ||
      lowered.includes("jusqu'au lendemain") ||
      lowered.includes('toda la noche') ||
      lowered.includes('hasta el día siguiente')
    ) {
      passive += 8 * 60;
    }

    if (minutes <= 0) continue;
    if (isPassive) {
      passive += minutes;
    } else {
      cook += minutes;
    }
  }

  if (cook === 0 && (mentionsHeat || allSentences.length < 3)) {
    cook = fallbackCookMinutes(category);
  }
  cook = Math.min(roundToFive(cook), 12 * 60);

  const stepCount = Math.max(instructions.length, 1);
  const active = 5 + ingredientCount * 1.5 + Math.min(stepCount, 12);
  const prep = Math.min(Math.max(roundToFive(Math.round(active)), 5), 45) + Math.min(roundToFive(passive), 24 * 60);

  return { prep, cook };
}

export function formatDurationShort(
  minutes: number,
  lang: AppLanguage = getActiveLanguage()
): string {
  if (minutes <= 0) return tFor(lang, '0 min');
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) return tFor(lang, '%lld min', rest);
  if (rest === 0) return tFor(lang, '%lld hr', hours);
  return tFor(lang, '%lld hr %lld min', hours, rest);
}
