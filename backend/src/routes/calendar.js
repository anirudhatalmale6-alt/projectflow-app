const express = require('express');
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { logAudit, getClientIp } = require('../utils/audit');

const router = express.Router();

// GET /api/v1/projects/:projectId/calendar/events
router.get('/projects/:projectId/calendar/events', auth, async (req, res, next) => {
  try {
    const { start, end, type } = req.query;
    let query = `
      SELECT ce.*, u.name as created_by_name
      FROM calendar_events ce
      LEFT JOIN users u ON ce.created_by = u.id
      WHERE ce.project_id = $1
    `;
    const params = [req.params.projectId];

    if (start) {
      params.push(start);
      query += ` AND ce.end_time >= $${params.length}`;
    }
    if (end) {
      params.push(end);
      query += ` AND ce.start_time <= $${params.length}`;
    }
    if (type) {
      params.push(type);
      query += ` AND ce.type = $${params.length}`;
    }

    query += ' ORDER BY ce.start_time ASC';
    const { rows } = await pool.query(query, params);
    res.json({ events: rows });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:projectId/calendar/events
router.post('/projects/:projectId/calendar/events', auth, async (req, res, next) => {
  try {
    const { title, description, start_time, end_time, type } = req.body;

    if (!title || !start_time || !end_time) {
      return res.status(400).json({ error: 'title, start_time, and end_time are required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO calendar_events (project_id, title, description, start_time, end_time, type, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [req.params.projectId, title, description || null, start_time, end_time, type || 'deadline', req.user.id]
    );

    await logAudit({
      userId: req.user.id, action: 'create_event', entityType: 'calendar_event',
      entityId: rows[0].id, details: { title, project_id: req.params.projectId }, ipAddress: getClientIp(req),
    });

    res.status(201).json({ message: 'Event created.', event: rows[0] });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/v1/calendar/events/:id
router.patch('/calendar/events/:id', auth, async (req, res, next) => {
  try {
    const { title, description, start_time, end_time, type } = req.body;
    const fields = [];
    const values = [];
    let idx = 1;

    if (title !== undefined) { fields.push(`title = $${idx++}`); values.push(title); }
    if (description !== undefined) { fields.push(`description = $${idx++}`); values.push(description); }
    if (start_time !== undefined) { fields.push(`start_time = $${idx++}`); values.push(start_time); }
    if (end_time !== undefined) { fields.push(`end_time = $${idx++}`); values.push(end_time); }
    if (type !== undefined) { fields.push(`type = $${idx++}`); values.push(type); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update.' });
    }

    values.push(req.params.id);
    const { rows } = await pool.query(
      `UPDATE calendar_events SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Event not found.' });
    }

    res.json({ message: 'Event updated.', event: rows[0] });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/calendar/events/:id
router.delete('/calendar/events/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM calendar_events WHERE id = $1', [req.params.id]);
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Event not found.' });
    }
    res.json({ message: 'Event deleted.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
