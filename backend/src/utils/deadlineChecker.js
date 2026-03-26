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
             GROUP_CONCAT(DISTINCT pm.user_id) as member_ids
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
      const memberIds = project.member_ids ? project.member_ids.split(',') : [];
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
             GROUP_CONCAT(DISTINCT pm.user_id) as member_ids
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
      const memberIds = project.member_ids ? project.member_ids.split(',') : [];
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
 * Reminder system: re-notify users who have unread notifications older than 1h30.
 * Groups unread notifications and sends a single reminder per user.
 * Only sends one reminder per 1h30 per user.
 */
async function checkUnreadReminders(io) {
  try {
    // Find users with unread notifications older than 2 hours
    // but only if we haven't sent a reminder in the last 4 hours
    const { rows: usersWithUnread } = await pool.query(`
      SELECT n.user_id, COUNT(*) as unread_count
      FROM notifications n
      WHERE n.is_read = FALSE
        AND n.created_at < NOW() - INTERVAL 90 MINUTE
        AND NOT EXISTS (
          SELECT 1 FROM notifications r
          WHERE r.user_id = n.user_id
            AND r.type = 'reminder'
            AND r.created_at > NOW() - INTERVAL 90 MINUTE
        )
      GROUP BY n.user_id
      HAVING COUNT(*) > 0
    `);

    for (const row of usersWithUnread) {
      const count = parseInt(row.unread_count) || 0;
      if (count === 0) continue;

      await Notification.create({
        userId: row.user_id,
        type: 'reminder',
        title: `Você tem ${count} notificação${count > 1 ? 'ões' : ''} não lida${count > 1 ? 's' : ''}`,
        message: `Existem ${count} notificação${count > 1 ? 'ões' : ''} pendente${count > 1 ? 's' : ''} aguardando sua atenção.`,
        referenceId: null,
        referenceType: null,
      });

      if (io) {
        io.to(`user:${row.user_id}`).emit('notification', {
          type: 'reminder',
          title: `Você tem ${count} notificação${count > 1 ? 'ões' : ''} não lida${count > 1 ? 's' : ''}`,
          unread_count: count,
        });
      }
    }

    if (usersWithUnread.length > 0) {
      console.log(`[Reminder] Sent reminders to ${usersWithUnread.length} user(s)`);
    }
  } catch (err) {
    console.error('[Reminder] Error:', err.message);
  }
}

/**
 * Start the deadline checker and reminder intervals.
 * Deadlines: every 30 minutes. Reminders: every 1h30.
 */
function startDeadlineChecker(io) {
  // Run immediately on startup
  checkDeadlines(io);
  // Then every 30 minutes
  setInterval(() => checkDeadlines(io), 30 * 60 * 1000);
  console.log('[DeadlineChecker] Started - checking every 30 minutes');

  // Unread notification reminders - every 1h30
  setTimeout(() => checkUnreadReminders(io), 5 * 60 * 1000); // First run after 5 minutes
  setInterval(() => checkUnreadReminders(io), 90 * 60 * 1000);
  console.log('[Reminder] Started - checking every 1h30');
}

module.exports = { checkDeadlines, checkUnreadReminders, startDeadlineChecker };
