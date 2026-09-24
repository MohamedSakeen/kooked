/**
 * Firestore Recipe Import Script
 *
 * Usage:
 *   1. Set FIREBASE_SERVICE_ACCOUNT env var to path of service account JSON
 *   2. node scripts/import_recipes.js
 *
 * Requires: firebase-admin, fs
 */
import 'dotenv/config';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!serviceAccountPath) {
  console.error('Set FIREBASE_SERVICE_ACCOUNT env var to your service account JSON path');
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf-8'));

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function importRecipes() {
  const recipesPath = join(__dirname, '..', 'data', 'seed_recipes.json');
  const recipes = JSON.parse(readFileSync(recipesPath, 'utf-8'));

  console.log(`Importing ${recipes.length} recipes...`);

  const batch = db.batch();
  const collection = db.collection('recipes');

  for (const recipe of recipes) {
    const doc = collection.doc();
    batch.set(doc, {
      ...recipe,
      isAiGenerated: false,
      createdAt: new Date().toISOString(),
    });
  }

  await batch.commit();
  console.log(`Successfully imported ${recipes.length} recipes.`);
  process.exit(0);
}

importRecipes().catch((err) => {
  console.error('Import failed:', err);
  process.exit(1);
});
