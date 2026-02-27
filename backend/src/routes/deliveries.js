const express = require('express');
const DeliveryJob = require('../models/DeliveryJob');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const { requireProjectAccess, requireProjectRole } = require('../middleware/rbac');
const { logAudit, getClientIp } = require('../utils/audit');
const pool = require('../config/database');
const { upload } = require('../middleware/upload');
const FileService = require('../services/fileService');

const router = express.Router();

// All routes require auth
router.use(auth);

// GET /api/v1/projects/:projectId/deliveries - list delivery jobs for a project
router.get('/projects/:projectId/deliveries', requireProjectAccess(), async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const { status, limit = 50, offset = 0 } = req.query;

    const deliveries = await DeliveryJob.findByProjectId(projectId, {
      status: status || undefined,
      limit: Math.min(parseInt(limit, 10) || 50, 200),
      offset: parseInt(offset, 10) || 0,
    });

    res.json({ deliveries });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:projectId/deliveries - upload a delivery
// Editors and managers can upload deliveries. Freelancers cannot. Clients cannot.
router.post('/projects/:projectId/deliveries', requireProjectRole('manager', 'editor'), upload.single('file'), async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const { title, description, format } = req.body;

    if (!title || typeof title !== 'string' || title.trim().length === 0) {
      return res.status(400).json({ error: 'Delivery title is required.' });
    }

    let fileUrl = req.body.file_url || null;
    let fileSize = req.body.file_size || null;

    // Handle file upload if a file was provided
    if (req.file) {
      const result = await FileService.upload(req.file.buffer, req.file.originalname, req.file.mimetype, projectId);
      fileUrl = result.fileId;
      fileSize = result.size || req.file.size;
    }

    const delivery = await DeliveryJob.create({
      projectId,
      title: title.trim(),
      description: description || null,
      format: format || null,
      fileUrl,
      fileSize,
      uploadedBy: req.user.id,
    });

    // Notify project managers about the new delivery
    const members = await Project.getMembers(projectId);
    const project = await Project.findById(projectId);
    const managerIds = members
      .filter(m => m.project_role === 'manager' && m.id !== req.user.id)
      .map(m => m.id);

    if (managerIds.length > 0) {
      const notifications = managerIds.map(uid => ({
        userId: uid,
        type: 'delivery_uploaded',
        title: `New delivery: "${delivery.title}" v${delivery.version}`,
        message: `${req.user.name} uploaded a delivery in "${project.name}".`,
        referenceId: delivery.id,
        referenceType: 'delivery',
      }));
      await Notification.createBulk(notifications);

      const io = req.app.get('io');
      if (io) {
        for (const uid of managerIds) {
          io.to(`user:${uid}`).emit('notification', {
            type: 'delivery_uploaded',
            title: `New delivery: "${delivery.title}" v${delivery.version}`,
            delivery_id: delivery.id,
          });
        }
        io.to(`project:${projectId}`).emit('delivery_uploaded', delivery);
      }
    }

    // Notify client (if project has a client linked with a user account)
    if (project.client_id) {
      const { rows: clientUsers } = await pool.query(
        `SELECT u.id FROM users u
         JOIN clients c ON u.email = c.email
         WHERE c.id = $1 AND u.role = 'client'`,
        [project.client_id]
      );
      for (const cu of clientUsers) {
        await Notification.create({
          userId: cu.id,
          type: 'approval_requested',
          title: `New delivery ready for review: "${delivery.title}"`,
          message: `A new version (v${delivery.version}) has been uploaded for "${project.name}".`,
          referenceId: delivery.id,
          referenceType: 'delivery',
        });

        const io = req.app.get('io');
        if (io) {
          io.to(`user:${cu.id}`).emit('notification', {
            type: 'approval_requested',
            delivery_id: delivery.id,
          });
        }
      }
    }

    await logAudit({
      userId: req.user.id,
      action: 'create',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { title: delivery.title, version: delivery.version, format: delivery.format, project_id: projectId },
      ipAddress: getClientIp(req),
    });

    res.status(201).json({ delivery });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/deliveries/:id - get delivery detail
router.get('/deliveries/:id', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.id);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    // Check project access
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      const isClientAccess = req.user.role === 'client';

      if (!membership && req.user.role !== 'manager') {
        if (isClientAccess) {
          // Check if client is linked to the project
          const { rows } = await pool.query(
            `SELECT 1 FROM projects p
             JOIN clients c ON p.client_id = c.id
             JOIN users u ON u.email = c.email
             WHERE p.id = $1 AND u.id = $2`,
            [delivery.project_id, req.user.id]
          );
          if (rows.length === 0) {
            return res.status(403).json({ error: 'Access denied.' });
          }
        } else {
          return res.status(403).json({ error: 'Access denied.' });
        }
      }
    }

    // Get approval history
    const { rows: approvals } = await pool.query(
      `SELECT a.*, u.name AS reviewer_name, u.avatar_url AS reviewer_avatar
       FROM approvals a
       JOIN users u ON a.reviewer_id = u.id
       WHERE a.delivery_id = $1
       ORDER BY a.created_at DESC`,
      [delivery.id]
    );

    // Get comments
    const { rows: comments } = await pool.query(
      `SELECT c.*, u.name AS user_name, u.avatar_url AS user_avatar
       FROM comments c
       JOIN users u ON c.user_id = u.id
       WHERE c.entity_type = 'delivery' AND c.entity_id = $1
       ORDER BY c.created_at ASC`,
      [delivery.id]
    );

    res.json({ delivery, approvals, comments });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/deliveries/:id/download - get presigned download URL for delivery file
router.get('/deliveries/:id/download', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.id);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    // Check project access
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      const isClientAccess = req.user.role === 'client';

      if (!membership && req.user.role !== 'manager') {
        if (isClientAccess) {
          const { rows } = await pool.query(
            `SELECT 1 FROM projects p
             JOIN clients c ON p.client_id = c.id
             JOIN users u ON u.email = c.email
             WHERE p.id = $1 AND u.id = $2`,
            [delivery.project_id, req.user.id]
          );
          if (rows.length === 0) {
            return res.status(403).json({ error: 'Access denied.' });
          }
        } else {
          return res.status(403).json({ error: 'Access denied.' });
        }
      }
    }

    if (!delivery.file_url) {
      return res.status(404).json({ error: 'No file attached to this delivery.' });
    }

    const downloadUrl = await FileService.getDownloadUrl(delivery.file_url);

    res.json({ download_url: downloadUrl });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/deliveries/:id - update delivery
