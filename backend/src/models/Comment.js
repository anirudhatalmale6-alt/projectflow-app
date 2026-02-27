const pool = require('../config/database');

const Comment = {
  async create({ taskId, userId, content }) {
    const { rows } = await pool.query(
      `INSERT INTO comments (task_id, user_id, content)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [taskId, userId, content]
    );
    return rows[0];
  },

  async findByTaskId(taskId) {
    const { rows } = await pool.query(
      `SELECT c.*, u.name AS user_name, u.email AS user_email, u.avatar_url AS user_avatar
       FROM comments c
       JOIN users u ON c.user_id = u.id
       WHERE c.task_id = $1
       ORDER BY c.created_at ASC`,
      [taskId]
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

  async addMentions(commentId, userIds) {
    if (!userIds || userIds.length === 0) return [];
    const values = userIds.map((uid, i) => `($1, $${i + 2})`).join(', ');
    const params = [commentId, ...userIds];
    const { rows } = await pool.query(
      `INSERT INTO mentions (comment_id, mentioned_user_id) VALUES ${values} RETURNING *`,
      params
    );
    return rows;
  },

  async getMentions(commentId) {
    const { rows } = await pool.query(
      `SELECT m.*, u.name AS user_name, u.email AS user_email
       FROM mentions m
       JOIN users u ON m.mentioned_user_id = u.id
       WHERE m.comment_id = $1`,
      [commentId]
    );
    return rows;
  },
};

module.exports = Comment;
