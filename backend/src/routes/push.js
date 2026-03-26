const express = require('express');
const auth = require('../middleware/auth');
const PushService = require('../services/pushService');

const router = express.Router();

// All routes require auth
router.use(auth);

// GET /api/v1/push/vapid-key - get the public VAPID key
router.get('/vapid-key', (req, res) => {
  res.json({ publicKey: PushService.getPublicKey() });
});

// POST /api/v1/push/subscribe - save a push subscription
router.post('/subscribe', async (req, res, next) => {
  try {
    const { subscription } = req.body;
    if (!subscription || !subscription.endpoint) {
      return res.status(400).json({ error: 'Push subscription data is required.' });
    }

    await PushService.saveSubscription(req.user.id, subscription);
    res.json({ message: 'Push subscription saved.' });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/push/unsubscribe - remove a push subscription
router.post('/unsubscribe', async (req, res, next) => {
  try {
    const { endpoint } = req.body;
    if (!endpoint) {
      return res.status(400).json({ error: 'Endpoint is required.' });
    }

    await PushService.removeSubscription(req.user.id, endpoint);
    res.json({ message: 'Push subscription removed.' });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/push/test - send a test push notification
router.post('/test', async (req, res, next) => {
  try {
    await PushService.sendToUser(req.user.id, {
      title: 'Duozz Flow',
      body: 'Push notifications estao funcionando!',
      icon: '/icons/Icon-192.png',
    });
    res.json({ message: 'Test push sent.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
