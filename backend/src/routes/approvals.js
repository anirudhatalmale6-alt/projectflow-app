const express = require('express');
const Approval = require('../models/Approval');
const DeliveryJob = require('../models/DeliveryJob');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const { logAudit, getClientIp } = require('../utils/audit');
const pool = require('../config/database');

const router = express.Router();

// All routes require auth
router.use(auth);

/**
 * Helper: check if user can approve/reject a delivery.
 */
async function canReviewDelivery(user, delivery) {
  if (user.role === 'admin' || user.role === 'manager') return true;
  const membership = await Project.isMember(delivery.project_id, user.id);
  if (membership && membership.role === 'manager') return true;
  if (user.role === 'client') {
    const { rows } = await pool.query(
      `SELECT 1 FROM projects p
       JOIN clients c ON p.client_id = c.id
       JOIN users u ON u.email = c.email
       WHERE p.id = $1 AND u.id = $2`,
      [delivery.project_id, user.id]
    );
    return rows.length > 0;
  }
  return false;
}

/**
 * Get all user IDs who should be notified about a delivery event.
 * Includes: uploader, task assignees, task reporter, project managers/admins.
 */
async function getDeliveryNotifyIds(delivery, excludeUserId) {
  const ids = new Set();

  // Uploader
  if (delivery.uploaded_by && delivery.uploaded_by !== excludeUserId) {
    ids.add(delivery.uploaded_by);
  }

  // Task assignees and reporter (if delivery is linked to a task)
  if (delivery.task_id) {
    try {
      const { rows: taskRows } = await pool.query(
        'SELECT assignee_id, reporter_id FROM tasks WHERE id = $1',
        [delivery.task_id]
      );
      if (taskRows.length > 0) {
        if (taskRows[0].assignee_id) ids.add(taskRows[0].assignee_id);
        if (taskRows[0].reporter_id) ids.add(taskRows[0].reporter_id);
      }
      // Multiple assignees
      const { rows: assignees } = await pool.query(
        'SELECT user_id FROM task_assignees WHERE task_id = $1',
        [delivery.task_id]
      );
      for (const a of assignees) ids.add(a.user_id);
    } catch (_) {}
  }

  // Project managers and admins
  try {
    const { rows: members } = await pool.query(
      `SELECT DISTINCT pm.user_id FROM project_members pm
       JOIN users u ON pm.user_id = u.id
       WHERE pm.project_id = $1
         AND (pm.role IN ('manager', 'admin') OR u.role IN ('manager', 'admin'))`,
      [delivery.project_id]
    );
    for (const m of members) ids.add(m.user_id);
  } catch (_) {}

  // Remove the actor
  ids.delete(excludeUserId);
  return [...ids];
}

/**
 * Send notifications to multiple users with Socket.IO emit.
 */
async function notifyUsers(userIds, notifData, io) {
  if (userIds.length === 0) return;
  const notifications = userIds.map(uid => ({ userId: uid, ...notifData }));
  await Notification.createBulk(notifications);
  if (io) {
    for (const uid of userIds) {
      io.to(`user:${uid}`).emit('notification', {
        type: notifData.type,
        status: notifData.status || undefined,
        delivery_id: notifData.referenceId,
      });
    }
  }
}

// POST /api/v1/deliveries/:deliveryId/approve
router.post('/deliveries/:deliveryId/approve', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.deliveryId);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    const canReview = await canReviewDelivery(req.user, delivery);
    if (!canReview) {
      return res.status(403).json({ error: 'Access denied. Only managers and clients can approve deliveries.' });
    }

    const { comments } = req.body;

    const approval = await Approval.create({
      deliveryId: delivery.id,
      status: 'approved',
      reviewerId: req.user.id,
      comments: comments || null,
    });

    await DeliveryJob.update(delivery.id, {
      status: 'approved',
      reviewedBy: req.user.id,
      reviewNotes: comments || null,
    });

    // Notify all relevant people
    const notifyIds = await getDeliveryNotifyIds(delivery, req.user.id);
    const io = req.app.get('io');
    await notifyUsers(notifyIds, {
      type: 'approval_result',
      status: 'approved',
      title: `Entrega aprovada: "${delivery.title}" v${delivery.version}`,
      message: `${req.user.name} aprovou a entrega.${comments ? ` Comentário: ${comments}` : ''}`,
      referenceId: delivery.id,
      referenceType: 'delivery',
    }, io);

    await logAudit({
      userId: req.user.id,
      action: 'approve',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { delivery_title: delivery.title, version: delivery.version, comments },
      ipAddress: getClientIp(req),
    });

    if (io) {
      io.to(`project:${delivery.project_id}`).emit('approval_submitted', {
        delivery_id: delivery.id, status: 'approved', reviewer: req.user.name,
      });
      io.to(`project:${delivery.project_id}`).emit('delivery_status_changed', {
        id: delivery.id, status: 'approved', project_id: delivery.project_id,
      });
    }

    res.json({ message: 'Delivery approved.', approval });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/deliveries/:deliveryId/reject
