const pool = require('../config/database');

const Client = {
  async create({ name, email, phone, company, notes, createdBy }) {
    const { rows } = await pool.query(
      `INSERT INTO clients (name, email, phone, company, notes, created_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [name, email || null, phone || null, company || null, notes || null, createdBy]
    );
    return rows[0];
  },

  async findById(id) {
    const { rows } = await pool.query(
      `SELECT c.*, u.name AS created_by_name
       FROM clients c
       JOIN users u ON c.created_by = u.id
       WHERE c.id = $1`,
      [id]
    );
    return rows[0] || null;
  },

  async findAll({ limit = 50, offset = 0, search } = {}) {
    let query = `
      SELECT c.*, u.name AS created_by_name,
        (SELECT COUNT(*)::int FROM projects WHERE client_id = c.id) AS project_count
      FROM clients c
      JOIN users u ON c.created_by = u.id
    `;
    const values = [];
    let paramIndex = 1;

    if (search) {
      query += ` WHERE c.name ILIKE $${paramIndex} OR c.email ILIKE $${paramIndex} OR c.company ILIKE $${paramIndex}`;
      values.push(`%${search}%`);
      paramIndex++;
    }

    query += ` ORDER BY c.created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    values.push(limit, offset);

    const { rows } = await pool.query(query, values);
    return rows;
  },

  async update(id, fields) {
    const allowed = ['name', 'email', 'phone', 'company', 'notes'];
    const setClauses = [];
    const values = [];
    let paramIndex = 1;

    for (const key of allowed) {
      if (fields[key] !== undefined) {
        setClauses.push(`${key} = $${paramIndex}`);
        values.push(fields[key]);
        paramIndex++;
      }
    }

    if (setClauses.length === 0) return null;

    values.push(id);
    const { rows } = await pool.query(
      `UPDATE clients SET ${setClauses.join(', ')} WHERE id = $${paramIndex}
       RETURNING *`,
      values
    );
    return rows[0] || null;
  },

  async delete(id) {
    const { rowCount } = await pool.query('DELETE FROM clients WHERE id = $1', [id]);
    return rowCount > 0;
  },

  async count() {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM clients');
    return rows[0].count;
  },
};

module.exports = Client;
