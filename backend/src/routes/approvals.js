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
 * Admin, manager (global or project), and client (linked to project) can review.
 */
async function canReviewDelivery(user, delivery) {
  if (user.role === 'admin' || user.role === 'manager') return true;

  // Project managers
  const membership = await Project.isMember(delivery.project_id, user.id);
  if (membership && membership.role === 'manager') return true;

  // Clients linked to the project
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

    // Create approval record
    const approval = await Approval.create({
      deliveryId: delivery.id,
      status: 'approved',
      reviewerId: req.user.id,
      comments: comments || null,
    });

    // Update delivery status
    await DeliveryJob.update(delivery.id, {
      status: 'approved',
      reviewedBy: req.user.id,
      reviewNotes: comments || null,
    });

    // Notify the uploader
    if (delivery.uploaded_by && delivery.uploaded_by !== req.user.id) {
      await Notification.create({
        userId: delivery.uploaded_by,
        type: 'approval_result',
        title: `Delivery approved: "${delivery.title}" v${delivery.version}`,
        message: `${req.user.name} approved your delivery.${comments ? ` Comments: ${comments}` : ''}`,
        referenceId: delivery.id,
        referenceType: 'delivery',
      });

      const io = req.app.get('io');
      if (io) {
        io.to(`user:${delivery.uploaded_by}`).emit('notification', {
          type: 'approval_result',
          status: 'approved',
          delivery_id: delivery.id,
        });
      }
    }

    await logAudit({
      userId: req.user.id,
      action: 'approve',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { delivery_title: delivery.title, version: delivery.version, comments },
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${delivery.project_id}`).emit('approval_submitted', {
        delivery_id: delivery.id,
        status: 'approved',
        reviewer: req.user.name,
      });
      io.to(`project:${delivery.project_id}`).emit('delivery_status_changed', {
        id: delivery.id,
        status: 'approved',
        project_id: delivery.project_id,
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

    // Notify the uploader
    if (delivery.uploaded_by && delivery.uploaded_by !== req.user.id) {
      await Notification.create({
        userId: delivery.uploaded_by,
        type: 'approval_result',
        title: `Delivery rejected: "${delivery.title}" v${delivery.version}`,
        message: `${req.user.name} rejected your delivery. Reason: ${comments}`,
        referenceId: delivery.id,
        referenceType: 'delivery',
      });

      const io = req.app.get('io');
      if (io) {
        io.to(`user:${delivery.uploaded_by}`).emit('notification', {
          type: 'approval_result',
          status: 'rejected',
          delivery_id: delivery.id,
        });
      }
    }

    await logAudit({
      userId: req.user.id,
      action: 'reject',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { delivery_title: delivery.title, version: delivery.version, comments },
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${delivery.project_id}`).emit('approval_submitted', {
        delivery_id: delivery.id,
        status: 'rejected',
        reviewer: req.user.name,
      });
      io.to(`project:${delivery.project_id}`).emit('delivery_status_changed', {
        id: delivery.id,
        status: 'rejected',
        project_id: delivery.project_id,
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

    // Notify the uploader
    if (delivery.uploaded_by && delivery.uploaded_by !== req.user.id) {
      await Notification.create({
        userId: delivery.uploaded_by,
        type: 'approval_result',
        title: `Revision requested: "${delivery.title}" v${delivery.version}`,
        message: `${req.user.name} requested a revision. Notes: ${comments}`,
        referenceId: delivery.id,
        referenceType: 'delivery',
      });

      const io = req.app.get('io');
      if (io) {
        io.to(`user:${delivery.uploaded_by}`).emit('notification', {
          type: 'approval_result',
          status: 'revision_requested',
          delivery_id: delivery.id,
        });
      }
    }

    await logAudit({
      userId: req.user.id,
      action: 'request_revision',
      entityType: 'delivery',
      entityId: delivery.id,
      details: { delivery_title: delivery.title, version: delivery.version, comments },
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${delivery.project_id}`).emit('approval_submitted', {
        delivery_id: delivery.id,
        status: 'revision_requested',
        reviewer: req.user.name,
      });
      io.to(`project:${delivery.project_id}`).emit('delivery_status_changed', {
        id: delivery.id,
        status: 'revision_requested',
        project_id: delivery.project_id,
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

    // Check project access
    if (req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(delivery.project_id, req.user.id);
      if (!membership) {
        // Check client access
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
