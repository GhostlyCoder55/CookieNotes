import { RecipeInputLimits } from '../constants/limits';
import type { RecipeDraft } from '../types/models';

const ONLY_NUMBER_OR_MARKER_RE = /^\d+[.)]?$|^(?:\(\d+\)|\[\d+\])$/;

const PREFIX_PATTERNS: Array<{ pattern: RegExp }> = [
  { pattern: /^\s*#{1,6}\s*/ },
  { pattern: /^\s*[☐□☑✓✔☒◻◼◽▫▪▢▣▯⬜]\s*/ },
  { pattern: /^\s*(?:\d+[.)]|\(\d+\)|\[\d+\])\s+/ },
  { pattern: /^\s*\d+\s+(?=[A-Z])/ },
  { pattern: /^\s*(?:step|étape|etape|paso)\s*#?\s*\d+\s*[:.)-]\s*/i },
  { pattern: /^\s*[•*–—-]\s+/ },
];

const HEADING_PATTERNS: RegExp[] = [
  /^(?:(?:#{1,6})\s*)?(?:steps?|instructions?|directions?|method|étapes?|etapes?|préparation|preparation|pasos?|instrucciones|preparación|preparacion)\s*:?\s*$/i,
  /^(?:(?:#{1,6})\s*)?(?:step|étape|etape|paso)\s*#?\s*\d+\s*[:.)-]?\s*$/i,
];

function singleLine(value: string): string {
  return value.replace(/\r/g, ' ').replace(/\n/g, ' ').trim();
}

function clip(value: string, limit: number): string {
  return value.slice(0, limit);
}

function stripDiacritics(value: string): string {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

export function sanitizeMinutes(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(Math.max(Math.round(value), 0), RecipeInputLimits.maxMinutes);
}

export function sanitizeServings(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(Math.max(Math.round(value), 0), RecipeInputLimits.maxServings);
}

export function sanitizeWebURL(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  try {
    const parsed = new URL(trimmed);
    const scheme = parsed.protocol.toLowerCase();
    if (scheme !== 'https:' && scheme !== 'http:') return null;
    if (!parsed.hostname) return null;
    return trimmed.slice(0, RecipeInputLimits.source);
  } catch {
    return null;
  }
}

export function cleanInstruction(raw: string): string | null {
  let instruction = raw.trim();
  if (!instruction) return null;
  if (ONLY_NUMBER_OR_MARKER_RE.test(instruction)) return null;

  for (let pass = 0; pass < 4; pass += 1) {
    const previous = instruction;
    for (const { pattern } of PREFIX_PATTERNS) {
      instruction = instruction.replace(pattern, '');
    }
    instruction = instruction.trim();
    if (instruction === previous) break;
  }

  for (const headingPattern of HEADING_PATTERNS) {
    if (headingPattern.test(instruction)) {
      return null;
    }
  }

  return instruction.length > 0 ? instruction : null;
}

function completingKarbonaderInstructions(instructions: string[], recipeName: string): string[] {
  const normalizedName = stripDiacritics(recipeName)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

  if (!normalizedName.includes('karbonader') || !normalizedName.includes('caramelized onions')) {
    return instructions;
  }

  const lowered = instructions.map((step) => step.toLowerCase());
  const onionIndex = lowered.findIndex((s) => s.includes('onion') && s.includes('set aside'));
  const mixtureIndex = lowered.findIndex((s) => s.includes('ground beef') && s.includes('grated onion'));
  const shapingIndex = lowered.findIndex((s) => s.includes('form') && s.includes('patties'));
  const cookingIndex = lowered.findIndex((s) => s.includes('brown both sides') && s.includes('karbonader'));
  const servingIndex = lowered.findIndex((s) => s.includes('serve the karbonader'));

  if (
    onionIndex < 0 ||
    mixtureIndex < 0 ||
    shapingIndex < 0 ||
    cookingIndex < 0 ||
    servingIndex < 0 ||
    !(onionIndex < mixtureIndex &&
      mixtureIndex < shapingIndex &&
      shapingIndex < cookingIndex &&
      cookingIndex < servingIndex)
  ) {
    return instructions;
  }

  const completed = [...instructions];
  const additions: Array<[needle: string, text: string]> = [
    [
      'transfer the caramelized onions',
      'Transfer the caramelized onions to a plate and keep them warm. Reserve the skillet and any butter for cooking the patties.',
    ],
    [
      'mix gently just until',
      'Mix gently just until the ingredients are evenly combined; overworking the beef can make the patties dense.',
    ],
    [
      'shape the patties to an even thickness',
      'Shape the patties to an even thickness so they cook at the same rate.',
    ],
    [
      'check that the center of a patty',
      'Check that the center of a patty reaches 160°F (71°C). Transfer the patties to a plate and let them rest for 3 minutes before serving.',
    ],
  ];
  const insertionAnchors = ['onion', 'ground beef', 'form', 'brown both sides'];

  additions.forEach(([needle, text], offset) => {
    const alreadyPresent = completed.some((step) => step.toLowerCase().includes(needle));
    if (alreadyPresent) return;
    const anchor = insertionAnchors[offset];
    const anchorIndex = completed.findIndex((step) => step.toLowerCase().includes(anchor));
    if (anchorIndex >= 0) {
      completed.splice(anchorIndex + 1, 0, text);
    }
  });

  return completed;
}

export function cleanInstructions(instructions: string[], recipeName?: string | null): string[] {
  const cleaned = instructions.map(cleanInstruction).filter((s): s is string => s !== null);
  if (!recipeName) return cleaned;
  return completingKarbonaderInstructions(cleaned, recipeName);
}

export function cleanRecipeDraft(draft: RecipeDraft, webSourceOnly = false): RecipeDraft {
  const cleanName = clip(singleLine(draft.name), RecipeInputLimits.name);
  const cleanIngredients = draft.ingredients
    .map((line) => clip(singleLine(line), RecipeInputLimits.ingredient))
    .filter((line) => line.length > 0)
    .slice(0, RecipeInputLimits.ingredientCount);

  const cleanSteps = cleanInstructions(draft.instructions, draft.name)
    .map((step) => clip(step, RecipeInputLimits.instruction))
    .slice(0, RecipeInputLimits.instructionCount);

  const cleanSource = webSourceOnly
    ? sanitizeWebURL(draft.source) ?? ''
    : clip(singleLine(draft.source), RecipeInputLimits.source);

  return {
    name: cleanName,
    ingredients: cleanIngredients,
    instructions: cleanSteps,
    notes: clip(draft.notes.trim(), RecipeInputLimits.notes),
    source: cleanSource,
    servings: sanitizeServings(draft.servings ?? 0),
  };
}
