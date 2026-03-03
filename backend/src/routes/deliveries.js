const express = require('express');
const DeliveryJob = require('../models/DeliveryJob');
const Project = require('../models/Project');
const Task = require('../models/Task');
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
    const { title, description, format, task_id, requires_approval } = req.body;

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
      taskId: task_id || null,
      title: title.trim(),
      description: description || null,
      format: format || null,
      fileUrl,
      fileSize,
      uploadedBy: req.user.id,
      requiresApproval: requires_approval !== undefined ? requires_approval : true,
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

// GET /api/v1/tasks/:taskId/deliveries - list deliveries for a specific task
router.get('/tasks/:taskId/deliveries', async (req, res, next) => {
  try {
    const { taskId } = req.params;
    const { status, limit = 50, offset = 0 } = req.query;

    // Verify task exists and user has access
    const Task = require('../models/Task');
    const task = await Task.findById(taskId);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check project access
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(task.project_id, req.user.id);
      if (!membership) {
        return res.status(403).json({ error: 'Access denied.' });
      }
    }

    const deliveries = await DeliveryJob.findByTaskId(taskId, {
      status: status || undefined,
      limit: Math.min(parseInt(limit, 10) || 50, 200),
      offset: parseInt(offset, 10) || 0,
    });

    res.json({ deliveries });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/tasks/:taskId/deliveries - upload a delivery for a specific task
router.post('/tasks/:taskId/deliveries', upload.single('file'), async (req, res, next) => {
  try {
    const { taskId } = req.params;
    const { title, description, format, requires_approval } = req.body;

    // Verify task exists
    const Task = require('../models/Task');
    const task = await Task.findById(taskId);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    const projectId = task.project_id;

    // Check project access
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(projectId, req.user.id);
      if (!membership) {
        return res.status(403).json({ error: 'Access denied.' });
      }
    }

    const deliveryTitle = (title && title.trim()) || task.title || 'Entrega';

    let fileUrl = req.body.file_url || null;
    let fileSize = req.body.file_size || null;

    if (req.file) {
      const result = await FileService.upload(req.file.buffer, req.file.originalname, req.file.mimetype, projectId);
      fileUrl = result.fileId;
      fileSize = result.size || req.file.size;
    }

    const delivery = await DeliveryJob.create({
      projectId,
      taskId,
      title: deliveryTitle,
      description: description || null,
      format: format || null,
      fileUrl,
      fileSize,
      uploadedBy: req.user.id,
      requiresApproval: requires_approval,
    });

    await logAudit({
      userId: req.user.id,
      action: 'create',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { title: delivery.title, task_id: taskId, project_id: projectId },
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

// DELETE /api/v1/deliveries/:id - soft delete (move to trash)
// Only uploader or managers can delete
router.delete('/deliveries/:id', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.id);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    // Check permissions: uploader, project manager, or admin
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      if (!membership) {
        return res.status(403).json({ error: 'Access denied.' });
      }
      // Approved files can only be deleted by admin or manager
      if (delivery.status === 'approved' && membership.role !== 'manager') {
        return res.status(403).json({ error: 'Approved files can only be deleted by administrators or managers.' });
      }
      if (membership.role !== 'manager' && delivery.uploaded_by !== req.user.id) {
        return res.status(403).json({ error: 'Only the uploader or a manager can delete this file.' });
      }
    }

    const deleted = await DeliveryJob.softDelete(req.params.id, req.user.id);

    await logAudit({
      userId: req.user.id,
      action: 'soft_delete',
      entityType: 'delivery',
      entityId: req.params.id,
      details: { title: delivery.title },
      ipAddress: getClientIp(req),
    });

    res.json({ message: 'File moved to trash.', delivery: deleted });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/trash - get current user's trash (deliveries, projects, tasks)
router.get('/trash', async (req, res, next) => {
  try {
    const deliveries = (await DeliveryJob.findTrashByUser(req.user.id)).map(d => ({ ...d, _type: 'delivery' }));
    const projects = (await Project.findTrash(req.user.id)).map(p => ({ ...p, _type: 'project' }));
    const tasks = (await Task.findTrash(req.user.id)).map(t => ({ ...t, _type: 'task' }));
    const items = [...deliveries, ...projects, ...tasks].sort(
      (a, b) => new Date(b.deleted_at) - new Date(a.deleted_at)
    );
    res.json({ items });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/trash/:id/restore - restore from trash
router.post('/trash/:id/restore', async (req, res, next) => {
  try {
    const { type } = req.query; // ?type=delivery|project|task

    if (type === 'project') {
      const restored = await Project.restore(req.params.id);
      if (!restored) return res.status(404).json({ error: 'Item not found in trash.' });
      return res.json({ message: 'Project restored.', item: restored });
    }

    if (type === 'task') {
      const restored = await Task.restore(req.params.id);
      if (!restored) return res.status(404).json({ error: 'Item not found in trash.' });
      return res.json({ message: 'Task restored.', item: restored });
    }

    // Default: delivery
    const delivery = await DeliveryJob.findById(req.params.id);
    if (!delivery || !delivery.deleted_at) {
      return res.status(404).json({ error: 'Item not found in trash.' });
    }

    if (req.user.role !== 'admin' && delivery.deleted_by !== req.user.id) {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      if (!membership || membership.role !== 'manager') {
        return res.status(403).json({ error: 'Access denied.' });
      }
    }

    const restored = await DeliveryJob.restore(req.params.id);
    res.json({ message: 'File restored.', item: restored });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/trash/:id - permanently delete from trash
router.delete('/trash/:id', async (req, res, next) => {
  try {
    const { type } = req.query;

    if (type === 'project') {
      await pool.query('DELETE FROM projects WHERE id = $1 AND deleted_at IS NOT NULL', [req.params.id]);
      return res.json({ message: 'Project permanently deleted.' });
    }

    if (type === 'task') {
      await pool.query('DELETE FROM tasks WHERE id = $1 AND deleted_at IS NOT NULL', [req.params.id]);
      return res.json({ message: 'Task permanently deleted.' });
    }

    const delivery = await DeliveryJob.findById(req.params.id);
    if (!delivery || !delivery.deleted_at) {
      return res.status(404).json({ error: 'Item not found in trash.' });
    }

    if (req.user.role !== 'admin' && delivery.deleted_by !== req.user.id) {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      if (!membership || membership.role !== 'manager') {
        return res.status(403).json({ error: 'Access denied.' });
      }
    }

    await DeliveryJob.permanentDelete(req.params.id);

    await logAudit({
      userId: req.user.id,
      action: 'permanent_delete',
      entityType: 'delivery',
      entityId: req.params.id,
      details: { title: delivery.title },
      ipAddress: getClientIp(req),
    });

    res.json({ message: 'File permanently deleted.' });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/trash - empty entire trash for current user
router.delete('/trash', async (req, res, next) => {
  try {
    const deliveries = await DeliveryJob.findTrashByUser(req.user.id);
    let deleted = 0;
    for (const item of deliveries) {
      await DeliveryJob.permanentDelete(item.id);
      deleted++;
    }
    // Also delete trashed projects and tasks
    const projResult = await pool.query('DELETE FROM projects WHERE deleted_at IS NOT NULL AND deleted_by = $1', [req.user.id]);
    deleted += projResult.rowCount;
    const taskResult = await pool.query('DELETE FROM tasks WHERE deleted_at IS NOT NULL AND deleted_by = $1', [req.user.id]);
    deleted += taskResult.rowCount;
    res.json({ message: `${deleted} items permanently deleted.`, count: deleted });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
