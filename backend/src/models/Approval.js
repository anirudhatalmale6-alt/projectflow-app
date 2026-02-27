const pool = require('../config/database');

const Approval = {
  async create({ deliveryId, status, reviewerId, comments }) {
    const { rows } = await pool.query(
      `INSERT INTO approvals (delivery_id, status, reviewer_id, comments)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [deliveryId, status, reviewerId, comments || null]
    );
    return rows[0];
  },

  async findByDeliveryId(deliveryId) {
    const { rows } = await pool.query(
      `SELECT a.*, u.name AS reviewer_name, u.email AS reviewer_email, u.avatar_url AS reviewer_avatar
       FROM approvals a
       JOIN users u ON a.reviewer_id = u.id
       WHERE a.delivery_id = $1
       ORDER BY a.created_at DESC`,
      [deliveryId]
    );
    return rows;
  },

  async findById(id) {
    const { rows } = await pool.query(
      `SELECT a.*, u.name AS reviewer_name, u.email AS reviewer_email
       FROM approvals a
       JOIN users u ON a.reviewer_id = u.id
       WHERE a.id = $1`,
      [id]
    );
    return rows[0] || null;
  },

  async getLatestForDelivery(deliveryId) {
    const { rows } = await pool.query(
      `SELECT a.*, u.name AS reviewer_name
       FROM approvals a
       JOIN users u ON a.reviewer_id = u.id
       WHERE a.delivery_id = $1
       ORDER BY a.created_at DESC
       LIMIT 1`,
      [deliveryId]
    );
    return rows[0] || null;
  },
};

module.exports = Approval;
