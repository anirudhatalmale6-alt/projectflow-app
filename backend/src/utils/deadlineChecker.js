/**
 * Deadline checker - runs periodically to create notifications
 * for overdue or approaching deadlines on projects and tasks.
 */
const pool = require('../config/database');
const Notification = require('../models/Notification');

async function checkDeadlines(io) {
  try {
    const now = new Date();

    // 1. Check overdue projects (deadline passed, not completed)
    const { rows: overdueProjects } = await pool.query(`
      SELECT p.id, p.name, p.deadline,
             ARRAY_AGG(DISTINCT pm.user_id) FILTER (WHERE pm.user_id IS NOT NULL) as member_ids
      FROM projects p
      LEFT JOIN project_members pm ON pm.project_id = p.id
      WHERE p.deadline < NOW()
        AND p.status NOT IN ('completed', 'cancelled')
        AND p.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM notifications n
          WHERE n.reference_id = p.id
            AND n.reference_type = 'project'
            AND n.type = 'deadline_overdue'
            AND n.created_at > NOW() - INTERVAL '24 hours'
        )
      GROUP BY p.id, p.name, p.deadline
    `);

    for (const project of overdueProjects) {
      const memberIds = project.member_ids || [];
      for (const userId of memberIds) {
        await Notification.create({
          userId,
          type: 'deadline_overdue',
          title: `Prazo excedido: "${project.name}"`,
          message: `O prazo do projeto "${project.name}" foi excedido em ${_timeSince(project.deadline)}.`,
          referenceId: project.id,
          referenceType: 'project',
        });
        if (io) {
          io.to(`user:${userId}`).emit('notification', {
            type: 'deadline_overdue',
            title: `Prazo excedido: "${project.name}"`,
          });
        }
      }
    }

    // 2. Check projects approaching deadline (within 24 hours)
    const { rows: approachingProjects } = await pool.query(`
      SELECT p.id, p.name, p.deadline,
             ARRAY_AGG(DISTINCT pm.user_id) FILTER (WHERE pm.user_id IS NOT NULL) as member_ids
      FROM projects p
      LEFT JOIN project_members pm ON pm.project_id = p.id
      WHERE p.deadline > NOW()
        AND p.deadline < NOW() + INTERVAL '24 hours'
        AND p.status NOT IN ('completed', 'cancelled')
        AND p.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM notifications n
          WHERE n.reference_id = p.id
            AND n.reference_type = 'project'
            AND n.type = 'deadline_approaching'
            AND n.created_at > NOW() - INTERVAL '24 hours'
        )
      GROUP BY p.id, p.name, p.deadline
    `);

    for (const project of approachingProjects) {
      const memberIds = project.member_ids || [];
      for (const userId of memberIds) {
        await Notification.create({
          userId,
          type: 'deadline_approaching',
          title: `Prazo próximo: "${project.name}"`,
          message: `O prazo do projeto "${project.name}" vence em ${_timeUntil(project.deadline)}.`,
          referenceId: project.id,
          referenceType: 'project',
        });
        if (io) {
          io.to(`user:${userId}`).emit('notification', {
            type: 'deadline_approaching',
            title: `Prazo próximo: "${project.name}"`,
          });
        }
      }
    }

    // 3. Check overdue tasks
    const { rows: overdueTasks } = await pool.query(`
      SELECT t.id, t.title, t.due_date, t.project_id, t.assignee_id, t.reporter_id,
             p.name as project_name
      FROM tasks t
      JOIN projects p ON p.id = t.project_id
      WHERE t.due_date < NOW()
        AND t.status NOT IN ('done')
        AND t.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM notifications n
          WHERE n.reference_id = t.id
            AND n.reference_type = 'task'
            AND n.type = 'deadline_overdue'
            AND n.created_at > NOW() - INTERVAL '24 hours'
        )
    `);

    for (const task of overdueTasks) {
      const notifyUsers = new Set();
      if (task.assignee_id) notifyUsers.add(task.assignee_id);
      if (task.reporter_id) notifyUsers.add(task.reporter_id);

      for (const userId of notifyUsers) {
        await Notification.create({
          userId,
          type: 'deadline_overdue',
          title: `Tarefa atrasada: "${task.title}"`,
          message: `A tarefa "${task.title}" no projeto "${task.project_name}" está atrasada por ${_timeSince(task.due_date)}.`,
          referenceId: task.id,
          referenceType: 'task',
        });
        if (io) {
          io.to(`user:${userId}`).emit('notification', {
            type: 'deadline_overdue',
            title: `Tarefa atrasada: "${task.title}"`,
          });
        }
      }
    }

    // 4. Check tasks approaching deadline (within 24 hours)
    const { rows: approachingTasks } = await pool.query(`
      SELECT t.id, t.title, t.due_date, t.project_id, t.assignee_id, t.reporter_id,
             p.name as project_name
      FROM tasks t
      JOIN projects p ON p.id = t.project_id
      WHERE t.due_date > NOW()
        AND t.due_date < NOW() + INTERVAL '24 hours'
        AND t.status NOT IN ('done')
        AND t.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM notifications n
          WHERE n.reference_id = t.id
            AND n.reference_type = 'task'
            AND n.type = 'deadline_approaching'
            AND n.created_at > NOW() - INTERVAL '24 hours'
        )
    `);

    for (const task of approachingTasks) {
      const notifyUsers = new Set();
      if (task.assignee_id) notifyUsers.add(task.assignee_id);
      if (task.reporter_id) notifyUsers.add(task.reporter_id);

      for (const userId of notifyUsers) {
        await Notification.create({
          userId,
          type: 'deadline_approaching',
          title: `Prazo próximo: "${task.title}"`,
          message: `A tarefa "${task.title}" vence em ${_timeUntil(task.due_date)}.`,
          referenceId: task.id,
          referenceType: 'task',
        });
        if (io) {
          io.to(`user:${userId}`).emit('notification', {
            type: 'deadline_approaching',
            title: `Prazo próximo: "${task.title}"`,
          });
        }
      }
    }

    const total = overdueProjects.length + approachingProjects.length + overdueTasks.length + approachingTasks.length;
    if (total > 0) {
      console.log(`[DeadlineChecker] Processed ${total} deadline alerts`);
    }
  } catch (err) {
    console.error('[DeadlineChecker] Error:', err.message);
  }
}

function _timeSince(date) {
  const d = new Date(date);
  const now = new Date();
  const diffMs = now - d;
  const hours = Math.floor(diffMs / (1000 * 60 * 60));
  const days = Math.floor(hours / 24);
  if (days > 0) return `${days} dia${days > 1 ? 's' : ''}`;
  if (hours > 0) return `${hours} hora${hours > 1 ? 's' : ''}`;
  return 'poucos minutos';
}

function _timeUntil(date) {
  const d = new Date(date);
  const now = new Date();
  const diffMs = d - now;
  const hours = Math.floor(diffMs / (1000 * 60 * 60));
  const days = Math.floor(hours / 24);
  if (days > 0) return `${days} dia${days > 1 ? 's' : ''}`;
  if (hours > 0) return `${hours} hora${hours > 1 ? 's' : ''}`;
  return 'poucos minutos';
}

/**
 * Start the deadline checker interval.
 * Runs every 30 minutes.
 */
function startDeadlineChecker(io) {
  // Run immediately on startup
  checkDeadlines(io);
  // Then every 30 minutes
  setInterval(() => checkDeadlines(io), 30 * 60 * 1000);
  console.log('[DeadlineChecker] Started - checking every 30 minutes');
}

module.exports = { checkDeadlines, startDeadlineChecker };
