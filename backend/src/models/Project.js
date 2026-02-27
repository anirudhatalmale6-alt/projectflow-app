const pool = require('../config/database');

const Project = {
  async create({ name, description, clientId, status = 'draft', deadline, budget, currency = 'BRL', createdBy }) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const { rows } = await client.query(
        `INSERT INTO projects (name, description, client_id, status, deadline, budget, currency, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [name, description || null, clientId || null, status, deadline || null, budget || null, currency, createdBy]
      );
      const project = rows[0];

      // Add creator as a project manager
      await client.query(
        `INSERT INTO project_members (project_id, user_id, role)
         VALUES ($1, $2, 'manager')`,
        [project.id, createdBy]
      );

      await client.query('COMMIT');
      return project;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  },

  async findById(id) {
    const { rows } = await pool.query(
      `SELECT p.*,
         c.name AS client_name, c.company AS client_company,
         u.name AS created_by_name, u.email AS created_by_email
       FROM projects p
       LEFT JOIN clients c ON p.client_id = c.id
       JOIN users u ON p.created_by = u.id
       WHERE p.id = $1`,
      [id]
    );
    return rows[0] || null;
  },

  async findAll({ limit = 50, offset = 0, status, clientId, userId, userRole } = {}) {
    let query = `
      SELECT p.*,
        c.name AS client_name, c.company AS client_company,
        u.name AS created_by_name,
        (SELECT COUNT(*)::int FROM project_members WHERE project_id = p.id) AS member_count,
        (SELECT COUNT(*)::int FROM tasks WHERE project_id = p.id) AS task_count,
        (SELECT COUNT(*)::int FROM tasks WHERE project_id = p.id AND status = 'done') AS done_count,
        (SELECT COUNT(*)::int FROM delivery_jobs WHERE project_id = p.id) AS delivery_count
      FROM projects p
      LEFT JOIN clients c ON p.client_id = c.id
      JOIN users u ON p.created_by = u.id
    `;

    const conditions = [];
    const values = [];
    let paramIndex = 1;

    // If user is not admin/manager, only show projects they are a member of
    if (userId && userRole !== 'admin' && userRole !== 'manager') {
      if (userRole === 'client') {
        // Clients see projects linked to their client record
        conditions.push(`p.client_id IN (SELECT id FROM clients WHERE email = (SELECT email FROM users WHERE id = $${paramIndex}))`);
        values.push(userId);
        paramIndex++;
      } else {
        conditions.push(`p.id IN (SELECT project_id FROM project_members WHERE user_id = $${paramIndex})`);
        values.push(userId);
        paramIndex++;
      }
    }

    if (status) {
      conditions.push(`p.status = $${paramIndex}`);
      values.push(status);
      paramIndex++;
    }

    if (clientId) {
      conditions.push(`p.client_id = $${paramIndex}`);
      values.push(clientId);
      paramIndex++;
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ` ORDER BY p.updated_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    values.push(limit, offset);

    const { rows } = await pool.query(query, values);
    return rows;
  },

  async update(id, fields) {
    const allowed = ['name', 'description', 'client_id', 'status', 'deadline', 'budget', 'currency'];
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
      `UPDATE projects SET ${setClauses.join(', ')} WHERE id = $${paramIndex}
       RETURNING *`,
      values
    );
    return rows[0] || null;
  },

  async delete(id) {
    const { rows } = await pool.query(
      `UPDATE projects SET status = 'archived' WHERE id = $1 RETURNING *`,
      [id]
    );
    return rows[0] || null;
  },

  async getMembers(projectId) {
    const { rows } = await pool.query(
      `SELECT u.id, u.name, u.email, u.avatar_url, u.role AS global_role, pm.role AS project_role, pm.joined_at
       FROM project_members pm
       JOIN users u ON pm.user_id = u.id
       WHERE pm.project_id = $1
       ORDER BY pm.joined_at ASC`,
      [projectId]
    );
    return rows;
  },

  async addMember(projectId, userId, role = 'editor') {
    const { rows } = await pool.query(
      `INSERT INTO project_members (project_id, user_id, role)
       VALUES ($1, $2, $3)
       ON CONFLICT (project_id, user_id) DO UPDATE SET role = $3
       RETURNING *`,
      [projectId, userId, role]
    );
    return rows[0];
  },

  async removeMember(projectId, userId) {
    const { rowCount } = await pool.query(
      `DELETE FROM project_members WHERE project_id = $1 AND user_id = $2`,
      [projectId, userId]
    );
    return rowCount > 0;
  },

  async isMember(projectId, userId) {
    const { rows } = await pool.query(
      `SELECT role FROM project_members WHERE project_id = $1 AND user_id = $2`,
      [projectId, userId]
    );
    return rows[0] || null;
  },

  async getStats(projectId) {
    const taskStats = await pool.query(
      `SELECT
         COUNT(*)::int AS total_tasks,
         COUNT(*) FILTER (WHERE status = 'todo')::int AS todo,
         COUNT(*) FILTER (WHERE status = 'in_progress')::int AS in_progress,
         COUNT(*) FILTER (WHERE status = 'review')::int AS review,
         COUNT(*) FILTER (WHERE status = 'done')::int AS done,
         COUNT(*) FILTER (WHERE due_date < NOW() AND status != 'done')::int AS overdue,
         COALESCE(SUM(estimated_hours), 0)::numeric AS total_estimated_hours,
         COALESCE(SUM(actual_hours), 0)::numeric AS total_actual_hours
       FROM tasks WHERE project_id = $1`,
      [projectId]
    );

    const deliveryStats = await pool.query(
      `SELECT
         COUNT(*)::int AS total_deliveries,
         COUNT(*) FILTER (WHERE status = 'approved')::int AS approved,
         COUNT(*) FILTER (WHERE status = 'rejected')::int AS rejected,
         COUNT(*) FILTER (WHERE status = 'in_review')::int AS in_review,
         COUNT(*) FILTER (WHERE status = 'revision_requested')::int AS revision_requested
       FROM delivery_jobs WHERE project_id = $1`,
      [projectId]
    );

    return {
      tasks: taskStats.rows[0],
      deliveries: deliveryStats.rows[0],
    };
  },

  async count() {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM projects');
    return rows[0].count;
  },
};

module.exports = Project;
