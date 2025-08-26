#!/usr/bin/env node
import admin from 'firebase-admin';

const DRY_RUN = process.argv.includes('--dry-run');
const LIMIT_ARG = process.argv.find((a) => a.startsWith('--limit='));
const LIMIT = LIMIT_ARG ? parseInt(LIMIT_ARG.split('=')[1], 10) : undefined;

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'prayerbuddy-6ca4a',
});

const db = admin.firestore();

async function run() {
  const users = await db.collection('users').get();
  const now = admin.firestore.Timestamp.now();
  const docs = typeof LIMIT === 'number' ? users.docs.slice(0, LIMIT) : users.docs;
  console.log(`Resetting handle limits for ${docs.length} users ${DRY_RUN ? '(dry-run)' : ''}...`);

  let processed = 0;
  const chunkSize = 400; // stay under 500 ops per batch
  for (let i = 0; i < docs.length; i += chunkSize) {
    const chunk = docs.slice(i, i + chunkSize);
    const batch = db.batch();
    for (const doc of chunk) {
      const ref = db.collection('users').doc(doc.id);
      batch.set(
        ref,
        {
          handleChangeCount: 0,
          handleChangeResetAt: now,
        },
        { merge: true },
      );
    }
    if (!DRY_RUN) await batch.commit();
    processed += chunk.length;
    console.log(`Processed ${processed}/${docs.length}`);
  }

  console.log('Done.');
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});


