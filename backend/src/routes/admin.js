const express = require('express');
const User = require('../models/User');
const Project = require('../models/Project');
const Task = require('../models/Task');
const DeliveryJob = require('../models/DeliveryJob');
const Client = require('../models/Client');
const auth = require('../middleware/auth');
const { requireGlobalRole } = require('../middleware/rbac');
const { logAudit, getClientIp } = require('../utils/audit');
const pool = require('../config/database');

const router = express.Router();

// All admin routes require auth + admin role
router.use(auth, requireGlobalRole('admin'));

// GET /api/v1/admin/users/pending - list pending approval users
router.get('/users/pending', async (req, res, next) => {
  try {
    const users = await User.findPending();
    res.json({ users, total: users.length });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/admin/users/:id/approve - approve a pending user
router.put('/users/:id/approve', async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    if (user.is_approved) {
      return res.status(400).json({ error: 'Usuário já está aprovado.' });
    }

    const updated = await User.updateApproval(req.params.id, true);

    await logAudit({
      userId: req.user.id,
      action: 'approve_user',
      entityType: 'user',
      entityId: req.params.id,
      details: { user_name: user.name, user_email: user.email },
      ipAddress: getClientIp(req),
    });

    res.json({
      message: `Usuário ${user.name} aprovado com sucesso.`,
      user: updated,
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/admin/users/:id/reject - reject (delete) a pending user
router.put('/users/:id/reject', async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    if (user.is_approved) {
      return res.status(400).json({ error: 'Não é possível rejeitar um usuário já aprovado.' });
    }

    // Delete the rejected user
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.params.id]);
    await pool.query('DELETE FROM users WHERE id = $1', [req.params.id]);

    await logAudit({
      userId: req.user.id,
      action: 'reject_user',
      entityType: 'user',
      entityId: req.params.id,
      details: { user_name: user.name, user_email: user.email },
      ipAddress: getClientIp(req),
    });

    res.json({ message: `Usuário ${user.name} rejeitado e removido.` });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/admin/users - list all users with stats
router.get('/users', async (req, res, next) => {
  try {
    const { limit = 50, offset = 0, search, role, is_approved } = req.query;

    let users;
    if (search) {
      users = await User.searchByName(search);
    } else {
      users = await User.findAll({
        limit: Math.min(parseInt(limit, 10) || 50, 200),
        offset: parseInt(offset, 10) || 0,
        role: role || undefined,
        is_approved: is_approved !== undefined ? is_approved === 'true' : undefined,
      });
    }

    const totalCount = await User.count();

    // Get per-user stats
    const usersWithStats = await Promise.all(
      users.map(async (user) => {
        const { rows: projectCount } = await pool.query(
          'SELECT COUNT(*)::int AS count FROM project_members WHERE user_id = $1',
          [user.id]
        );
        const { rows: taskCount } = await pool.query(
          'SELECT COUNT(*)::int AS count FROM tasks WHERE assignee_id = $1',
          [user.id]
        );
        const { rows: deliveryCount } = await pool.query(
          'SELECT COUNT(*)::int AS count FROM delivery_jobs WHERE uploaded_by = $1',
          [user.id]
        );
        return {
          ...user,
          project_count: projectCount[0].count,
          task_count: taskCount[0].count,
          delivery_count: deliveryCount[0].count,
        };
      })
    );

    res.json({
      users: usersWithStats,
      total: totalCount,
      limit: parseInt(limit, 10) || 50,
      offset: parseInt(offset, 10) || 0,
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/admin/users/:id/role - change user role
router.put('/users/:id/role', async (req, res, next) => {
  try {
    const { role } = req.body;

    const validRoles = ['admin', 'manager', 'editor', 'freelancer', 'client'];
    if (!role || !validRoles.includes(role)) {
      return res.status(400).json({ error: `Invalid role. Must be one of: ${validRoles.join(', ')}.` });
    }

    // Prevent self-demotion
    if (req.params.id === req.user.id && role !== 'admin') {
      return res.status(400).json({ error: 'Cannot change your own admin role.' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const previousRole = user.role;
    const updated = await User.updateRole(req.params.id, role);

    await logAudit({
      userId: req.user.id,
      action: 'change_role',
      entityType: 'user',
      entityId: req.params.id,
      details: { user_name: user.name, previous_role: previousRole, new_role: role },
      ipAddress: getClientIp(req),
    });

    res.json({
      message: `User role updated to ${role}.`,
      user: updated,
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/admin/stats - global platform stats
router.get('/stats', async (req, res, next) => {
  try {
    const totalUsers = await User.count();
    const totalProjects = await Project.count();
    const totalTasks = await Task.countAll();
    const totalDeliveries = await DeliveryJob.countAll();
    const totalClients = await Client.count();

    // Users by role
    const { rows: usersByRole } = await pool.query(
      `SELECT role, COUNT(*)::int AS count
       FROM users GROUP BY role ORDER BY count DESC`
    );

    // Tasks by status
    const { rows: tasksByStatus } = await pool.query(
      `SELECT status, COUNT(*)::int AS count
       FROM tasks GROUP BY status ORDER BY status`
    );

    // Tasks by priority
    const { rows: tasksByPriority } = await pool.query(
      `SELECT priority, COUNT(*)::int AS count
       FROM tasks GROUP BY priority ORDER BY priority`
    );

    // Projects by status
    const { rows: projectsByStatus } = await pool.query(
      `SELECT status, COUNT(*)::int AS count
       FROM projects GROUP BY status ORDER BY status`
    );

    // Deliveries by status
    const { rows: deliveriesByStatus } = await pool.query(
      `SELECT status, COUNT(*)::int AS count
       FROM delivery_jobs GROUP BY status ORDER BY status`
    );

    // Hours tracked
    const { rows: hoursTracked } = await pool.query(
      `SELECT
         COALESCE(SUM(estimated_hours), 0)::numeric AS total_estimated,
         COALESCE(SUM(actual_hours), 0)::numeric AS total_actual
       FROM tasks`
    );

    // Users registered per day (last 30 days)
    const { rows: userGrowth } = await pool.query(
      `SELECT DATE(created_at) AS date, COUNT(*)::int AS count
       FROM users
       WHERE created_at >= NOW() - INTERVAL '30 days'
       GROUP BY DATE(created_at)
       ORDER BY date ASC`
    );

    // Activity per day (last 30 days)
    const { rows: activityTrend } = await pool.query(
      `SELECT DATE(created_at) AS date, COUNT(*)::int AS count
       FROM audit_log
       WHERE created_at >= NOW() - INTERVAL '30 days'
       GROUP BY DATE(created_at)
       ORDER BY date ASC`
    );

    res.json({
      total_users: totalUsers,
      total_projects: totalProjects,
      total_tasks: totalTasks,
      total_deliveries: totalDeliveries,
      total_clients: totalClients,
      users_by_role: usersByRole,
      tasks_by_status: tasksByStatus,
      tasks_by_priority: tasksByPriority,
      projects_by_status: projectsByStatus,
      deliveries_by_status: deliveriesByStatus,
      hours_tracked: hoursTracked[0],
      user_growth: userGrowth,
      activity_trend: activityTrend,
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/admin/audit-log - paginated audit log
router.get('/audit-log', async (req, res, next) => {
  try {
    const { limit = 50, offset = 0, user_id, action, entity_type } = req.query;

    let query = `
      SELECT al.*, u.name AS user_name, u.email AS user_email, u.avatar_url AS user_avatar
      FROM audit_log al
      LEFT JOIN users u ON al.user_id = u.id
    `;
    const conditions = [];
    const values = [];
    let paramIndex = 1;

    if (user_id) {
      conditions.push(`al.user_id = $${paramIndex}`);
      values.push(user_id);
      paramIndex++;
    }

    if (action) {
      conditions.push(`al.action = $${paramIndex}`);
      values.push(action);
      paramIndex++;
    }

    if (entity_type) {
      conditions.push(`al.entity_type = $${paramIndex}`);
      values.push(entity_type);
      paramIndex++;
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    // Count total
    const countQuery = query.replace(/SELECT al\.\*, u\.name .* FROM/, 'SELECT COUNT(*)::int AS count FROM');
    const { rows: countRows } = await pool.query(countQuery, values);
    const total = countRows[0].count;

    query += ` ORDER BY al.created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    values.push(
      Math.min(parseInt(limit, 10) || 50, 200),
      parseInt(offset, 10) || 0
    );

    const { rows } = await pool.query(query, values);

    res.json({
      audit_log: rows,
      total,
      limit: parseInt(limit, 10) || 50,
      offset: parseInt(offset, 10) || 0,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/admin/users - create user (admin only)
router.post('/users', async (req, res, next) => {
  try {
    const { name, email, password, role, phone } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Nome, email e senha são obrigatórios.' });
    }

    const validRoles = ['admin', 'manager', 'editor', 'freelancer', 'client'];
    const userRole = role && validRoles.includes(role) ? role : 'editor';

    const existing = await User.findByEmail(email.toLowerCase().trim());
    if (existing) {
      return res.status(409).json({ error: 'Este email já está cadastrado.' });
    }

    const user = await User.create({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      password,
      role: userRole,
      phone: phone || null,
      is_approved: true,
    });

    await logAudit({
      userId: req.user.id,
      action: 'admin_create_user',
      entityType: 'user',
      entityId: user.id,
      details: { name: user.name, email: user.email, role: user.role },
      ipAddress: getClientIp(req),
    });

    res.status(201).json({ user });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/admin/users/:id - delete user (admin only)
router.delete('/users/:id', async (req, res, next) => {
  try {
    if (req.params.id === req.user.id) {
      return res.status(400).json({ error: 'Você não pode excluir sua própria conta.' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    // Remove from project memberships
    await pool.query('DELETE FROM project_members WHERE user_id = $1', [req.params.id]);
    // Remove refresh tokens
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.params.id]);
    // Delete user
    await pool.query('DELETE FROM users WHERE id = $1', [req.params.id]);

    await logAudit({
      userId: req.user.id,
      action: 'admin_delete_user',
      entityType: 'user',
      entityId: req.params.id,
      details: { name: user.name, email: user.email },
      ipAddress: getClientIp(req),
    });

    res.json({ message: 'Usuário excluído com sucesso.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
