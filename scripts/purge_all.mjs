#!/usr/bin/env node
import admin from 'firebase-admin';

const DRY_RUN = process.argv.includes('--dry-run');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'prayerbuddy-6ca4a',
});

const db = admin.firestore();

async function deleteCollection(collPath, batchSize = 300) {
  const collRef = db.collection(collPath);
  while (true) {
    const snap = await collRef.limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    if (!DRY_RUN) await batch.commit();
  }
}

async function purgeChats() {
  const chats = await db.collection('chats').get();
  for (const chat of chats.docs) {
    const msgs = await chat.ref.collection('messages').get();
    const batch = db.batch();
    msgs.docs.forEach((m) => batch.delete(m.ref));
    if (!DRY_RUN && msgs.size > 0) await batch.commit();
    if (!DRY_RUN) await chat.ref.delete();
  }
}

async function purgePosts() {
  await deleteCollection('posts');
}

async function purgeUsers() {
  const users = await db.collection('users').get();
  for (const u of users.docs) {
    const uid = u.id;
    // delete subcollections like friends
    const friends = await u.ref.collection('friends').get();
    const batch = db.batch();
    friends.docs.forEach((d) => batch.delete(d.ref));
    if (!DRY_RUN && friends.size > 0) await batch.commit();

    if (!DRY_RUN) await u.ref.delete();
    try {
      if (!DRY_RUN) await admin.auth().deleteUser(uid);
    } catch (_) {}
  }
}

async function purgeFriendRequests() {
  await deleteCollection('friend_requests');
}

async function run() {
  console.log(`Purging ALL data ${DRY_RUN ? '(dry-run)' : ''}...`);
  await purgeChats();
  await purgePosts();
  await purgeFriendRequests();
  await purgeUsers();
  await deleteCollection('handles');
  console.log('Done.');
}

run().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });



