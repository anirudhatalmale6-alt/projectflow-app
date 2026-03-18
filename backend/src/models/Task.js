const pool = require('../config/database');

// Helper: parse tags from JSON string to array (MySQL stores JSON, PG used TEXT[])
function parseTags(rows) {
  if (!rows) return rows;
  for (const row of rows) {
    if (row.tags && typeof row.tags === 'string') {
      try { row.tags = JSON.parse(row.tags); } catch (_) { row.tags = []; }
    }
    if (row.tags === null || row.tags === undefined) row.tags = [];
  }
  return rows;
}

// Helper: fetch assignees for tasks
async function enrichWithAssignees(tasks) {
  if (!tasks || tasks.length === 0) return tasks;
  const taskIds = tasks.map(t => t.id);
  const { rows: assignees } = await pool.query(
    `SELECT ta.task_id, u.id, u.name, u.email, u.avatar_url
     FROM task_assignees ta
     JOIN users u ON ta.user_id = u.id
     WHERE ta.task_id = ANY($1)
     ORDER BY ta.assigned_at ASC`,
    [taskIds]
  );
  const map = {};
  for (const a of assignees) {
    if (!map[a.task_id]) map[a.task_id] = [];
    map[a.task_id].push({ id: a.id, name: a.name, email: a.email, avatar_url: a.avatar_url });
  }
  for (const t of tasks) {
    t.assignees = map[t.id] || [];
  }
  return tasks;
}