// Only uploader or managers can update
router.put('/deliveries/:id', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.id);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    // Check permissions
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      if (!membership && req.user.role !== 'manager') {
        return res.status(403).json({ error: 'Access denied.' });
      }
      if (membership && membership.role !== 'manager') {
        // Editors can only update their own deliveries
        if (delivery.uploaded_by !== req.user.id) {
          return res.status(403).json({ error: 'You can only update deliveries you uploaded.' });
        }
      }
    }

    const { title, description, format, file_url, file_size, status } = req.body;

    const validStatuses = ['pending', 'uploaded', 'in_review', 'approved', 'rejected', 'revision_requested'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({ error: `Invalid status. Must be one of: ${validStatuses.join(', ')}.` });
    }

    const updates = {};
    if (title !== undefined) updates.title = title.trim();
    if (description !== undefined) updates.description = description;
    if (format !== undefined) updates.format = format;
    if (file_url !== undefined) updates.fileUrl = file_url;
    if (file_size !== undefined) updates.fileSize = file_size;
    if (status !== undefined) updates.status = status;

    const updated = await DeliveryJob.update(req.params.id, updates);

    await logAudit({
      userId: req.user.id,
      action: 'update',
      entityType: 'delivery',
      entityId: req.params.id,
      details: updates,
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${delivery.project_id}`).emit('delivery_status_changed', updated);
    }

    res.json({ delivery: updated });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
