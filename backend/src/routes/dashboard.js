const express = require('express');
const Task = require('../models/Task');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const pool = require('../config/database');

const router = express.Router();

// All routes require auth
router.use(auth);

// GET /api/v1/dashboard - role-aware dashboard
router.get('/', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;

    // Unread notifications count (all roles)
    const unreadNotifications = await Notification.getUnreadCount(userId);

    // -------------------------------------------------------
    // ADMIN / MANAGER: project overview
    // -------------------------------------------------------
    if (userRole === 'admin' || userRole === 'manager') {
      // All projects (or projects managed)
      const projects = await Project.findAll({
        limit: 20,
        userId,
        userRole,
      });

      // Global task summary
      const { rows: taskSummary } = await pool.query(
        `SELECT
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE status = 'todo')::int AS todo,
           COUNT(*) FILTER (WHERE status = 'in_progress')::int AS in_progress,
           COUNT(*) FILTER (WHERE status = 'review')::int AS review,
           COUNT(*) FILTER (WHERE status = 'done')::int AS done,
           COUNT(*) FILTER (WHERE due_date < NOW() AND status != 'done')::int AS overdue,
           COUNT(*) FILTER (WHERE due_date BETWEEN NOW() AND NOW() + INTERVAL '7 days' AND status != 'done')::int AS due_soon,
           COALESCE(SUM(estimated_hours), 0)::numeric AS total_estimated_hours,
           COALESCE(SUM(actual_hours), 0)::numeric AS total_actual_hours
         FROM tasks`
      );

      // Delivery summary
      const { rows: deliverySummary } = await pool.query(
        `SELECT
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE status = 'pending')::int AS pending,
           COUNT(*) FILTER (WHERE status = 'uploaded')::int AS uploaded,
           COUNT(*) FILTER (WHERE status = 'in_review')::int AS in_review,
           COUNT(*) FILTER (WHERE status = 'approved')::int AS approved,
           COUNT(*) FILTER (WHERE status = 'rejected')::int AS rejected,
           COUNT(*) FILTER (WHERE status = 'revision_requested')::int AS revision_requested
         FROM delivery_jobs`
      );

      // Recent audit activity
      const { rows: recentActivity } = await pool.query(
        `SELECT al.*, u.name AS user_name, u.avatar_url AS user_avatar
         FROM audit_log al
         LEFT JOIN users u ON al.user_id = u.id
         ORDER BY al.created_at DESC
         LIMIT 20`
      );

      // Team members summary
      const { rows: teamSummary } = await pool.query(
        `SELECT role, COUNT(*)::int AS count
         FROM users
         GROUP BY role
         ORDER BY count DESC`
      );

      return res.json({
        role: userRole,
        projects,
        task_summary: taskSummary[0],
        delivery_summary: deliverySummary[0],
        recent_activity: recentActivity,
        team_summary: teamSummary,
        unread_notifications: unreadNotifications,
      });
    }

    // -------------------------------------------------------
    // EDITOR / FREELANCER: their tasks
    // -------------------------------------------------------
    if (userRole === 'editor' || userRole === 'freelancer') {
      // My assigned tasks
      const myTasks = await Task.findByAssignee(userId);

      // Task summary for my tasks
      const { rows: taskSummary } = await pool.query(
        `SELECT
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE status = 'todo')::int AS todo,
           COUNT(*) FILTER (WHERE status = 'in_progress')::int AS in_progress,
           COUNT(*) FILTER (WHERE status = 'review')::int AS review,
           COUNT(*) FILTER (WHERE status = 'done')::int AS done,
           COUNT(*) FILTER (WHERE due_date < NOW() AND status != 'done')::int AS overdue,
           COUNT(*) FILTER (WHERE due_date BETWEEN NOW() AND NOW() + INTERVAL '7 days' AND status != 'done')::int AS due_soon,
           COALESCE(SUM(estimated_hours), 0)::numeric AS total_estimated_hours,
           COALESCE(SUM(actual_hours), 0)::numeric AS total_actual_hours
         FROM tasks
         WHERE assignee_id = $1`,
        [userId]
      );

      // My projects
      const { rows: myProjects } = await pool.query(
        `SELECT p.id, p.name, p.status, p.deadline, pm.role AS project_role,
           (SELECT COUNT(*)::int FROM tasks WHERE project_id = p.id AND assignee_id = $1 AND status != 'done') AS pending_tasks
         FROM projects p
         JOIN project_members pm ON p.id = pm.project_id
         WHERE pm.user_id = $1 AND p.status != 'archived'
         ORDER BY p.updated_at DESC
         LIMIT 10`,
        [userId]
      );

      // My recent deliveries
      const { rows: myDeliveries } = await pool.query(
        `SELECT dj.id, dj.title, dj.version, dj.status, dj.created_at,
           p.name AS project_name
         FROM delivery_jobs dj
         JOIN projects p ON dj.project_id = p.id
         WHERE dj.uploaded_by = $1
         ORDER BY dj.created_at DESC
         LIMIT 10`,
        [userId]
      );

      return res.json({
        role: userRole,
        my_tasks: myTasks,
        task_summary: taskSummary[0],
        my_projects: myProjects,
        my_deliveries: myDeliveries,
        unread_notifications: unreadNotifications,
      });
    }

    // -------------------------------------------------------
    // CLIENT: their projects and deliveries
    // -------------------------------------------------------
    if (userRole === 'client') {
      // Projects linked to the client
      const { rows: clientProjects } = await pool.query(
        `SELECT p.id, p.name, p.status, p.deadline, p.budget, p.currency,
           c.name AS client_name,
           (SELECT COUNT(*)::int FROM delivery_jobs WHERE project_id = p.id) AS delivery_count,
           (SELECT COUNT(*)::int FROM delivery_jobs WHERE project_id = p.id AND status = 'in_review') AS pending_review_count,
           (SELECT COUNT(*)::int FROM delivery_jobs WHERE project_id = p.id AND status = 'approved') AS approved_count
         FROM projects p
         JOIN clients c ON p.client_id = c.id
         JOIN users u ON u.email = c.email
         WHERE u.id = $1 AND p.status != 'archived'
         ORDER BY p.updated_at DESC`,
        [userId]
      );

      // Deliveries pending review for client's projects
      const projectIds = clientProjects.map(p => p.id);
      let pendingDeliveries = [];
      if (projectIds.length > 0) {
        const placeholders = projectIds.map((_, i) => `$${i + 1}`).join(', ');
        const { rows } = await pool.query(
          `SELECT dj.*, p.name AS project_name,
             u.name AS uploaded_by_name
           FROM delivery_jobs dj
           JOIN projects p ON dj.project_id = p.id
           LEFT JOIN users u ON dj.uploaded_by = u.id
           WHERE dj.project_id IN (${placeholders})
             AND dj.status IN ('uploaded', 'in_review')
           ORDER BY dj.created_at DESC
           LIMIT 20`,
          projectIds
        );
        pendingDeliveries = rows;
      }

      return res.json({
        role: userRole,
        projects: clientProjects,
        pending_deliveries: pendingDeliveries,
        unread_notifications: unreadNotifications,
      });
    }

    // Fallback for unknown roles
    res.json({
      role: userRole,
      message: 'No dashboard data available for your role.',
      unread_notifications: unreadNotifications,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
