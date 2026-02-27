const pool = require('../config/database');
const bcrypt = require('bcrypt');

const SALT_ROUNDS = 12;

const User = {
  async create({ name, email, password, role = 'editor', phone = null }) {
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const { rows } = await pool.query(
      `INSERT INTO users (name, email, password_hash, role, phone)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, email, avatar_url, role, phone, created_at, updated_at`,
      [name, email, passwordHash, role, phone]
    );
    return rows[0];
  },

  async findByEmail(email) {
    const { rows } = await pool.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );
    return rows[0] || null;
  },

  async findById(id) {
    const { rows } = await pool.query(
      'SELECT id, name, email, avatar_url, role, phone, created_at, updated_at FROM users WHERE id = $1',
      [id]
    );
    return rows[0] || null;
  },

  async findByIds(ids) {
    if (!ids || ids.length === 0) return [];
    const placeholders = ids.map((_, i) => `$${i + 1}`).join(', ');
    const { rows } = await pool.query(
      `SELECT id, name, email, avatar_url, role, phone FROM users WHERE id IN (${placeholders})`,
      ids
    );
    return rows;
  },

  async update(id, fields) {
    const allowed = ['name', 'avatar_url', 'phone'];
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
      `UPDATE users SET ${setClauses.join(', ')} WHERE id = $${paramIndex}
       RETURNING id, name, email, avatar_url, role, phone, created_at, updated_at`,
      values
    );
    return rows[0] || null;
  },

  async updatePassword(id, newPassword) {
    const passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
    const { rows } = await pool.query(
      `UPDATE users SET password_hash = $1 WHERE id = $2
       RETURNING id, name, email, avatar_url, role, phone, created_at, updated_at`,
      [passwordHash, id]
    );
    return rows[0] || null;
  },

  async updateRole(id, role) {
    const { rows } = await pool.query(
      `UPDATE users SET role = $1 WHERE id = $2
       RETURNING id, name, email, avatar_url, role, phone, created_at, updated_at`,
      [role, id]
    );
    return rows[0] || null;
  },

  async comparePassword(plainPassword, hash) {
    return bcrypt.compare(plainPassword, hash);
  },

  async findAll({ limit = 50, offset = 0, role } = {}) {
    let query = `SELECT id, name, email, avatar_url, role, phone, created_at, updated_at FROM users`;
    const values = [];
    let paramIndex = 1;

    if (role) {
      query += ` WHERE role = $${paramIndex}`;
      values.push(role);
      paramIndex++;
    }

    query += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    values.push(limit, offset);

    const { rows } = await pool.query(query, values);
    return rows;
  },

  async count() {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM users');
    return rows[0].count;
  },

  async searchByName(query) {
    const { rows } = await pool.query(
      `SELECT id, name, email, avatar_url, role, phone FROM users
       WHERE name ILIKE $1 OR email ILIKE $1
       LIMIT 20`,
      [`%${query}%`]
    );
    return rows;
  },
};

module.exports = User;
