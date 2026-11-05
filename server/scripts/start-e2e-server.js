// Starts the real API for the end-to-end tests (client/e2e_test) on a fresh,
// throw-away database built from database/schema.sql + database/seed.sql.
// The development database (database/mountain_hut.db) is never touched.
//
// Usage (from the server folder):  npm run start:e2e
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const databaseDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../database');
const file = path.join(os.tmpdir(), 'mountain-hut-e2e.db');

for (const f of [file, `${file}-wal`, `${file}-shm`]) fs.rmSync(f, { force: true });

const db = new DatabaseSync(file);
db.exec(fs.readFileSync(path.join(databaseDir, 'schema.sql'), 'utf8'));
db.exec('PRAGMA foreign_keys = ON');
db.exec(fs.readFileSync(path.join(databaseDir, 'seed.sql'), 'utf8'));
db.close();

process.env.DB_PATH = file;
// Works without a .env file; emails are never sent during E2E runs.
process.env.SESSION_SECRET ??= 'e2e-only-session-secret-0123456789abcdef';
process.env.MAIL_MODE = 'disabled';

console.log(`E2E database: ${file}`);
await import('../index.js');
