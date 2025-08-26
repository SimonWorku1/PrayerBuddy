#!/usr/bin/env node
import admin from 'firebase-admin';

const DRY_RUN = process.argv.includes('--dry-run');
const LIMIT_ARG = process.argv.find((a) => a.startsWith('--limit='));
const LIMIT = LIMIT_ARG ? parseInt(LIMIT_ARG.split('=')[1], 10) : undefined;

// Initialize Admin SDK using ADC or service account pointed to by
// GOOGLE_APPLICATION_CREDENTIALS. Set project explicitly as a safeguard.
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'prayerbuddy-6ca4a',
});

const db = admin.firestore();

function isPlaceholderUser(data) {
  const isFlagged = data.isPlaceholder === true;
  const name = (data.name || '').toString().trim();
  const handle = (data.handle || '').toString().trim();
  const email = (data.email || '').toString().trim();
  const phone = (data.phone || '').toString().trim();
  const minimal = (name === '' || name.toLowerCase() === 'user') &&
                  handle === '' && email === '' && phone === '';
  return isFlagged || minimal;
}

async function deleteFriendLinksFor(uid) {
  const idField = admin.firestore.FieldPath.documentId();
  const cg = await db.collectionGroup('friends').where(idField, '==', uid).get();
  const batch = db.batch();
  cg.docs.forEach((d) => batch.delete(d.ref));
  if (!DRY_RUN && cg.size > 0) await batch.commit();
  return cg.size;
}

async function deleteFriendRequestsFor(uid) {
  const out = { from: 0, to: 0 };
  const q1 = await db.collection('friend_requests').where('from', '==', uid).get();
  const q2 = await db.collection('friend_requests').where('to', '==', uid).get();
  out.from = q1.size; out.to = q2.size;
  if (!DRY_RUN) {
    const batch = db.batch();
    q1.docs.forEach((d) => batch.delete(d.ref));
    q2.docs.forEach((d) => batch.delete(d.ref));
    if (q1.size + q2.size > 0) await batch.commit();
  }
  return out;
}

async function releaseHandleIfAny(handle) {
  if (!handle) return false;
  const ref = db.collection('handles').doc(handle);
  const snap = await ref.get();
  if (!snap.exists) return false;
  if (!DRY_RUN) await ref.delete();
  return true;
}

async function run() {
  console.log(`Starting placeholder cleanup ${DRY_RUN ? '(dry-run)' : ''} ...`);
  const usersCol = db.collection('users');
  const usersSnap = await usersCol.get();
  const candidates = [];
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    if (isPlaceholderUser(data)) candidates.push({ id: doc.id, data });
  }
  const target = typeof LIMIT === 'number' ? candidates.slice(0, LIMIT) : candidates;
  console.log(`Found ${candidates.length} placeholder candidates; operating on ${target.length}.`);

  const results = [];
  for (const { id: uid, data } of target) {
    const handle = (data.handle || '').toString().trim();
    const summary = { uid, releasedHandle: false, friendLinks: 0, requestsDeleted: { from: 0, to: 0 }, userDocDeleted: false, authDeleted: false, error: null };
    try {
      summary.releasedHandle = await releaseHandleIfAny(handle);
      summary.friendLinks = await deleteFriendLinksFor(uid);
      summary.requestsDeleted = await deleteFriendRequestsFor(uid);
      if (!DRY_RUN) {
        await usersCol.doc(uid).delete();
        summary.userDocDeleted = true;
        await admin.auth().deleteUser(uid);
        summary.authDeleted = true;
      }
    } catch (e) {
      summary.error = e?.message || String(e);
    }
    results.push(summary);
    console.log(`[${DRY_RUN ? 'DRY' : 'DEL'}] ${uid} ->`, summary);
  }

  const tot = results.length;
  const delUsers = results.filter((r) => r.userDocDeleted).length;
  const delAuth = results.filter((r) => r.authDeleted).length;
  const released = results.filter((r) => r.releasedHandle).length;
  console.log(`Done. Users processed: ${tot}. User docs deleted: ${delUsers}. Auth users deleted: ${delAuth}. Handles released: ${released}.`);
  if (DRY_RUN) {
    console.log('Dry-run complete. Re-run without --dry-run to apply deletions.');
  }
}

run().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });


