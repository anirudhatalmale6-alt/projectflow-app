const express = require('express');
const Client = require('../models/Client');
const auth = require('../middleware/auth');
const { requireGlobalRole } = require('../middleware/rbac');
const { logAudit, getClientIp } = require('../utils/audit');

const router = express.Router();

// All client routes require authentication
router.use(auth);

// GET /api/v1/clients - list clients
// Accessible by: admin, manager
router.get('/', requireGlobalRole('admin', 'manager'), async (req, res, next) => {
  try {
    const { limit = 50, offset = 0, search } = req.query;

    const clients = await Client.findAll({
      limit: Math.min(parseInt(limit, 10) || 50, 200),
      offset: parseInt(offset, 10) || 0,
      search: search || undefined,
    });

    const total = await Client.count();

    res.json({
      clients,
      total,
      limit: parseInt(limit, 10) || 50,
      offset: parseInt(offset, 10) || 0,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/clients - create client
// Accessible by: admin, manager
router.post('/', requireGlobalRole('admin', 'manager'), async (req, res, next) => {
  try {
    const { name, email, phone, company, notes } = req.body;

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({ error: 'Client name is required.' });
    }

    if (email) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(email)) {
        return res.status(400).json({ error: 'Invalid email format.' });
      }
    }

    const client = await Client.create({
      name: name.trim(),
      email: email ? email.toLowerCase().trim() : null,
      phone: phone || null,
      company: company || null,
      notes: notes || null,
      createdBy: req.user.id,
    });

    await logAudit({
      userId: req.user.id,
      action: 'create',
      entityType: 'client',
      entityId: client.id,
      details: { name: client.name, company: client.company },
      ipAddress: getClientIp(req),
    });

    res.status(201).json({ client });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/clients/:id - get client details
// Accessible by: admin, manager
router.get('/:id', requireGlobalRole('admin', 'manager'), async (req, res, next) => {
  try {
    const client = await Client.findById(req.params.id);
    if (!client) {
      return res.status(404).json({ error: 'Client not found.' });
    }

    // Also get client's projects
    const { rows: projects } = await require('../config/database').query(
      `SELECT p.id, p.name, p.status, p.deadline, p.budget, p.currency, p.created_at
       FROM projects p
       WHERE p.client_id = $1
       ORDER BY p.created_at DESC`,
      [client.id]
    );

    res.json({ client, projects });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/clients/:id - update client
// Accessible by: admin, manager
router.put('/:id', requireGlobalRole('admin', 'manager'), async (req, res, next) => {
  try {
    const client = await Client.findById(req.params.id);
    if (!client) {
      return res.status(404).json({ error: 'Client not found.' });
    }

    const { name, email, phone, company, notes } = req.body;
    const updates = {};
    if (name !== undefined) updates.name = name.trim();
    if (email !== undefined) updates.email = email ? email.toLowerCase().trim() : null;
    if (phone !== undefined) updates.phone = phone;
    if (company !== undefined) updates.company = company;
    if (notes !== undefined) updates.notes = notes;

    const updated = await Client.update(req.params.id, updates);

    await logAudit({
      userId: req.user.id,
      action: 'update',
      entityType: 'client',
      entityId: req.params.id,
      details: updates,
      ipAddress: getClientIp(req),
    });

    res.json({ client: updated });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/clients/:id - delete client
// Accessible by: admin only
router.delete('/:id', requireGlobalRole('admin'), async (req, res, next) => {
  try {
    const client = await Client.findById(req.params.id);
    if (!client) {
      return res.status(404).json({ error: 'Client not found.' });
    }

    const deleted = await Client.delete(req.params.id);
    if (!deleted) {
      return res.status(400).json({ error: 'Could not delete client.' });
    }

    await logAudit({
      userId: req.user.id,
      action: 'delete',
      entityType: 'client',
      entityId: req.params.id,
      details: { name: client.name },
      ipAddress: getClientIp(req),
    });

    res.json({ message: 'Client deleted successfully.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
