const pool = require('../config/database');

const DeliveryJob = {
  async create({ projectId, title, description, format, fileUrl, fileSize, uploadedBy }) {
    // version is auto-incremented by the database trigger
    const { rows } = await pool.query(
      `INSERT INTO delivery_jobs (project_id, title, description, format, file_url, file_size, status, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        projectId, title, description || null, format || null,
        fileUrl || null, fileSize || null,
        fileUrl ? 'uploaded' : 'pending',
        uploadedBy,
      ]
    );
    return rows[0];
  },

  async findById(id) {
    const { rows } = await pool.query(
      `SELECT dj.*,
         u_up.name AS uploaded_by_name, u_up.email AS uploaded_by_email, u_up.avatar_url AS uploaded_by_avatar,
         u_rev.name AS reviewed_by_name, u_rev.email AS reviewed_by_email,
         p.name AS project_name
       FROM delivery_jobs dj
       LEFT JOIN users u_up ON dj.uploaded_by = u_up.id
       LEFT JOIN users u_rev ON dj.reviewed_by = u_rev.id
       JOIN projects p ON dj.project_id = p.id
       WHERE dj.id = $1`,
      [id]
    );
    return rows[0] || null;
  },

  async findByProjectId(projectId, { status, limit = 50, offset = 0 } = {}) {
    let query = `
      SELECT dj.*,
        u_up.name AS uploaded_by_name, u_up.avatar_url AS uploaded_by_avatar,
        u_rev.name AS reviewed_by_name,
        (SELECT COUNT(*)::int FROM approvals WHERE delivery_id = dj.id) AS approval_count
      FROM delivery_jobs dj
      LEFT JOIN users u_up ON dj.uploaded_by = u_up.id
      LEFT JOIN users u_rev ON dj.reviewed_by = u_rev.id
      WHERE dj.project_id = $1
    `;
    const values = [projectId];
    let paramIndex = 2;

    if (status) {
      query += ` AND dj.status = $${paramIndex}`;
      values.push(status);
      paramIndex++;
    }

    query += ` ORDER BY dj.version DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    values.push(limit, offset);

    const { rows } = await pool.query(query, values);
    return rows;
  },

  async update(id, fields) {
    const allowed = ['title', 'description', 'format', 'file_url', 'file_size', 'status', 'reviewed_by', 'review_notes'];
    const setClauses = [];
    const values = [];
    let paramIndex = 1;

    for (const key of allowed) {
      const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
      const value = fields[camelKey] !== undefined ? fields[camelKey] : fields[key];
      if (value !== undefined) {
        setClauses.push(`${key} = $${paramIndex}`);
        values.push(value === '' ? null : value);
        paramIndex++;
      }
    }

    if (setClauses.length === 0) return null;

    values.push(id);
    const { rows } = await pool.query(
      `UPDATE delivery_jobs SET ${setClauses.join(', ')} WHERE id = $${paramIndex}
       RETURNING *`,
      values
    );
    return rows[0] || null;
  },

  async countByProject(projectId) {
    const { rows } = await pool.query(
      'SELECT COUNT(*)::int AS count FROM delivery_jobs WHERE project_id = $1',
      [projectId]
    );
    return rows[0].count;
  },

  async countAll() {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM delivery_jobs');
    return rows[0].count;
  },
};

module.exports = DeliveryJob;
