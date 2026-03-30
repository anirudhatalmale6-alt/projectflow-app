const express = require('express');
const auth = require('../middleware/auth');
const PushService = require('../services/pushService');
const FcmService = require('../services/fcmService');
const ApnsService = require('../services/apnsService');

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

// ======= FCM (Mobile Push) =======

// POST /api/v1/push/fcm/register - register FCM token
router.post('/fcm/register', async (req, res, next) => {
  try {
    const { token, platform } = req.body;
    if (!token) {
      return res.status(400).json({ error: 'FCM token is required.' });
    }

    await FcmService.saveToken(req.user.id, token, platform || 'ios');
    res.json({ message: 'FCM token registered.' });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/push/fcm/unregister - remove FCM token
router.post('/fcm/unregister', async (req, res, next) => {
  try {
    const { token } = req.body;
    if (!token) {
      return res.status(400).json({ error: 'FCM token is required.' });
    }

    await FcmService.removeToken(token);
    res.json({ message: 'FCM token removed.' });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/push/fcm/test - send a test FCM push
router.post('/fcm/test', async (req, res, next) => {
  try {
    await FcmService.sendToUser(req.user.id, {
      title: 'Duozz Flow',
      body: 'Push notifications nativas funcionando!',
      type: 'test',
    });
    res.json({ message: 'Test FCM push sent.' });
  } catch (err) {
    next(err);
  }
});

// ======= APNs (Direct iOS Push) =======

// POST /api/v1/push/apns/register - register APNs device token
router.post('/apns/register', async (req, res, next) => {
  try {
    const { token, platform } = req.body;
    if (!token) {
      return res.status(400).json({ error: 'Device token is required.' });
    }

    await ApnsService.saveToken(req.user.id, token, platform || 'ios');
    res.json({ message: 'APNs device token registered.' });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/push/apns/unregister - remove APNs device token
router.post('/apns/unregister', async (req, res, next) => {
  try {
    const { token } = req.body;
    if (!token) {
      return res.status(400).json({ error: 'Device token is required.' });
    }

    await ApnsService.removeToken(token);
    res.json({ message: 'APNs device token removed.' });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/push/apns/test - send a test APNs push
router.post('/apns/test', async (req, res, next) => {
  try {
    await ApnsService.sendToUser(req.user.id, {
      title: 'Duozz Flow',
      body: 'Push notifications iOS funcionando!',
      type: 'test',
    });
    res.json({ message: 'Test APNs push sent.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
