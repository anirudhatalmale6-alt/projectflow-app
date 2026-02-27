const express = require('express');
const Comment = require('../models/Comment');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const { logAudit, getClientIp } = require('../utils/audit');
const pool = require('../config/database');

const router = express.Router();

// All routes require auth
router.use(auth);

/**
 * Resolve the project_id for an entity so we can check access.
 */
async function getProjectIdForEntity(entityType, entityId) {
  switch (entityType) {
    case 'project':
      return entityId;
    case 'task': {
      const { rows } = await pool.query('SELECT project_id FROM tasks WHERE id = $1', [entityId]);
      return rows[0]?.project_id || null;
    }
    case 'delivery': {
      const { rows } = await pool.query('SELECT project_id FROM delivery_jobs WHERE id = $1', [entityId]);
      return rows[0]?.project_id || null;
    }
    default:
      return null;
  }
}

/**
 * Check if the entity exists.
 */
async function entityExists(entityType, entityId) {
  let table;
  switch (entityType) {
    case 'project': table = 'projects'; break;
    case 'task': table = 'tasks'; break;
    case 'delivery': table = 'delivery_jobs'; break;
    default: return false;
  }
  const { rows } = await pool.query(`SELECT id FROM ${table} WHERE id = $1`, [entityId]);
  return rows.length > 0;
}

