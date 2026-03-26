const express = require('express');
const pool = require('../config/database');
const auth = require('../middleware/auth');
const Notification = require('../models/Notification');

const router = express.Router();

// GET /api/v1/projects/:projectId/channels
router.get('/projects/:projectId/channels', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT cc.*,
              (SELECT COUNT(*)::int FROM chat_messages cm WHERE cm.channel_id = cc.id) as message_count,
              (SELECT cm.content FROM chat_messages cm WHERE cm.channel_id = cc.id ORDER BY cm.created_at DESC LIMIT 1) as last_message
       FROM chat_channels cc
       WHERE cc.project_id = $1
       ORDER BY cc.created_at ASC`,
      [req.params.projectId]
    );
    res.json({ channels: rows });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:projectId/channels
router.post('/projects/:projectId/channels', auth, async (req, res, next) => {
  try {
    const { name, type, job_id } = req.body;
    const channelName = name || 'Geral';
    const channelType = type || 'project';

    // Prevent duplicate channels with the same name in the same project
    const existing = await pool.query(
      'SELECT * FROM chat_channels WHERE project_id = $1 AND name = $2 AND type = $3 LIMIT 1',
      [req.params.projectId, channelName, channelType]
    );
    if (existing.rows.length > 0) {
      return res.status(200).json({ message: 'Channel already exists.', channel: existing.rows[0] });
    }

    const { rows } = await pool.query(
      `INSERT INTO chat_channels (project_id, name, type, job_id)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.params.projectId, channelName, channelType, job_id || null]
    );

    res.status(201).json({ message: 'Channel created.', channel: rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/channels/:id/messages
router.get('/channels/:id/messages', auth, async (req, res, next) => {
  try {
    const { limit = 50, before } = req.query;
    let query = `
      SELECT cm.*, u.name as user_name, u.avatar_url as user_avatar
      FROM chat_messages cm
      LEFT JOIN users u ON cm.user_id = u.id
      WHERE cm.channel_id = $1
    `;
    const params = [req.params.id];

    if (before) {
      params.push(before);
      query += ` AND cm.created_at < $${params.length}`;
    }

    params.push(parseInt(limit, 10));
    query += ` ORDER BY cm.created_at DESC LIMIT $${params.length}`;

    const { rows } = await pool.query(query, params);
    res.json({ messages: rows.reverse() });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/channels/:id/messages
router.post('/channels/:id/messages', auth, async (req, res, next) => {
  try {
    const { content, type, file_url, file_name } = req.body;

    if (!content) {
      return res.status(400).json({ error: 'Content is required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO chat_messages (channel_id, user_id, content, type, file_url, file_name)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.params.id, req.user.id, content, type || 'text', file_url || null, file_name || null]
    );

    // Get user info for the response
    const message = rows[0];
    message.user_name = req.user.name;
    message.user_avatar = req.user.avatar_url;

    // Emit via Socket.IO and notify project members
    const io = req.app.get('io');
    const channelRes = await pool.query('SELECT project_id FROM chat_channels WHERE id = $1', [req.params.id]);
    const projectId = channelRes.rows.length > 0 ? channelRes.rows[0].project_id : null;

    if (io && projectId) {
      io.to(`project:${projectId}`).emit('chat_message', {
        channel_id: req.params.id,
        message,
      });

      // Notify all project members (except the sender)
      try {
        const { rows: members } = await pool.query(
          `SELECT DISTINCT user_id FROM project_members WHERE project_id = $1 AND user_id != $2
           UNION
           SELECT DISTINCT id as user_id FROM users WHERE role = 'admin' AND id != $2`,
          [projectId, req.user.id]
        );

        const { rows: projectRows } = await pool.query('SELECT name FROM projects WHERE id = $1', [projectId]);
        const projectName = projectRows.length > 0 ? projectRows[0].name : 'Projeto';

        const preview = content.length > 60 ? content.substring(0, 60) + '...' : content;
        const notifications = members.map(m => ({
          userId: m.user_id,
          type: 'chat_message',
          title: `Nova mensagem de ${req.user.name}`,
          message: `${preview} — no projeto "${projectName}"`,
          referenceId: projectId,
          referenceType: 'project',
        }));

        if (notifications.length > 0) {
          await Notification.createBulk(notifications);
          for (const m of members) {
            io.to(`user:${m.user_id}`).emit('notification', {
              type: 'chat_message',
              title: `Nova mensagem de ${req.user.name}`,
              project_id: projectId,
            });
          }
        }
      } catch (notifErr) {
        console.error('Failed to send chat notifications:', notifErr.message);
      }
    }

    res.status(201).json({ message: 'Message sent.', data: message });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
