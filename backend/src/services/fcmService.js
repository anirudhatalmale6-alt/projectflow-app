const pool = require('../config/database');

let admin = null;
let initialized = false;

function initFirebase() {
  if (initialized) return;
  initialized = true;
  try {
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (serviceAccount) {
      admin = require('firebase-admin');
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(serviceAccount)),
      });
      console.log('[FCM] Firebase Admin initialized');
    } else {
      console.log('[FCM] FIREBASE_SERVICE_ACCOUNT_JSON not set - FCM disabled');
    }
  } catch (err) {
    console.error('[FCM] Failed to initialize Firebase Admin:', err.message);
    admin = null;
  }
}

const FcmService = {
  /**
   * Save an FCM token for a user
   */
  async saveToken(userId, token, platform) {
    // Upsert: remove existing token then insert
    await pool.query(
      'DELETE FROM fcm_tokens WHERE token = $1',
      [token]
    );
    await pool.query(
      `INSERT INTO fcm_tokens (user_id, token, platform)
       VALUES ($1, $2, $3)`,
      [userId, token, platform || 'ios']
    );
  },

  /**
   * Remove an FCM token
   */
  async removeToken(token) {
    await pool.query(
      'DELETE FROM fcm_tokens WHERE token = $1',
      [token]
    );
  },

  /**
   * Send push notification to a specific user via FCM
   */
  async sendToUser(userId, payload) {
    initFirebase();
    if (!admin) return;

    const { rows: tokens } = await pool.query(
      'SELECT * FROM fcm_tokens WHERE user_id = $1',
      [userId]
    );

    if (tokens.length === 0) return;

    const staleTokens = [];

    for (const row of tokens) {
      try {
        await admin.messaging().send({
          token: row.token,
          notification: {
            title: payload.title || 'Duozz Flow',
            body: payload.body || '',
          },
          data: {
            route: payload.route || '',
            route_args: payload.routeArgs || '',
            type: payload.type || 'general',
          },
          apns: {
            payload: {
              aps: {
                badge: payload.badge || 1,
                sound: 'default',
                'content-available': 1,
              },
            },
          },
        });
      } catch (err) {
        if (
          err.code === 'messaging/registration-token-not-registered' ||
          err.code === 'messaging/invalid-registration-token'
        ) {
          staleTokens.push(row.token);
        } else {
          console.error(`[FCM] Send failed for user ${userId}:`, err.message);
        }
      }
    }

    // Clean up stale tokens
    for (const token of staleTokens) {
      await pool.query('DELETE FROM fcm_tokens WHERE token = $1', [token]);
    }
  },
};

module.exports = FcmService;
