const pool = require('../config/database');

const Comment = {
  /**
   * Create a polymorphic comment.
   * @param {object} params
   * @param {string} params.entityType - 'project', 'task', or 'delivery'
   * @param {string} params.entityId   - UUID of the entity
   * @param {string} params.userId     - UUID of the user
   * @param {string} params.content    - Comment text
   */
  async create({ entityType, entityId, userId, content }) {
    const { rows } = await pool.query(
      `INSERT INTO comments (entity_type, entity_id, user_id, content)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [entityType, entityId, userId, content]
    );
    return rows[0];
  },

  /**
   * Find comments for an entity (polymorphic).
   */
  async findByEntity(entityType, entityId, { limit = 100, offset = 0 } = {}) {
    const { rows } = await pool.query(
      `SELECT c.*, u.name AS user_name, u.email AS user_email, u.avatar_url AS user_avatar
       FROM comments c
       JOIN users u ON c.user_id = u.id
       WHERE c.entity_type = $1 AND c.entity_id = $2
       ORDER BY c.created_at ASC
       LIMIT $3 OFFSET $4`,
      [entityType, entityId, limit, offset]
    );
    return rows;
  },

  async findById(id) {
    const { rows } = await pool.query(
      `SELECT c.*, u.name AS user_name, u.email AS user_email, u.avatar_url AS user_avatar
       FROM comments c
       JOIN users u ON c.user_id = u.id
       WHERE c.id = $1`,
      [id]
    );
    return rows[0] || null;
  },

  async countByEntity(entityType, entityId) {
    const { rows } = await pool.query(
      `SELECT COUNT(*)::int AS count FROM comments WHERE entity_type = $1 AND entity_id = $2`,
      [entityType, entityId]
    );
    return rows[0].count;
  },
};

module.exports = Comment;
