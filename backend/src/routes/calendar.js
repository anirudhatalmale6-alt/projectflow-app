const express = require('express');
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { logAudit, getClientIp } = require('../utils/audit');

let CalendarSyncService;
try { CalendarSyncService = require('../services/calendarSyncService'); } catch (e) { CalendarSyncService = null; }

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
    const { title, description, start_time, end_time, type, sync_google } = req.body;

    if (!title || !start_time || !end_time) {
      return res.status(400).json({ error: 'title, start_time, and end_time are required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO calendar_events (project_id, title, description, start_time, end_time, type, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [req.params.projectId, title, description || null, start_time, end_time, type || 'deadline', req.user.id]
    );

    // Sync to Google Calendar if requested
    if (sync_google && CalendarSyncService) {
      try {
        const googleEventId = await CalendarSyncService.createEvent(req.user.id, rows[0]);
        rows[0].google_event_id = googleEventId;
      } catch (syncErr) {
        console.error('Google Calendar sync error:', syncErr.message);
        // Don't fail the request, event was created locally
      }
    }

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

    // Sync update to Google Calendar
    if (rows[0].google_event_id && CalendarSyncService) {
      try {
        await CalendarSyncService.updateEvent(req.user.id, rows[0]);
      } catch (syncErr) {
        console.error('Google Calendar sync update error:', syncErr.message);
      }
    }

    res.json({ message: 'Event updated.', event: rows[0] });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/calendar/events/:id
router.delete('/calendar/events/:id', auth, async (req, res, next) => {
  try {
    // Get event first to check for google_event_id
    const { rows: eventRows } = await pool.query(
      'SELECT google_event_id FROM calendar_events WHERE id = $1',
      [req.params.id]
    );

    const { rowCount } = await pool.query('DELETE FROM calendar_events WHERE id = $1', [req.params.id]);
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Event not found.' });
    }

    // Delete from Google Calendar
    if (eventRows.length > 0 && eventRows[0].google_event_id && CalendarSyncService) {
      try {
        await CalendarSyncService.deleteEvent(req.user.id, eventRows[0].google_event_id);
      } catch (syncErr) {
        console.error('Google Calendar sync delete error:', syncErr.message);
      }
    }

    res.json({ message: 'Event deleted.' });
  } catch (err) {
    next(err);
  }
});

// ===== Google Calendar Sync Endpoints =====

// GET /api/v1/calendar/google/status - Check if user has Google Calendar linked
router.get('/calendar/google/status', auth, async (req, res, next) => {
  try {
    if (!CalendarSyncService) {
      return res.json({ linked: false, available: false });
    }
    const linked = await CalendarSyncService.hasGoogleCalendar(req.user.id);
    res.json({ linked, available: true });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:projectId/calendar/sync/import - Import from Google Calendar
router.post('/projects/:projectId/calendar/sync/import', auth, async (req, res, next) => {
  try {
    if (!CalendarSyncService) {
      return res.status(501).json({ error: 'Google Calendar sync not available.' });
    }

    const { start, end } = req.body;
    if (!start || !end) {
      return res.status(400).json({ error: 'start and end dates are required.' });
    }

    const result = await CalendarSyncService.importEvents(
      req.user.id,
      req.params.projectId,
      start,
      end
    );

    await logAudit({
      userId: req.user.id, action: 'import_google_calendar', entityType: 'calendar',
      entityId: req.params.projectId, details: result, ipAddress: getClientIp(req),
    });

    res.json({ message: 'Import complete.', ...result });
  } catch (err) {
    if (err.message === 'USER_NOT_GOOGLE_LINKED') {
      return res.status(400).json({ error: 'Sua conta Google não está vinculada. Faça login com Google primeiro.' });
    }
    next(err);
  }
});

// POST /api/v1/projects/:projectId/calendar/sync/export - Export to Google Calendar
router.post('/projects/:projectId/calendar/sync/export', auth, async (req, res, next) => {
  try {
    if (!CalendarSyncService) {
      return res.status(501).json({ error: 'Google Calendar sync not available.' });
    }

    const result = await CalendarSyncService.exportEvents(
      req.user.id,
      req.params.projectId
    );

    await logAudit({
      userId: req.user.id, action: 'export_google_calendar', entityType: 'calendar',
      entityId: req.params.projectId, details: result, ipAddress: getClientIp(req),
    });

    res.json({ message: 'Export complete.', ...result });
  } catch (err) {
    if (err.message === 'USER_NOT_GOOGLE_LINKED') {
      return res.status(400).json({ error: 'Sua conta Google não está vinculada. Faça login com Google primeiro.' });
    }
    next(err);
  }
});

module.exports = router;
