const pool = require('../config/database');

const Project = {
  async create({ name, description, status = 'active', ownerId, color = '#6366f1' }) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Create the project
      const { rows } = await client.query(
        `INSERT INTO projects (name, description, status, owner_id, color)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [name, description, status, ownerId, color]
      );
      const project = rows[0];

      // Add owner as a member with 'owner' role
      await client.query(
        `INSERT INTO project_members (project_id, user_id, role)
         VALUES ($1, $2, 'owner')`,
        [project.id, ownerId]
      );

      // Log activity
      await client.query(
        `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
         VALUES ($1, $2, 'created', 'project', $3, $4)`,
        [project.id, ownerId, project.id, JSON.stringify({ name: project.name })]
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
      `SELECT p.*, u.name AS owner_name, u.email AS owner_email, u.avatar_url AS owner_avatar
       FROM projects p
       JOIN users u ON p.owner_id = u.id
       WHERE p.id = $1`,
      [id]
    );
    return rows[0] || null;
  },

  async findByUserId(userId) {
    const { rows } = await pool.query(
      `SELECT p.*, pm.role AS member_role, u.name AS owner_name
       FROM projects p
       JOIN project_members pm ON p.id = pm.project_id
       JOIN users u ON p.owner_id = u.id
       WHERE pm.user_id = $1
       ORDER BY p.updated_at DESC`,
      [userId]
    );
    return rows;
  },

  async update(id, fields) {
    const allowed = ['name', 'description', 'status', 'color'];
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

  async archive(id) {
    const { rows } = await pool.query(
      `UPDATE projects SET status = 'archived' WHERE id = $1 RETURNING *`,
      [id]
    );
    return rows[0] || null;
  },

  async getMembers(projectId) {
    const { rows } = await pool.query(
      `SELECT u.id, u.name, u.email, u.avatar_url, pm.role, pm.joined_at
       FROM project_members pm
       JOIN users u ON pm.user_id = u.id
       WHERE pm.project_id = $1
       ORDER BY pm.joined_at ASC`,
      [projectId]
    );
    return rows;
  },

  async addMember(projectId, userId, role = 'member') {
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
      `DELETE FROM project_members WHERE project_id = $1 AND user_id = $2 AND role != 'owner'`,
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

  async count() {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM projects');
    return rows[0].count;
  },

  async getStats(projectId) {
    const taskStats = await pool.query(
      `SELECT
         COUNT(*)::int AS total_tasks,
         COUNT(*) FILTER (WHERE status = 'todo')::int AS todo,
         COUNT(*) FILTER (WHERE status = 'in_progress')::int AS in_progress,
         COUNT(*) FILTER (WHERE status = 'review')::int AS review,
         COUNT(*) FILTER (WHERE status = 'done')::int AS done,
         COUNT(*) FILTER (WHERE due_date < NOW() AND status != 'done')::int AS overdue
       FROM tasks WHERE project_id = $1`,
      [projectId]
    );

    const memberProductivity = await pool.query(
      `SELECT
         u.id, u.name, u.avatar_url,
         COUNT(*) FILTER (WHERE t.status = 'done')::int AS completed_tasks,
         COUNT(*)::int AS total_assigned
       FROM project_members pm
       JOIN users u ON pm.user_id = u.id
       LEFT JOIN tasks t ON t.assignee_id = u.id AND t.project_id = $1
       WHERE pm.project_id = $1
       GROUP BY u.id, u.name, u.avatar_url
       ORDER BY completed_tasks DESC`,
      [projectId]
    );

    return {
      tasks: taskStats.rows[0],
      member_productivity: memberProductivity.rows,
    };
  },
};

module.exports = Project;
