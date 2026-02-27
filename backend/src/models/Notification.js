const pool = require('../config/database');

const Notification = {
  async create({ userId, type, title, message, referenceId, referenceType }) {
    const { rows } = await pool.query(
      `INSERT INTO notifications (user_id, type, title, message, reference_id, reference_type)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [userId, type, title, message || null, referenceId || null, referenceType || null]
    );
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
};

module.exports = Notification;
