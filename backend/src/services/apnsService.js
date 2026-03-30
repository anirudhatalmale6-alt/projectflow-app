const apn = require('@parse/node-apn');
const path = require('path');
const pool = require('../config/database');

let apnProvider = null;
let initialized = false;

function initApns() {
  if (initialized) return;
  initialized = true;
  try {
    const keyPath = process.env.APNS_KEY_PATH;
    const keyId = process.env.APNS_KEY_ID;
    const teamId = process.env.APNS_TEAM_ID;

    if (!keyPath || !keyId || !teamId) {
      console.log('[APNs] Missing APNS_KEY_PATH, APNS_KEY_ID, or APNS_TEAM_ID - APNs disabled');
      return;
    }

    apnProvider = new apn.Provider({
      token: {
        key: keyPath,
        keyId: keyId,
        teamId: teamId,
      },
      production: process.env.APNS_PRODUCTION === 'true',
    });

    console.log('[APNs] Provider initialized (production:', process.env.APNS_PRODUCTION === 'true', ')');
  } catch (err) {
    console.error('[APNs] Failed to initialize:', err.message);
    apnProvider = null;
  }
}

const ApnsService = {
  /**
   * Save a device token for a user
   */
  async saveToken(userId, token, platform) {
    await pool.query('DELETE FROM fcm_tokens WHERE token = $1', [token]);
    await pool.query(
      `INSERT INTO fcm_tokens (user_id, token, platform)
       VALUES ($1, $2, $3)`,
      [userId, token, platform || 'ios']
    );
  },

  /**
   * Remove a device token
   */
  async removeToken(token) {
    await pool.query('DELETE FROM fcm_tokens WHERE token = $1', [token]);
  },

  /**
   * Send push notification to a specific user via APNs
   */
  async sendToUser(userId, payload) {
    initApns();
    if (!apnProvider) return;

    const { rows: tokens } = await pool.query(
      'SELECT * FROM fcm_tokens WHERE user_id = $1',
      [userId]
    );

    if (tokens.length === 0) return;

    const staleTokens = [];
    const bundleId = process.env.APNS_BUNDLE_ID || 'com.duozzflow.app';

    for (const row of tokens) {
      try {
        const note = new apn.Notification();
        note.expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour
        note.badge = payload.badge || 1;
        note.sound = 'default';
        note.alert = {
          title: payload.title || 'Duozz Flow',
          body: payload.body || '',
        };
        note.topic = bundleId;
        note.contentAvailable = true;
        note.payload = {
          route: payload.route || '',
          route_args: payload.routeArgs || '',
          type: payload.type || 'general',
        };

        const result = await apnProvider.send(note, row.token);

        if (result.failed && result.failed.length > 0) {
          for (const fail of result.failed) {
            if (
              fail.status === '410' ||
              (fail.response && fail.response.reason === 'Unregistered') ||
              (fail.response && fail.response.reason === 'BadDeviceToken')
            ) {
              staleTokens.push(row.token);
            } else {
              console.error(
                `[APNs] Send failed for user ${userId}:`,
                fail.response ? fail.response.reason : fail.error
              );
            }
          }
        }
      } catch (err) {
        console.error(`[APNs] Send error for user ${userId}:`, err.message);
      }
    }

    // Clean up stale tokens
    for (const token of staleTokens) {
      await pool.query('DELETE FROM fcm_tokens WHERE token = $1', [token]);
    }
  },
};

module.exports = ApnsService;
