import { RecipeInputLimits } from '../constants/limits';
import { getActiveLanguage, tFor, type AppLanguage } from '../localization/i18n';
import type { GroceryItem, GrocerySort } from '../types/models';

export const GROCERY_SORTS: readonly GrocerySort[] = [
  'default',
  'uncheckedFirst',
  'alphabetical',
] as const;

export function parseGrocerySort(raw?: string | null): GrocerySort {
  if (!raw) return 'default';
  if ((GROCERY_SORTS as readonly string[]).includes(raw)) {
    return raw as GrocerySort;
  }
  return 'default';
}

export function getGrocerySortTitle(sort: GrocerySort, lang: AppLanguage = getActiveLanguage()): string {
  switch (sort) {
    case 'default':
      return tFor(lang, 'Default');
    case 'uncheckedFirst':
      return tFor(lang, 'Unchecked first');
    case 'alphabetical':
      return tFor(lang, 'A–Z');
  }
}

export function sanitizeGroceryName(raw: string): string {
  return raw.replace(/\r/g, ' ').replace(/\n/g, ' ').trim().slice(0, RecipeInputLimits.name);
}

function compareDefault(lhs: GroceryItem, rhs: GroceryItem): number {
  if (lhs.sortOrder !== rhs.sortOrder) {
    return lhs.sortOrder - rhs.sortOrder;
  }
  if (lhs.dateCreated !== rhs.dateCreated) {
    return lhs.dateCreated.localeCompare(rhs.dateCreated);
  }
  return lhs.itemID.localeCompare(rhs.itemID);
}

export function sortGroceryItems<T extends GroceryItem>(items: readonly T[], sort: GrocerySort): T[] {
  const copy = [...items];
  switch (sort) {
    case 'default':
      return copy.sort(compareDefault);
    case 'uncheckedFirst':
      return copy.sort((lhs, rhs) => {
        if (lhs.isChecked !== rhs.isChecked) {
          return lhs.isChecked ? 1 : -1;
        }
        return compareDefault(lhs, rhs);
      });
    case 'alphabetical':
      return copy.sort((lhs, rhs) => {
        const cmp = lhs.name.localeCompare(rhs.name, undefined, { sensitivity: 'base', numeric: true });
        if (cmp !== 0) return cmp;
        return compareDefault(lhs, rhs);
      });
  }
}

export function nextGrocerySortOrder(items: ReadonlyArray<Pick<GroceryItem, 'sortOrder'>>): number {
  if (items.length === 0) return 0;
  let maxOrder = -1;
  for (const item of items) {
    if (item.sortOrder > maxOrder) {
      maxOrder = item.sortOrder;
    }
  }
  return maxOrder + 1;
}
