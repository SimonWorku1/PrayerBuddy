import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as https from 'node:https';
import { URL } from 'node:url';

admin.initializeApp();

const db = admin.firestore();

// Mirror isDeactivated status from Firestore to Firebase Auth custom claims
export const onUserDeactivated = functions.firestore
  .document('users/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const before = change.before.data();
    const after = change.after.data();

    // Check if isDeactivated status changed
    const wasDeactivated = before?.isDeactivated === true;
    const isDeactivated = after?.isDeactivated === true;

    if (wasDeactivated !== isDeactivated) {
      try {
        await admin.auth().setCustomUserClaims(uid, {
          isDeactivated: isDeactivated
        });
        console.log(`Updated custom claims for ${uid}: isDeactivated=${isDeactivated}`);
      } catch (error) {
        console.error(`Failed to update custom claims for ${uid}:`, error);
      }
    }
  });

// Handle reactivation requests
export const onReactivateRequest = functions.firestore
  .document('users/{uid}/reactivate_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const uid = context.params.uid;
    const requestData = snap.data();

    try {
      // Unhide all user content
      const batch = db.batch();

      // Update user document
      const userRef = db.collection('users').doc(uid);
      batch.update(userRef, {
        isDeactivated: false,
        lastReactivationAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Unhide posts
      const postsSnapshot = await db.collection('posts')
        .where('ownerId', '==', uid)
        .get();
      
      postsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          isHidden: false,
          ownerActive: true
        });
      });

      // Unhide chats
      const chatsSnapshot = await db.collection('chats')
        .where('memberIds', 'array-contains', uid)
        .get();
      
      chatsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          isHidden: false
        });
      });

      // Unhide friend requests
      const friendRequestsSnapshot = await db.collection('friend_requests')
        .where('from', '==', uid)
        .get();
      
      friendRequestsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          isHidden: false
        });
      });

      // Update handle document
      const userDoc = await userRef.get();
      const userData = userDoc.data();
      if (userData?.handle) {
        const handleRef = db.collection('handles').doc(userData.handle);
        batch.update(handleRef, {
          isActive: true,
          ownerId: uid
        });
      }

      // Delete the reactivation request
      batch.delete(snap.ref);

      await batch.commit();

      // Update custom claims
      await admin.auth().setCustomUserClaims(uid, {
        isDeactivated: false
      });

      console.log(`Successfully reactivated account for ${uid}`);
    } catch (error) {
      console.error(`Failed to reactivate account for ${uid}:`, error);
    }
  });

// Backfill posts with missing isHidden and ownerActive fields
export const backfillPosts = functions.firestore
  .document('admin/backfill_posts/trigger/{triggerId}')
  .onCreate(async (snap, context) => {
    try {
      const postsSnapshot = await db.collection('posts')
        .where('isHidden', '==', null)
        .get();

      const batch = db.batch();
      let count = 0;

      postsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          isHidden: false,
          ownerActive: true
        });
        count++;
      });

      await batch.commit();
      console.log(`Backfilled ${count} posts with isHidden and ownerActive fields`);
    } catch (error) {
      console.error('Failed to backfill posts:', error);
    }
  });

// -- BibleGateway proxy (secure) ------------------------------------------------

// In Functions config, set credentials (do NOT commit secrets):
//   firebase functions:config:set biblegateway.user="YOUR_USER" biblegateway.pass="YOUR_PASS"

type TokenCache = { value: string; expiresEpochSec: number } | null;
let bibleGatewayTokenCache: TokenCache = null;

function httpsGet(urlString: string, timeoutMs = 5000): Promise<string> {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(urlString);
    const req = https.request(
      {
        method: 'GET',
        hostname: urlObj.hostname,
        path: urlObj.pathname + urlObj.search,
        protocol: urlObj.protocol,
      },
      (res) => {
        let data = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            resolve(data);
          } else {
            const msg = `HTTP ${res.statusCode}: ${data}`;
            reject(new Error(msg));
          }
        });
      }
    );
    req.setTimeout(timeoutMs, () => {
      req.destroy(new Error('Request timed out'));
    });
    req.on('error', reject);
    req.end();
  });
}

