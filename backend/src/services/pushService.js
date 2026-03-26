const webpush = require('web-push');
const pool = require('../config/database');

// VAPID keys for Web Push
const VAPID_PUBLIC_KEY = process.env.VAPID_PUBLIC_KEY || 'BIYEzCdEtjsTOgLxMXgQEsEhRMNhQu4TYIpn1FjgXZI8GzxVNBO1iD2s-FdWJPH2c62RlLSagUzf8yur1AIddyo';
const VAPID_PRIVATE_KEY = process.env.VAPID_PRIVATE_KEY || 'REvN1oEuPSx1JlvKNPq_FKeaLbmpFi0Hdwi1nbinuzs';

webpush.setVapidDetails(
  'mailto:admin@duozzflow.com',
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY
);

const PushService = {
  /**
   * Save a push subscription for a user
   */
  async saveSubscription(userId, subscription) {
    const endpoint = subscription.endpoint;
    const p256dh = subscription.keys?.p256dh || '';
    const auth = subscription.keys?.auth || '';

    // Upsert: delete existing then insert
    await pool.query(
      'DELETE FROM push_subscriptions WHERE user_id = $1 AND endpoint = $2',
      [userId, endpoint]
    );
    await pool.query(
      `INSERT INTO push_subscriptions (user_id, endpoint, p256dh, auth_key)
       VALUES ($1, $2, $3, $4)`,
      [userId, endpoint, p256dh, auth]
    );
  },

  /**
   * Remove a push subscription
   */
  async removeSubscription(userId, endpoint) {
    await pool.query(
      'DELETE FROM push_subscriptions WHERE user_id = $1 AND endpoint = $2',
      [userId, endpoint]
    );
  },

  /**
   * Send push notification to a specific user
   */
  async sendToUser(userId, payload) {
    const { rows: subscriptions } = await pool.query(
      'SELECT * FROM push_subscriptions WHERE user_id = $1',
      [userId]
    );

    if (subscriptions.length === 0) return;

    const body = JSON.stringify(payload);
    const staleEndpoints = [];

    for (const sub of subscriptions) {
      const pushSub = {
        endpoint: sub.endpoint,
        keys: {
          p256dh: sub.p256dh,
          auth: sub.auth_key,
        },
      };

      try {
        await webpush.sendNotification(pushSub, body);
      } catch (err) {
        if (err.statusCode === 404 || err.statusCode === 410) {
          // Subscription expired or invalid - remove it
          staleEndpoints.push(sub.endpoint);
        } else {
          console.error(`Push failed for user ${userId}:`, err.message);
        }
      }
    }

    // Clean up stale subscriptions
    for (const ep of staleEndpoints) {
      await pool.query(
        'DELETE FROM push_subscriptions WHERE endpoint = $1',
        [ep]
      );
    }
  },

  /**
   * Get the public VAPID key for the frontend
   */
  getPublicKey() {
    return VAPID_PUBLIC_KEY;
  },
};

module.exports = PushService;
