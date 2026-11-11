import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { RecipeDraft, SharedRecipePayload } from '../types/models';
import { cleanRecipeDraft, sanitizeWebURL } from './recipeSanitizer';
import { parseRecipeText } from './recipeTextParser';

export function buildSharedRecipeDraft(
  payload: SharedRecipePayload,
  language: AppLanguage = getActiveLanguage()
): RecipeDraft {
  const parsed = parseRecipeText(payload.text);
  const title = payload.title.trim();
  const source = sanitizeWebURL(payload.url) ?? '';

  let name = title || parsed.name;
  if (!name || sanitizeWebURL(name) !== null) {
    if (source) {
      try {
        const host = new URL(source).hostname;
        if (host) name = host;
      } catch {
        // leave fallback below
      }
    }
  }
  if (!name) {
    name = tFor(language, 'Saved recipe');
  }

  let notes = parsed.notes;
  if (parsed.ingredients.length === 0 && parsed.instructions.length === 0 && !notes && source) {
    notes = tFor(language, "Saved from the web. Add the ingredients and steps when you're ready.");
  }

  return cleanRecipeDraft(
    {
      name,
      ingredients: parsed.ingredients,
      instructions: parsed.instructions,
      notes,
      source,
    },
    true
  );
}
