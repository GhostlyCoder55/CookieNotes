import * as SQLite from 'expo-sqlite';
import type { SQLiteDatabase } from 'expo-sqlite';

export type SQLExecutor = Pick<
  SQLiteDatabase,
  'runAsync' | 'getFirstAsync' | 'getAllAsync' | 'execAsync'
>;

const DATABASE_NAME = 'cookienotes.db';

let dbInstance: SQLiteDatabase | null = null;
let initPromise: Promise<SQLiteDatabase> | null = null;

const SCHEMA_SQL = `
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS recipes (
  recipe_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  ingredients_json TEXT NOT NULL DEFAULT '[]',
  instructions_json TEXT NOT NULL DEFAULT '[]',
  notes TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT '',
  prep_time INTEGER NOT NULL DEFAULT 0,
  cook_time INTEGER NOT NULL DEFAULT 0,
  servings INTEGER NOT NULL DEFAULT 0,
  is_sample INTEGER NOT NULL DEFAULT 0,
  is_imported INTEGER NOT NULL DEFAULT 0,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  category_raw TEXT NOT NULL DEFAULT 'uncategorized',
  ingredient_icon_ids_json TEXT NOT NULL DEFAULT '[]',
  cover_icon_id TEXT NOT NULL DEFAULT '',
  uses_category_cover INTEGER NOT NULL DEFAULT 0,
  catalog_recipe_id TEXT NOT NULL DEFAULT '',
  is_catalog_synced INTEGER NOT NULL DEFAULT 0,
  synced_english_name TEXT NOT NULL DEFAULT '',
  synced_english_ingredients_json TEXT NOT NULL DEFAULT '[]',
  synced_english_instructions_json TEXT NOT NULL DEFAULT '[]',
  date_created TEXT NOT NULL,
  date_modified TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS recipe_photos (
  photo_id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL REFERENCES recipes(recipe_id) ON DELETE CASCADE,
  sort_index INTEGER NOT NULL DEFAULT 0,
  image_uri TEXT NOT NULL,
  thumbnail_uri TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recipe_photos_recipe_id
  ON recipe_photos(recipe_id, sort_index);

CREATE TABLE IF NOT EXISTS grocery_items (
  item_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_checked INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  date_created TEXT NOT NULL,
  date_modified TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS mealdb_cache (
  cache_key TEXT PRIMARY KEY,
  payload_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
`;

export async function getDatabase(): Promise<SQLiteDatabase> {
  if (dbInstance) return dbInstance;
  if (!initPromise) {
    initPromise = (async () => {
      const db = await SQLite.openDatabaseAsync(DATABASE_NAME);
      await db.execAsync(SCHEMA_SQL);
      dbInstance = db;
      return db;
    })();
  }
  return initPromise;
}

export async function getCachedMealDBJson(cacheKey: string): Promise<string | null> {
  try {
    const db = await getDatabase();
    const row = await db.getFirstAsync<{ payload_json: string }>(
      'SELECT payload_json FROM mealdb_cache WHERE cache_key = ?',
      cacheKey
    );
    return row?.payload_json ?? null;
  } catch {
    return null;
  }
}

export async function setCachedMealDBJson(cacheKey: string, payloadJson: string): Promise<void> {
  try {
    const db = await getDatabase();
    await db.runAsync(
      'INSERT OR REPLACE INTO mealdb_cache (cache_key, payload_json, updated_at) VALUES (?, ?, ?)',
      cacheKey,
      payloadJson,
      Date.now()
    );
  } catch {
    // Non-fatal cache write error
  }
}
