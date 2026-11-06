import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_DB = path.join(path.dirname(fileURLToPath(import.meta.url)), '../database/mountain_hut.db');

export function openDb(file = process.env.DB_PATH ?? DEFAULT_DB) {
  const db = new DatabaseSync(file);
  db.exec('PRAGMA foreign_keys = ON');
  return db;
}
