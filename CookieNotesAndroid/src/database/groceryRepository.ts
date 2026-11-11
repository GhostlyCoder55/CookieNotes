import type { GroceryItem } from '../types/models';
import { nextGrocerySortOrder, sanitizeGroceryName } from '../utils/groceryListLogic';
import { generateUUID } from '../utils/uuid';
import { getDatabase, type SQLExecutor } from './db';

interface GroceryRow {
  item_id: string;
  name: string;
  is_checked: number;
  sort_order: number;
  date_created: string;
  date_modified: string;
}

function rowToItem(row: GroceryRow): GroceryItem {
  return {
    itemID: row.item_id,
    name: row.name,
    isChecked: row.is_checked === 1,
    sortOrder: row.sort_order,
    dateCreated: row.date_created,
    dateModified: row.date_modified,
  };
}

export async function fetchAllGroceryItems(executor?: SQLExecutor): Promise<GroceryItem[]> {
  const db = executor ?? (await getDatabase());
  const rows = await db.getAllAsync<GroceryRow>(
    'SELECT item_id, name, is_checked, sort_order, date_created, date_modified FROM grocery_items ORDER BY sort_order ASC, date_created ASC'
  );
  return rows.map(rowToItem);
}

export async function addGroceryItem(rawName: string): Promise<GroceryItem | null> {
  const cleaned = sanitizeGroceryName(rawName);
  if (!cleaned) return null;

  const db = await getDatabase();
  const existing = await fetchAllGroceryItems(db);
  const now = new Date().toISOString();
  const item: GroceryItem = {
    itemID: generateUUID(),
    name: cleaned,
    isChecked: false,
    sortOrder: nextGrocerySortOrder(existing),
    dateCreated: now,
    dateModified: now,
  };

  await db.runAsync(
    `INSERT INTO grocery_items (item_id, name, is_checked, sort_order, date_created, date_modified)
     VALUES (?, ?, ?, ?, ?, ?)`,
    item.itemID,
    item.name,
    0,
    item.sortOrder,
    item.dateCreated,
    item.dateModified
  );

  return item;
}

export async function toggleGroceryItem(itemID: string, nextChecked: boolean): Promise<void> {
  const db = await getDatabase();
  const now = new Date().toISOString();
  await db.runAsync(
    'UPDATE grocery_items SET is_checked = ?, date_modified = ? WHERE item_id = ?',
    nextChecked ? 1 : 0,
    now,
    itemID
  );
}

export async function updateGroceryItemName(itemID: string, rawName: string): Promise<string | null> {
  const cleaned = sanitizeGroceryName(rawName);
  if (!cleaned) return null;
  const db = await getDatabase();
  const now = new Date().toISOString();
  await db.runAsync(
    'UPDATE grocery_items SET name = ?, date_modified = ? WHERE item_id = ?',
    cleaned,
    now,
    itemID
  );
  return cleaned;
}

export async function deleteGroceryItem(itemID: string): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('DELETE FROM grocery_items WHERE item_id = ?', itemID);
}

export async function clearCheckedGroceryItems(): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('DELETE FROM grocery_items WHERE is_checked = 1');
}

export async function clearAllGroceryItems(): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('DELETE FROM grocery_items');
}