// GET /api/v1/comments?entity_type=project&entity_id=xxx
router.get('/', async (req, res, next) => {
  try {
    const { entity_type, entity_id, limit = 100, offset = 0 } = req.query;

    if (!entity_type || !entity_id) {
      return res.status(400).json({ error: 'entity_type and entity_id are required.' });
    }

    const validTypes = ['project', 'task', 'delivery'];
    if (!validTypes.includes(entity_type)) {
      return res.status(400).json({ error: `Invalid entity_type. Must be one of: ${validTypes.join(', ')}.` });
    }

    // Check if entity exists
    const exists = await entityExists(entity_type, entity_id);
    if (!exists) {
      return res.status(404).json({ error: `${entity_type} not found.` });
    }

    // Check project access
    const projectId = await getProjectIdForEntity(entity_type, entity_id);
    if (projectId && req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(projectId, req.user.id);
      if (!membership) {
        // Check client access
        if (req.user.role === 'client') {
          const { rows } = await pool.query(
            `SELECT 1 FROM projects p
             JOIN clients c ON p.client_id = c.id
             JOIN users u ON u.email = c.email
             WHERE p.id = $1 AND u.id = $2`,
            [projectId, req.user.id]
          );
          if (rows.length === 0) {
            return res.status(403).json({ error: 'Access denied.' });
          }
        } else {
          return res.status(403).json({ error: 'Access denied.' });
        }
      }
    }

    const comments = await Comment.findByEntity(entity_type, entity_id, {
      limit: Math.min(parseInt(limit, 10) || 100, 500),
      offset: parseInt(offset, 10) || 0,
    });

    res.json({ comments });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/comments
router.post('/', async (req, res, next) => {
  try {
    const { entity_type, entity_id, content } = req.body;

    if (!entity_type || !entity_id || !content) {
      return res.status(400).json({ error: 'entity_type, entity_id, and content are required.' });
    }

    const validTypes = ['project', 'task', 'delivery'];
    if (!validTypes.includes(entity_type)) {
      return res.status(400).json({ error: `Invalid entity_type. Must be one of: ${validTypes.join(', ')}.` });
    }

    if (typeof content !== 'string' || content.trim().length === 0) {
      return res.status(400).json({ error: 'Comment content cannot be empty.' });
    }

    // Check if entity exists
    const exists = await entityExists(entity_type, entity_id);
    if (!exists) {
      return res.status(404).json({ error: `${entity_type} not found.` });
    }

    // Check project access
    const projectId = await getProjectIdForEntity(entity_type, entity_id);
    if (projectId && req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(projectId, req.user.id);
      if (!membership) {
        // Clients can comment on deliveries and projects
        if (req.user.role === 'client' && (entity_type === 'delivery' || entity_type === 'project')) {
          const { rows } = await pool.query(
            `SELECT 1 FROM projects p
             JOIN clients c ON p.client_id = c.id
             JOIN users u ON u.email = c.email
             WHERE p.id = $1 AND u.id = $2`,
            [projectId, req.user.id]
          );
          if (rows.length === 0) {
            return res.status(403).json({ error: 'Access denied.' });
          }
        } else {
          return res.status(403).json({ error: 'Access denied.' });
        }
      }

      // Freelancers can comment on tasks assigned to them
      if (req.user.role === 'freelancer' && entity_type === 'task') {
        const { rows } = await pool.query(
          'SELECT assignee_id FROM tasks WHERE id = $1',
          [entity_id]
        );
        if (rows.length > 0 && rows[0].assignee_id !== req.user.id) {
          return res.status(403).json({ error: 'Freelancers can only comment on tasks assigned to them.' });
        }
      }
    }

    const comment = await Comment.create({
      entityType: entity_type,
      entityId: entity_id,
      userId: req.user.id,
      content: content.trim(),
    });

    // Build notifications based on entity type
    const notifyUserIds = new Set();

    if (entity_type === 'task') {
      const { rows } = await pool.query(
        'SELECT assignee_id, reporter_id, title FROM tasks WHERE id = $1',
        [entity_id]
      );
      if (rows[0]) {
        if (rows[0].assignee_id && rows[0].assignee_id !== req.user.id) notifyUserIds.add(rows[0].assignee_id);
        if (rows[0].reporter_id && rows[0].reporter_id !== req.user.id) notifyUserIds.add(rows[0].reporter_id);
      }
    } else if (entity_type === 'delivery') {
      const { rows } = await pool.query(
        'SELECT uploaded_by, reviewed_by, title FROM delivery_jobs WHERE id = $1',
        [entity_id]
      );
      if (rows[0]) {
        if (rows[0].uploaded_by && rows[0].uploaded_by !== req.user.id) notifyUserIds.add(rows[0].uploaded_by);
        if (rows[0].reviewed_by && rows[0].reviewed_by !== req.user.id) notifyUserIds.add(rows[0].reviewed_by);
      }
    } else if (entity_type === 'project' && projectId) {
      // Notify all project managers
      const members = await Project.getMembers(projectId);
      members
        .filter(m => m.project_role === 'manager' && m.id !== req.user.id)
        .forEach(m => notifyUserIds.add(m.id));
    }

    if (notifyUserIds.size > 0) {
      const notifications = [];
      for (const uid of notifyUserIds) {
        notifications.push({
          userId: uid,
          type: 'comment',
          title: `New comment on ${entity_type}`,
          message: `${req.user.name}: ${content.substring(0, 200)}`,
          referenceId: entity_id,
          referenceType: entity_type,
        });
      }
      await Notification.createBulk(notifications);

      const io = req.app.get('io');
      if (io) {
        for (const uid of notifyUserIds) {
          io.to(`user:${uid}`).emit('notification', {
            type: 'comment',
            entity_type,
            entity_id,
            comment_id: comment.id,
          });
        }
      }
    }

    await logAudit({
      userId: req.user.id,
      action: 'create',
      entityType: 'comment',
      entityId: comment.id,
      details: { on_entity_type: entity_type, on_entity_id: entity_id, preview: content.substring(0, 100) },
      ipAddress: getClientIp(req),
    });

    // Emit socket event to project room
    if (projectId) {
      const io = req.app.get('io');
      if (io) {
        io.to(`project:${projectId}`).emit('comment_added', {
          ...comment,
          user_name: req.user.name,
          user_avatar: req.user.avatar_url,
        });
      }
    }

    // Fetch full comment with user info
    const fullComment = await Comment.findById(comment.id);
    res.status(201).json({ comment: fullComment });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
