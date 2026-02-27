const pool = require('../config/database');

const Task = {
  async create({ projectId, title, description, status = 'todo', priority = 'medium', assigneeId, reporterId, dueDate, parentTaskId }) {
    // Get the next position for this status column
    const posResult = await pool.query(
      `SELECT COALESCE(MAX(position), -1) + 1 AS next_pos
       FROM tasks WHERE project_id = $1 AND status = $2`,
      [projectId, status]
    );
    const position = posResult.rows[0].next_pos;

    const { rows } = await pool.query(
      `INSERT INTO tasks (project_id, title, description, status, priority, assignee_id, reporter_id, due_date, position, parent_task_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [projectId, title, description, status, priority, assigneeId || null, reporterId, dueDate || null, position, parentTaskId || null]
    );

    // Log activity
    await pool.query(
      `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
       VALUES ($1, $2, 'created', 'task', $3, $4)`,
      [projectId, reporterId, rows[0].id, JSON.stringify({ title, status, priority })]
    );

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
       WHERE t.id = $1`,
      [id]
    );
    return rows[0] || null;
  },

  async findByProjectId(projectId, { status, assigneeId, priority, search } = {}) {
    let query = `
      SELECT t.*,
        a.name AS assignee_name, a.email AS assignee_email, a.avatar_url AS assignee_avatar,
        r.name AS reporter_name, r.email AS reporter_email,
        (SELECT COUNT(*)::int FROM tasks sub WHERE sub.parent_task_id = t.id) AS subtask_count,
        (SELECT COUNT(*)::int FROM tasks sub WHERE sub.parent_task_id = t.id AND sub.status = 'done') AS subtask_done_count
      FROM tasks t
      LEFT JOIN users a ON t.assignee_id = a.id
      JOIN users r ON t.reporter_id = r.id
      WHERE t.project_id = $1
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
    return rows;
  },

  async update(id, fields, userId) {
    const allowed = ['title', 'description', 'status', 'priority', 'assignee_id', 'due_date', 'parent_task_id'];
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
      `UPDATE tasks SET ${setClauses.join(', ')} WHERE id = $${paramIndex}
       RETURNING *`,
      values
    );

    if (rows[0] && userId) {
      const changes = {};
      for (const key of allowed) {
        const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
        const value = fields[camelKey] !== undefined ? fields[camelKey] : fields[key];
        if (value !== undefined) {
          changes[key] = value;
        }
      }
      await pool.query(
        `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
         VALUES ($1, $2, 'updated', 'task', $3, $4)`,
        [rows[0].project_id, userId, id, JSON.stringify(changes)]
      );
    }

    return rows[0] || null;
  },

  async updatePosition(id, status, position) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Get the task's current info
      const taskResult = await client.query(
        'SELECT project_id, status AS old_status, position AS old_position FROM tasks WHERE id = $1',
        [id]
      );
      if (taskResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }

      const task = taskResult.rows[0];

      // If moving within the same column, shift positions
      if (task.old_status === status) {
        if (position > task.old_position) {
          // Moving down: decrement positions of items between old and new
          await client.query(
            `UPDATE tasks SET position = position - 1
             WHERE project_id = $1 AND status = $2 AND position > $3 AND position <= $4`,
            [task.project_id, status, task.old_position, position]
          );
        } else if (position < task.old_position) {
          // Moving up: increment positions of items between new and old
          await client.query(
            `UPDATE tasks SET position = position + 1
             WHERE project_id = $1 AND status = $2 AND position >= $3 AND position < $4`,
            [task.project_id, status, position, task.old_position]
          );
        }
      } else {
        // Moving to different column
        // Close gap in old column
        await client.query(
          `UPDATE tasks SET position = position - 1
           WHERE project_id = $1 AND status = $2 AND position > $3`,
          [task.project_id, task.old_status, task.old_position]
        );

        // Make space in new column
        await client.query(
          `UPDATE tasks SET position = position + 1
           WHERE project_id = $1 AND status = $2 AND position >= $3`,
          [task.project_id, status, position]
        );
      }

      // Update the task itself
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

  async delete(id, userId) {
    // Get task info before deleting for activity log
    const taskResult = await pool.query(
      'SELECT project_id, title, status, position FROM tasks WHERE id = $1',
      [id]
    );
    if (taskResult.rows.length === 0) return false;

    const task = taskResult.rows[0];

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Delete the task
      await client.query('DELETE FROM tasks WHERE id = $1', [id]);

      // Close the position gap
      await client.query(
        `UPDATE tasks SET position = position - 1
         WHERE project_id = $1 AND status = $2 AND position > $3`,
        [task.project_id, task.status, task.position]
      );

      // Log activity
      if (userId) {
        await client.query(
          `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
           VALUES ($1, $2, 'deleted', 'task', $3, $4)`,
          [task.project_id, userId, id, JSON.stringify({ title: task.title })]
        );
      }

      await client.query('COMMIT');
      return true;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
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
      SELECT t.*, p.name AS project_name, p.color AS project_color
      FROM tasks t
      JOIN projects p ON t.project_id = p.id
      WHERE t.assignee_id = $1
    `;
    const values = [userId];

    if (status) {
      query += ' AND t.status = $2';
      values.push(status);
    }

    query += ' ORDER BY t.due_date ASC NULLS LAST, t.priority DESC, t.created_at DESC';

    const { rows } = await pool.query(query, values);
    return rows;
  },

  async countAll() {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM tasks');
    return rows[0].count;
  },
};

module.exports = Task;
