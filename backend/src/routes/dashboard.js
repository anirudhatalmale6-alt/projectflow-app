const express = require('express');
const Task = require('../models/Task');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const pool = require('../config/database');

const router = express.Router();

// GET /api/dashboard - user dashboard
router.get('/', auth, async (req, res, next) => {
  try {
    const userId = req.user.id;

    // My tasks (assigned to me, not done)
    const myTasks = await Task.findByAssignee(userId);

    // Task summary
    const { rows: taskSummary } = await pool.query(
      `SELECT
         COUNT(*)::int AS total,
         COUNT(*) FILTER (WHERE status = 'todo')::int AS todo,
         COUNT(*) FILTER (WHERE status = 'in_progress')::int AS in_progress,
         COUNT(*) FILTER (WHERE status = 'review')::int AS review,
         COUNT(*) FILTER (WHERE status = 'done')::int AS done,
         COUNT(*) FILTER (WHERE due_date < NOW() AND status != 'done')::int AS overdue,
         COUNT(*) FILTER (WHERE due_date BETWEEN NOW() AND NOW() + INTERVAL '7 days' AND status != 'done')::int AS due_soon
       FROM tasks
       WHERE assignee_id = $1`,
      [userId]
    );

    // My projects summary
    const projects = await Project.findByUserId(userId);
    const projectSummaries = await Promise.all(
      projects.slice(0, 10).map(async (project) => {
        const { rows } = await pool.query(
          `SELECT
             COUNT(*)::int AS total_tasks,
             COUNT(*) FILTER (WHERE status = 'done')::int AS done_tasks
           FROM tasks WHERE project_id = $1`,
          [project.id]
        );
        return {
          id: project.id,
          name: project.name,
          color: project.color,
          status: project.status,
          member_role: project.member_role,
          total_tasks: rows[0].total_tasks,
          done_tasks: rows[0].done_tasks,
          progress: rows[0].total_tasks > 0
            ? Math.round((rows[0].done_tasks / rows[0].total_tasks) * 100)
            : 0,
        };
      })
    );

    // Recent activity across all user's projects
    const projectIds = projects.map((p) => p.id);
    let recentActivity = [];
    if (projectIds.length > 0) {
      const placeholders = projectIds.map((_, i) => `$${i + 1}`).join(', ');
      const { rows } = await pool.query(
        `SELECT al.*, u.name AS user_name, u.avatar_url AS user_avatar, p.name AS project_name
         FROM activity_log al
         JOIN users u ON al.user_id = u.id
         JOIN projects p ON al.project_id = p.id
         WHERE al.project_id IN (${placeholders})
         ORDER BY al.created_at DESC
         LIMIT 30`,
        projectIds
      );
      recentActivity = rows;
    }

    // Unread notifications count
    const unreadCount = await Notification.getUnreadCount(userId);

    res.json({
      my_tasks: myTasks,
      task_summary: taskSummary[0],
      projects: projectSummaries,
      recent_activity: recentActivity,
      unread_notifications: unreadCount,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
