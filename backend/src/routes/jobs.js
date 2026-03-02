const express = require('express');
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { requireGlobalRole } = require('../middleware/rbac');
const { logAudit, getClientIp } = require('../utils/audit');

const router = express.Router();

// GET /api/v1/projects/:projectId/jobs
router.get('/projects/:projectId/jobs', auth, async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const { status } = req.query;

    let query = `
      SELECT j.*, u.name as assigned_to_name, c.name as created_by_name
      FROM jobs j
      LEFT JOIN users u ON j.assigned_to = u.id
      LEFT JOIN users c ON j.created_by = c.id
      WHERE j.project_id = $1
    `;
    const params = [projectId];

    if (status) {
      params.push(status);
      query += ` AND j.status = $${params.length}`;
    }

    query += ' ORDER BY j.created_at DESC';
    const { rows } = await pool.query(query, params);
    res.json({ jobs: rows });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:projectId/jobs
router.post('/projects/:projectId/jobs', auth, requireGlobalRole('admin', 'manager'), async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const { title, description, type, assigned_to, due_date, priority } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'Title is required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO jobs (project_id, title, description, type, assigned_to, due_date, priority, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [projectId, title, description || null, type || 'edit', assigned_to || null, due_date || null, priority || 'medium', req.user.id]
    );

    await logAudit({
      userId: req.user.id, action: 'create_job', entityType: 'job',
      entityId: rows[0].id, details: { title, project_id: projectId }, ipAddress: getClientIp(req),
    });

    res.status(201).json({ message: 'Job created.', job: rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/jobs/:id
router.get('/jobs/:id', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT j.*, u.name as assigned_to_name, c.name as created_by_name,
              (SELECT COUNT(*) FROM reviews r WHERE r.job_id = j.id) as review_count,
              (SELECT COUNT(*) FROM assets a WHERE a.job_id = j.id) as asset_count
       FROM jobs j
       LEFT JOIN users u ON j.assigned_to = u.id
       LEFT JOIN users c ON j.created_by = c.id
       WHERE j.id = $1`,
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Job not found.' });
    }

    res.json({ job: rows[0] });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/jobs/:id
router.put('/jobs/:id', auth, async (req, res, next) => {
  try {
    const { title, description, type, status, assigned_to, due_date, priority } = req.body;
    const fields = [];
    const values = [];
    let idx = 1;

    if (title !== undefined) { fields.push(`title = $${idx++}`); values.push(title); }
    if (description !== undefined) { fields.push(`description = $${idx++}`); values.push(description); }
    if (type !== undefined) { fields.push(`type = $${idx++}`); values.push(type); }
    if (status !== undefined) { fields.push(`status = $${idx++}`); values.push(status); }
    if (assigned_to !== undefined) { fields.push(`assigned_to = $${idx++}`); values.push(assigned_to); }
    if (due_date !== undefined) { fields.push(`due_date = $${idx++}`); values.push(due_date); }
    if (priority !== undefined) { fields.push(`priority = $${idx++}`); values.push(priority); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update.' });
    }

    values.push(req.params.id);
    const { rows } = await pool.query(
      `UPDATE jobs SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Job not found.' });
    }

    res.json({ message: 'Job updated.', job: rows[0] });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/jobs/:id
router.delete('/jobs/:id', auth, requireGlobalRole('admin', 'manager'), async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM jobs WHERE id = $1', [req.params.id]);
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Job not found.' });
    }
    res.json({ message: 'Job deleted.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