async function getBibleGatewayToken(): Promise<string> {
  // Prefer new dotenv/env vars, fallback to legacy functions.config()
  const envUser = process.env.BIBLEGATEWAY_USER;
  const envPass = process.env.BIBLEGATEWAY_PASS;
  const cfg = (functions as any).config?.() ?? functions.config?.();
  const user: string | undefined = envUser || cfg?.biblegateway?.user;
  const pass: string | undefined = envPass || cfg?.biblegateway?.pass;
  if (!user || !pass) {
    throw new Error('BibleGateway credentials not configured. Set functions config.');
  }
  const nowSec = Math.floor(Date.now() / 1000);
  if (bibleGatewayTokenCache && bibleGatewayTokenCache.expiresEpochSec > nowSec + 60) {
    return bibleGatewayTokenCache.value;
  }
  const tokenUrl = `https://api.biblegateway.com/v2/request_access_token?username=${encodeURIComponent(
    user
  )}&password=${encodeURIComponent(pass)}`;
  const body = await httpsGet(tokenUrl, 5000);
  let parsed: any;
  try {
    parsed = JSON.parse(body);
  } catch {
    throw new Error('Failed to parse BibleGateway token response');
  }
  const token = parsed?.access_token as string | undefined;
  const expires = Number(parsed?.expires) || nowSec + 3600;
  if (!token) throw new Error('No access_token in BibleGateway response');
  bibleGatewayTokenCache = { value: token, expiresEpochSec: expires };
  return token;
}

function stripHtmlToText(html: string): string {
  const withoutScripts = html.replace(/<script[\s\S]*?<\/script>/gi, '');
  const withoutStyles = withoutScripts.replace(/<style[\s\S]*?<\/style>/gi, '');
  const noTags = withoutStyles.replace(/<[^>]+>/g, ' ');
  return noTags
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

export const bibleGatewayTranslations = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  try {
    const token = await getBibleGatewayToken();
    const url = `https://api.biblegateway.com/v2/bible?access_token=${encodeURIComponent(token)}`;
    const body = await httpsGet(url);
    res.type('application/json').send(body);
  } catch (err: any) {
    res.status(500).json({ error: err?.message || String(err) });
  }
});

export const bibleGatewayPassage = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  try {
    const ref = (req.query.ref || req.query.reference || req.query.search || '') as string;
    const versionRaw = (req.query.version || req.query.translation || 'NIV') as string;
    const version = versionRaw.toString();
    const versionLower = version.toLowerCase();
    if (!ref || !ref.toString().trim()) {
      res.status(400).json({ error: 'Missing ref query parameter' });
      return;
    }
    const token = await getBibleGatewayToken();
    const tryFetch = async (abbr: string): Promise<{ html: string; text: string; used: string } | null> => {
      const url = `https://api.biblegateway.com/v2/passage?search=${encodeURIComponent(
        ref
      )}&version=${encodeURIComponent(abbr)}&access_token=${encodeURIComponent(token)}`;
      try {
        const html = await httpsGet(url, 5000);
        const text = stripHtmlToText(html);
        if (text && text.trim()) return { html, text: text.trim(), used: abbr };
        return null;
      } catch {
        return null;
      }
    };

    let result = await tryFetch(versionLower);
    if (!result && versionLower !== version) {
      result = await tryFetch(version);
    }
    // Secondary fallbacks that are usually open
    if (!result) {
      for (const abbr of ['web', 'bsb']) {
        result = await tryFetch(abbr);
        if (result) break;
      }
    }
    if (!result) throw new Error('No passage available for requested translation');
    res.json({ reference: ref, version: result.used.toUpperCase(), html: result.html, text: result.text, source: 'biblegateway' });
  } catch (err: any) {
    res.status(500).json({ error: err?.message || String(err) });
  }
});
