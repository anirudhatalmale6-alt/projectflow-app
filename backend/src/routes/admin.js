const express = require('express');
const User = require('../models/User');
const Project = require('../models/Project');
const Task = require('../models/Task');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');
const pool = require('../config/database');

const router = express.Router();

// All routes require auth + admin
router.use(auth, admin);

// GET /api/admin/users - list all users
router.get('/users', async (req, res, next) => {
  try {
    const { limit = 50, offset = 0, search } = req.query;

    let users;
    if (search) {
      users = await User.searchByName(search);
    } else {
      users = await User.findAll({
        limit: Math.min(parseInt(limit, 10) || 50, 200),
        offset: parseInt(offset, 10) || 0,
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
        return {
          ...user,
          project_count: projectCount[0].count,
          task_count: taskCount[0].count,
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

// PUT /api/admin/users/:id/role - change user role
router.put('/users/:id/role', async (req, res, next) => {
  try {
    const { role } = req.body;

    if (!role || !['admin', 'member'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role. Must be admin or member.' });
    }

    // Prevent self-demotion
    if (req.params.id === req.user.id && role !== 'admin') {
      return res.status(400).json({ error: 'Cannot change your own admin role.' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const updated = await User.updateRole(req.params.id, role);

    res.json({
      message: `User role updated to ${role}.`,
      user: updated,
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/admin/stats - global stats
router.get('/stats', async (req, res, next) => {
  try {
    const totalUsers = await User.count();
    const totalProjects = await Project.count();
    const totalTasks = await Task.countAll();

    // Tasks by status
    const { rows: tasksByStatus } = await pool.query(
      `SELECT
         status,
         COUNT(*)::int AS count
       FROM tasks
       GROUP BY status
       ORDER BY status`
    );

    // Tasks by priority
    const { rows: tasksByPriority } = await pool.query(
      `SELECT
         priority,
         COUNT(*)::int AS count
       FROM tasks
       GROUP BY priority
       ORDER BY priority`
    );

    // Projects by status
    const { rows: projectsByStatus } = await pool.query(
      `SELECT
         status,
         COUNT(*)::int AS count
       FROM projects
       GROUP BY status
       ORDER BY status`
    );

    // Recent activity (global)
    const { rows: recentActivity } = await pool.query(
      `SELECT al.*, u.name AS user_name, p.name AS project_name
       FROM activity_log al
       JOIN users u ON al.user_id = u.id
       JOIN projects p ON al.project_id = p.id
       ORDER BY al.created_at DESC
       LIMIT 50`
    );

    // Users registered per day (last 30 days)
    const { rows: userGrowth } = await pool.query(
      `SELECT
         DATE(created_at) AS date,
         COUNT(*)::int AS count
       FROM users
       WHERE created_at >= NOW() - INTERVAL '30 days'
       GROUP BY DATE(created_at)
       ORDER BY date ASC`
    );

    // Activity per day (last 30 days)
    const { rows: activityTrend } = await pool.query(
      `SELECT
         DATE(created_at) AS date,
         COUNT(*)::int AS count
       FROM activity_log
       WHERE created_at >= NOW() - INTERVAL '30 days'
       GROUP BY DATE(created_at)
       ORDER BY date ASC`
    );

    res.json({
      total_users: totalUsers,
      total_projects: totalProjects,
      total_tasks: totalTasks,
      tasks_by_status: tasksByStatus,
      tasks_by_priority: tasksByPriority,
      projects_by_status: projectsByStatus,
      recent_activity: recentActivity,
      user_growth: userGrowth,
      activity_trend: activityTrend,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
