const express = require('express');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');

const router = express.Router();

// GET /api/notifications - list user's notifications
router.get('/', auth, async (req, res, next) => {
  try {
    const { limit = 50, offset = 0, unread } = req.query;

    const notifications = await Notification.findByUserId(req.user.id, {
      limit: Math.min(parseInt(limit, 10) || 50, 100),
      offset: parseInt(offset, 10) || 0,
      unreadOnly: unread === 'true',
    });

    const unreadCount = await Notification.getUnreadCount(req.user.id);

    res.json({ notifications, unread_count: unreadCount });
  } catch (err) {
    next(err);
  }
});

// PUT /api/notifications/:id/read - mark as read
router.put('/:id/read', auth, async (req, res, next) => {
  try {
    const notification = await Notification.markAsRead(req.params.id, req.user.id);
    if (!notification) {
      return res.status(404).json({ error: 'Notification not found.' });
    }

    res.json({ notification });
  } catch (err) {
    next(err);
  }
});

// PUT /api/notifications/read-all - mark all as read
router.put('/read-all', auth, async (req, res, next) => {
  try {
    const count = await Notification.markAllAsRead(req.user.id);
    res.json({ message: `Marked ${count} notifications as read.`, count });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