router.post('/deliveries/:deliveryId/reject', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.deliveryId);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    const canReview = await canReviewDelivery(req.user, delivery);
    if (!canReview) {
      return res.status(403).json({ error: 'Access denied. Only managers and clients can reject deliveries.' });
    }

    const { comments } = req.body;
    if (!comments || typeof comments !== 'string' || comments.trim().length === 0) {
      return res.status(400).json({ error: 'Comments are required when rejecting a delivery.' });
    }

    const approval = await Approval.create({
      deliveryId: delivery.id,
      status: 'rejected',
      reviewerId: req.user.id,
      comments: comments.trim(),
    });

    await DeliveryJob.update(delivery.id, {
      status: 'rejected',
      reviewedBy: req.user.id,
      reviewNotes: comments.trim(),
    });

    // Notify all relevant people
    const notifyIds = await getDeliveryNotifyIds(delivery, req.user.id);
    const io = req.app.get('io');
    await notifyUsers(notifyIds, {
      type: 'approval_result',
      status: 'rejected',
      title: `Entrega rejeitada: "${delivery.title}" v${delivery.version}`,
      message: `${req.user.name} rejeitou a entrega. Motivo: ${comments}`,
      referenceId: delivery.id,
      referenceType: 'delivery',
    }, io);

    await logAudit({
      userId: req.user.id,
      action: 'reject',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { delivery_title: delivery.title, version: delivery.version, comments },
      ipAddress: getClientIp(req),
    });

    if (io) {
      io.to(`project:${delivery.project_id}`).emit('approval_submitted', {
        delivery_id: delivery.id, status: 'rejected', reviewer: req.user.name,
      });
      io.to(`project:${delivery.project_id}`).emit('delivery_status_changed', {
        id: delivery.id, status: 'rejected', project_id: delivery.project_id,
      });
    }

    res.json({ message: 'Delivery rejected.', approval });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/deliveries/:deliveryId/request-revision
router.post('/deliveries/:deliveryId/request-revision', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.deliveryId);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    const canReview = await canReviewDelivery(req.user, delivery);
    if (!canReview) {
      return res.status(403).json({ error: 'Access denied. Only managers and clients can request revisions.' });
    }

    const { comments } = req.body;
    if (!comments || typeof comments !== 'string' || comments.trim().length === 0) {
      return res.status(400).json({ error: 'Comments are required when requesting a revision.' });
    }

    const approval = await Approval.create({
      deliveryId: delivery.id,
      status: 'revision',
      reviewerId: req.user.id,
      comments: comments.trim(),
    });

    await DeliveryJob.update(delivery.id, {
      status: 'revision_requested',
      reviewedBy: req.user.id,
      reviewNotes: comments.trim(),
    });

    // Notify all relevant people
    const notifyIds = await getDeliveryNotifyIds(delivery, req.user.id);
    const io = req.app.get('io');
    await notifyUsers(notifyIds, {
      type: 'approval_result',
      status: 'revision_requested',
      title: `Revisão solicitada: "${delivery.title}" v${delivery.version}`,
      message: `${req.user.name} solicitou uma revisão. Notas: ${comments}`,
      referenceId: delivery.id,
      referenceType: 'delivery',
    }, io);

    await logAudit({
      userId: req.user.id,
      action: 'request_revision',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { delivery_title: delivery.title, version: delivery.version, comments },
      ipAddress: getClientIp(req),
    });

    if (io) {
      io.to(`project:${delivery.project_id}`).emit('approval_submitted', {
        delivery_id: delivery.id, status: 'revision_requested', reviewer: req.user.name,
      });
      io.to(`project:${delivery.project_id}`).emit('delivery_status_changed', {
        id: delivery.id, status: 'revision_requested', project_id: delivery.project_id,
      });
    }

    res.json({ message: 'Revision requested.', approval });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/deliveries/:deliveryId/approvals - approval history
router.get('/deliveries/:deliveryId/approvals', async (req, res, next) => {
  try {
    const delivery = await DeliveryJob.findById(req.params.deliveryId);
    if (!delivery) {
      return res.status(404).json({ error: 'Delivery not found.' });
    }

    if (req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      if (!membership) {
        if (req.user.role === 'client') {
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

    const approvals = await Approval.findByDeliveryId(req.params.deliveryId);
    res.json({ approvals });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