const Task = {
  async create({ projectId, title, description, status = 'todo', priority = 'medium', assigneeId, reporterId, dueDate, parentTaskId, estimatedHours, tags }) {
    // Get the next position for this status column
    const posResult = await pool.query(
      `SELECT COALESCE(MAX(position), -1) + 1 AS next_pos
       FROM tasks WHERE project_id = $1 AND status = $2`,
      [projectId, status]
    );
    const position = posResult.rows[0].next_pos;

    const { rows } = await pool.query(
      `INSERT INTO tasks (project_id, title, description, status, priority, assignee_id, reporter_id, due_date, position, parent_task_id, estimated_hours, tags)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       RETURNING *`,
      [
        projectId, title, description || null, status, priority,
        assigneeId || null, reporterId, dueDate || null, position,
        parentTaskId || null, estimatedHours || null, tags ? JSON.stringify(tags) : null,
      ]
    );
    parseTags(rows);
    return rows[0];
  },

  async findById(id) {
    const { rows } = await pool.query(
      `SELECT t.*,
         a.name AS assignee_name, a.email AS assignee_email, a.avatar_url AS assignee_avatar,
         r.name AS reporter_name, r.email AS reporter_email, r.avatar_url AS reporter_avatar,
         p.name AS project_name
       FROM tasks t
       LEFT JOIN users a ON t.assignee_id = a.id
       JOIN users r ON t.reporter_id = r.id
       JOIN projects p ON t.project_id = p.id
       WHERE t.id = $1 AND t.deleted_at IS NULL`,
      [id]
    );
    if (rows.length === 0) return null;
    parseTags(rows);
    await enrichWithAssignees(rows);
    return rows[0];
  },

  async findByProjectId(projectId, { status, assigneeId, priority, search } = {}) {
    let query = `
      SELECT t.*,
        a.name AS assignee_name, a.email AS assignee_email, a.avatar_url AS assignee_avatar,
        r.name AS reporter_name, r.email AS reporter_email,
        (SELECT COUNT(*)::int FROM tasks sub WHERE sub.parent_task_id = t.id) AS subtask_count,
        (SELECT COUNT(*)::int FROM tasks sub WHERE sub.parent_task_id = t.id AND sub.status = 'done') AS subtask_done_count,
        (SELECT COUNT(*)::int FROM comments WHERE entity_type = 'task' AND entity_id = t.id) AS comment_count
      FROM tasks t
      LEFT JOIN users a ON t.assignee_id = a.id
      JOIN users r ON t.reporter_id = r.id
      WHERE t.project_id = $1 AND t.deleted_at IS NULL
    `;
    const values = [projectId];
    let paramIndex = 2;

    if (status) {
      query += ` AND t.status = $${paramIndex}`;
      values.push(status);
      paramIndex++;
    }

    if (assigneeId) {
      query += ` AND t.assignee_id = $${paramIndex}`;
      values.push(assigneeId);
      paramIndex++;
    }

    if (priority) {
      query += ` AND t.priority = $${paramIndex}`;
      values.push(priority);
      paramIndex++;
    }

    if (search) {
      query += ` AND (t.title ILIKE $${paramIndex} OR t.description ILIKE $${paramIndex})`;
      values.push(`%${search}%`);
      paramIndex++;
    }

    query += ' ORDER BY t.status, t.position ASC, t.created_at DESC';

    const { rows } = await pool.query(query, values);
    parseTags(rows);
    await enrichWithAssignees(rows);
    return rows;
  },

  async update(id, fields) {
    const allowed = ['title', 'description', 'status', 'priority', 'assignee_id', 'due_date', 'parent_task_id', 'estimated_hours', 'actual_hours', 'tags'];
    const setClauses = [];
    const values = [];
    let paramIndex = 1;

    for (const key of allowed) {
      const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
      const value = fields[camelKey] !== undefined ? fields[camelKey] : fields[key];
      if (value !== undefined) {
        setClauses.push(`${key} = $${paramIndex}`);
        const v = value === '' ? null : value;
        values.push(key === 'tags' && Array.isArray(v) ? JSON.stringify(v) : v);
        paramIndex++;
      }
    }

    if (setClauses.length === 0) return null;

    values.push(id);
    const { rows } = await pool.query(
      `UPDATE tasks SET ${setClauses.join(', ')} WHERE id = $${paramIndex}
       RETURNING *`,
      values
    );

    return rows[0] || null;
  },

  async updatePosition(id, status, position) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const taskResult = await client.query(
        'SELECT project_id, status AS old_status, position AS old_position FROM tasks WHERE id = $1',
        [id]
      );
      if (taskResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }

      const task = taskResult.rows[0];

      if (task.old_status === status) {
        if (position > task.old_position) {
          await client.query(
            `UPDATE tasks SET position = position - 1
             WHERE project_id = $1 AND status = $2 AND position > $3 AND position <= $4`,
            [task.project_id, status, task.old_position, position]
          );
        } else if (position < task.old_position) {
          await client.query(
            `UPDATE tasks SET position = position + 1
             WHERE project_id = $1 AND status = $2 AND position >= $3 AND position < $4`,
            [task.project_id, status, position, task.old_position]
          );
        }
      } else {
        await client.query(
          `UPDATE tasks SET position = position - 1
           WHERE project_id = $1 AND status = $2 AND position > $3`,
          [task.project_id, task.old_status, task.old_position]
        );
        await client.query(
          `UPDATE tasks SET position = position + 1
           WHERE project_id = $1 AND status = $2 AND position >= $3`,
          [task.project_id, status, position]
        );
      }

      const { rows } = await client.query(
        `UPDATE tasks SET status = $1, position = $2 WHERE id = $3 RETURNING *`,
        [status, position, id]
      );

      await client.query('COMMIT');
      return rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  },

  async delete(id) {
    const taskResult = await pool.query(
      'SELECT project_id, title, status, position FROM tasks WHERE id = $1',
      [id]
    );
    if (taskResult.rows.length === 0) return false;

    const task = taskResult.rows[0];

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('DELETE FROM tasks WHERE id = $1', [id]);
      await client.query(
        `UPDATE tasks SET position = position - 1
         WHERE project_id = $1 AND status = $2 AND position > $3`,
        [task.project_id, task.status, task.position]
      );
      await client.query('COMMIT');
      return true;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  },

  async softDelete(id, userId) {
    const { rows } = await pool.query(
      `UPDATE tasks SET deleted_at = NOW(), deleted_by = $2 WHERE id = $1 RETURNING *`,
      [id, userId]
    );
    return rows[0] || null;
  },

  async restore(id) {
    const { rows } = await pool.query(
      `UPDATE tasks SET deleted_at = NULL, deleted_by = NULL WHERE id = $1 RETURNING *`,
      [id]
    );
    return rows[0] || null;
  },

  async findTrash(userId) {
    const { rows } = await pool.query(
      `SELECT t.*, p.name AS project_name
       FROM tasks t
       JOIN projects p ON t.project_id = p.id
       WHERE t.deleted_at IS NOT NULL AND t.deleted_by = $1
       ORDER BY t.deleted_at DESC`,
      [userId]
    );
    return rows;
  },

  async getSubtasks(parentTaskId) {
    const { rows } = await pool.query(
      `SELECT t.*, a.name AS assignee_name, a.avatar_url AS assignee_avatar
       FROM tasks t
       LEFT JOIN users a ON t.assignee_id = a.id
       WHERE t.parent_task_id = $1
       ORDER BY t.position ASC`,
      [parentTaskId]
    );
    return rows;
  },

  async findByAssignee(userId, { status } = {}) {
    let query = `
      SELECT t.*, p.name AS project_name, p.status AS project_status
      FROM tasks t
      JOIN projects p ON t.project_id = p.id
      WHERE t.assignee_id = $1 AND t.deleted_at IS NULL
    `;
    const values = [userId];

    if (status) {
      query += ' AND t.status = $2';
      values.push(status);
    }

    query += ' ORDER BY CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END, t.due_date ASC, t.priority DESC, t.created_at DESC';

    const { rows } = await pool.query(query, values);
    return rows;
  },

  async countAll() {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM tasks WHERE deleted_at IS NULL');
    return rows[0].count;
  },
};

Task.enrichWithAssignees = enrichWithAssignees;

module.exports = Task;
