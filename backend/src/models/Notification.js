const pool = require('../config/database');
let PushService;
try { PushService = require('../services/pushService'); } catch (e) { PushService = null; }
let FcmService;
try { FcmService = require('../services/fcmService'); } catch (e) { FcmService = null; }

const Notification = {
  async create({ userId, type, title, message, referenceId, referenceType }) {
    const { rows } = await pool.query(
      `INSERT INTO notifications (user_id, type, title, message, reference_id, reference_type)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [userId, type, title, message || null, referenceId || null, referenceType || null]
    );

    // Send web push notification (non-blocking)
    if (PushService) {
      PushService.sendToUser(userId, {
        title: title || 'Duozz Flow',
        body: message || '',
        icon: '/icons/Icon-192.png',
        data: { type, referenceId, referenceType },
      }).catch(err => console.error('Push send error:', err.message));
    }

    // Send FCM push notification to mobile (non-blocking)
    if (FcmService) {
      FcmService.sendToUser(userId, {
        title: title || 'Duozz Flow',
        body: message || '',
        type: type || 'general',
        route: referenceType === 'task' ? '/tasks/detail' : referenceType === 'project' ? '/projects/detail' : '',
        routeArgs: referenceId || '',
      }).catch(err => console.error('FCM send error:', err.message));
    }

    return rows[0];
  },

  async createBulk(notifications) {
    if (!notifications || notifications.length === 0) return [];

    const values = [];
    const params = [];
    let paramIndex = 1;

    for (const n of notifications) {
      values.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4}, $${paramIndex + 5})`);
      params.push(n.userId, n.type, n.title, n.message || null, n.referenceId || null, n.referenceType || null);
      paramIndex += 6;
    }

    const { rows } = await pool.query(
      `INSERT INTO notifications (user_id, type, title, message, reference_id, reference_type)
       VALUES ${values.join(', ')}
       RETURNING *`,
      params
    );

    // Send FCM push to all recipients (non-blocking)
    if (FcmService) {
      for (const n of notifications) {
        FcmService.sendToUser(n.userId, {
          title: n.title || 'Duozz Flow',
          body: n.message || '',
          type: n.type || 'general',
          route: n.referenceType === 'task' ? '/tasks/detail' : n.referenceType === 'project' ? '/projects/detail' : '',
          routeArgs: n.referenceId || '',
        }).catch(err => console.error('FCM bulk send error:', err.message));
      }
    }

    return rows;
  },

  async findByUserId(userId, { limit = 50, offset = 0, unreadOnly = false } = {}) {
    let query = `SELECT * FROM notifications WHERE user_id = $1`;
    const values = [userId];
    let paramIndex = 2;

    if (unreadOnly) {
      query += ` AND is_read = FALSE`;
    }

    query += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    values.push(limit, offset);

    const { rows } = await pool.query(query, values);
    return rows;
  },

  async markAsRead(id, userId) {
    const { rows } = await pool.query(
      `UPDATE notifications SET is_read = TRUE
       WHERE id = $1 AND user_id = $2
       RETURNING *`,
      [id, userId]
    );
    return rows[0] || null;
  },

  async markAllAsRead(userId) {
    const { rowCount } = await pool.query(
      `UPDATE notifications SET is_read = TRUE
       WHERE user_id = $1 AND is_read = FALSE`,
      [userId]
    );
    return rowCount;
  },

  async getUnreadCount(userId) {
    const { rows } = await pool.query(
      'SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND is_read = FALSE',
      [userId]
    );
    return rows[0].count;
  },

  async deleteAll(userId) {
    const { rowCount } = await pool.query(
      'DELETE FROM notifications WHERE user_id = $1',
      [userId]
    );
    return rowCount;
  },

  async deleteRead(userId) {
    const { rowCount } = await pool.query(
      'DELETE FROM notifications WHERE user_id = $1 AND is_read = TRUE',
      [userId]
    );
    return rowCount;
  },
};

module.exports = Notification;
