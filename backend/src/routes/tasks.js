const express = require('express');
const Task = require('../models/Task');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const { requireProjectAccess, requireProjectRole } = require('../middleware/rbac');
const { logAudit, getClientIp } = require('../utils/audit');
const pool = require('../config/database');

const router = express.Router();

/**
 * Get all project members who should be notified about project activity.
 * Returns user IDs of managers and admins in the project, excluding the actor.
 */
async function getProjectNotifyIds(projectId, excludeUserId) {
  const { rows } = await pool.query(
    `SELECT DISTINCT pm.user_id FROM project_members pm
     JOIN users u ON pm.user_id = u.id
     WHERE pm.project_id = $1
       AND (pm.role IN ('manager', 'admin') OR u.role IN ('manager', 'admin'))
       AND pm.user_id != $2`,
    [projectId, excludeUserId]
  );
  return rows.map(r => r.user_id);
}

// All routes require auth
router.use(auth);

// GET /api/v1/projects/:projectId/tasks - list tasks for a project
router.get('/projects/:projectId/tasks', requireProjectAccess(), async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const { status, assignee, priority, search } = req.query;

    // Editors and freelancers can only see their own assigned tasks
    let assigneeId = assignee;
    if (req.projectRole === 'freelancer' || req.projectRole === 'editor') {
      assigneeId = req.user.id;
    }

    const tasks = await Task.findByProjectId(projectId, {
      status,
      assigneeId,
      priority,
      search,
    });

    // Group tasks by status for kanban view
    const kanban = {
      todo: tasks.filter((t) => t.status === 'todo'),
      in_progress: tasks.filter((t) => t.status === 'in_progress'),
      review: tasks.filter((t) => t.status === 'review'),
      done: tasks.filter((t) => t.status === 'done'),
    };

    res.json({ tasks, kanban });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:projectId/tasks - create task
// Managers and editors can create tasks. Freelancers and clients cannot.
router.post('/projects/:projectId/tasks', requireProjectRole('manager', 'editor'), async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const { title, description, status, priority, assigneeId, dueDate, parentTaskId, estimatedHours, tags } = req.body;

    if (!title || typeof title !== 'string' || title.trim().length === 0) {
      return res.status(400).json({ error: 'Task title is required.' });
    }

    if (status && !['todo', 'in_progress', 'review', 'done'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status.' });
    }

    if (priority && !['low', 'medium', 'high', 'urgent'].includes(priority)) {
      return res.status(400).json({ error: 'Invalid priority.' });
    }

    // Verify assignee is a member if provided
    if (assigneeId) {
      const assigneeMembership = await Project.isMember(projectId, assigneeId);
      if (!assigneeMembership && req.user.role !== 'admin') {
        return res.status(400).json({ error: 'Assignee must be a project member.' });
      }
    }

    // Verify parent task belongs to the same project
    if (parentTaskId) {
      const parentTask = await Task.findById(parentTaskId);
      if (!parentTask || parentTask.project_id !== projectId) {
        return res.status(400).json({ error: 'Parent task not found in this project.' });
      }
    }

    const task = await Task.create({
      projectId,
      title: title.trim(),
      description: description || null,
      status: status || 'todo',
      priority: priority || 'medium',
      assigneeId: assigneeId || null,
      reporterId: req.user.id,
      dueDate: dueDate || null,
      parentTaskId: parentTaskId || null,
      estimatedHours: estimatedHours || null,
      tags: tags || null,
    });

    // Handle multiple assignees via junction table
    const { assigneeIds } = req.body;
    const idsToAssign = assigneeIds && Array.isArray(assigneeIds) && assigneeIds.length > 0
      ? assigneeIds
      : (assigneeId ? [assigneeId] : []);

    for (const uid of idsToAssign) {
      await pool.query(
        'INSERT INTO task_assignees (task_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [task.id, uid]
      );
    }

    // Set legacy assignee_id to first assignee for backwards compat
    if (idsToAssign.length > 0 && !assigneeId) {
      await pool.query('UPDATE tasks SET assignee_id = $1 WHERE id = $2', [idsToAssign[0], task.id]);
    }

    // Enrich task with assignees before returning
    let taskWithAssignees = task;
    try {
      const enriched = await Task.enrichWithAssignees([task]);
      taskWithAssignees = enriched[0] || task;
    } catch (enrichErr) {
      console.error('Failed to enrich task with assignees:', enrichErr.message);
      taskWithAssignees.assignees = [];
    }

    // Notify all assignees
    const project = await Project.findById(projectId);
    const io = req.app.get('io');
    const notifiedIds = new Set();
    for (const uid of idsToAssign) {
      if (uid !== req.user.id) {
        notifiedIds.add(uid);
        await Notification.create({
          userId: uid,
          type: 'task_assigned',
          title: `Nova tarefa atribuída: "${task.title}"`,
          message: `${req.user.name} atribuiu uma tarefa a você no projeto "${project.name}".`,
          referenceId: task.id,
          referenceType: 'task',
        });
        if (io) {
          io.to(`user:${uid}`).emit('notification', {
            type: 'task_assigned',
            title: `Nova tarefa atribuída: "${task.title}"`,
            task_id: task.id,
          });
          io.to(`user:${uid}`).emit('task_assigned', taskWithAssignees);
        }
      }
    }

    // Notify project managers about new task creation
    const managerIds = await getProjectNotifyIds(projectId, req.user.id);
    for (const uid of managerIds) {
      if (!notifiedIds.has(uid)) {
        await Notification.create({
          userId: uid,
          type: 'task_updated',
          title: `Nova tarefa criada: "${task.title}"`,
          message: `${req.user.name} criou uma tarefa no projeto "${project.name}".`,
          referenceId: task.id,
          referenceType: 'task',
        });
        if (io) {
          io.to(`user:${uid}`).emit('notification', {
            type: 'task_updated',
            title: `Nova tarefa criada: "${task.title}"`,
            task_id: task.id,
          });
        }
      }
    }

    // Auto-create calendar event if task has a due date
    if (dueDate) {
      try {
        const startTime = new Date(dueDate);
        const endTime = new Date(startTime.getTime() + 60 * 60 * 1000); // +1 hour
        await pool.query(
          `INSERT INTO calendar_events (project_id, title, description, start_time, end_time, type, created_by)
           VALUES ($1, $2, $3, $4, $5, 'deadline', $6)`,
          [projectId, task.title, task.description || '', startTime, endTime, req.user.id]
        );
      } catch (calErr) {
        console.error('Failed to auto-create calendar event:', calErr.message);
      }
    }

    await logAudit({
      userId: req.user.id,
      action: 'create',
      entityType: 'task',
      entityId: task.id,
      details: { title: task.title, status: task.status, priority: task.priority, project_id: projectId },
      ipAddress: getClientIp(req),
    });

    if (io) {
      io.to(`project:${projectId}`).emit('task_created', taskWithAssignees);
    }

    res.status(201).json({ task: taskWithAssignees });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/tasks/:id - get task detail
router.get('/tasks/:id', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check project access
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(task.project_id, req.user.id);
      if (!membership && req.user.role !== 'manager') {
        return res.status(403).json({ error: 'Access denied.' });
      }
      // Editors and freelancers can only see tasks assigned to them
      if (membership && (membership.role === 'editor' || membership.role === 'freelancer')) {
        if (task.assignee_id !== req.user.id) {
          return res.status(403).json({ error: 'Access denied.' });
        }
      }
    }

    const subtasks = await Task.getSubtasks(task.id);
    const { rows: commentRows } = await pool.query(
      "SELECT COUNT(*)::int AS count FROM comments WHERE entity_type = 'task' AND entity_id = $1",
      [task.id]
    );

    res.json({
      task,
      subtasks,
      comment_count: commentRows[0].count,
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/tasks/:id - update task (log hours, change status, etc.)
router.put('/tasks/:id', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // RBAC: check who can update
    if (req.user.role !== 'admin') {
      const membership = await Project.isMember(task.project_id, req.user.id);
      if (!membership && req.user.role !== 'manager') {
        return res.status(403).json({ error: 'Access denied.' });
      }

      // Freelancers can only update their own tasks (status and hours)
      if (req.user.role === 'freelancer' || (membership && membership.role === 'freelancer')) {
        if (task.assignee_id !== req.user.id) {
          return res.status(403).json({ error: 'Freelancers can only update tasks assigned to them.' });
        }
        // Restrict which fields freelancers can change
        const allowedFields = ['status', 'actual_hours', 'actualHours'];
        const requestedFields = Object.keys(req.body);
        const disallowed = requestedFields.filter(f => !allowedFields.includes(f));
        if (disallowed.length > 0) {
          return res.status(403).json({ error: `Freelancers can only update: status, actual_hours.` });
        }
      }

      // Editors can update their assigned tasks or tasks they reported
      if (membership && membership.role === 'editor') {
        if (task.assignee_id !== req.user.id && task.reporter_id !== req.user.id) {
          return res.status(403).json({ error: 'Editors can only update tasks assigned to or reported by them.' });
        }
      }

      // Clients cannot update tasks
      if (req.user.role === 'client') {
        return res.status(403).json({ error: 'Clients cannot update tasks.' });
      }
    }

    const { title, description, status, priority, assigneeId, dueDate, parentTaskId, estimatedHours, actualHours, tags } = req.body;

    if (status && !['todo', 'in_progress', 'review', 'done'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status.' });
    }

    if (priority && !['low', 'medium', 'high', 'urgent'].includes(priority)) {
      return res.status(400).json({ error: 'Invalid priority.' });
    }

    const updates = {};
    if (title !== undefined) updates.title = title.trim();
    if (description !== undefined) updates.description = description;
    if (status !== undefined) updates.status = status;
    if (priority !== undefined) updates.priority = priority;
    if (assigneeId !== undefined) updates.assignee_id = assigneeId || null;
    if (dueDate !== undefined) updates.due_date = dueDate || null;
    if (parentTaskId !== undefined) updates.parent_task_id = parentTaskId || null;
    if (estimatedHours !== undefined) updates.estimated_hours = estimatedHours;
    if (actualHours !== undefined) updates.actual_hours = actualHours;
    if (tags !== undefined) updates.tags = tags;

    // Auto time tracking: manage timer on status changes
    if (status !== undefined && status !== task.status) {
      if (status === 'in_progress' && !task.timer_started_at) {
        // Starting work: set timer
        updates.timer_started_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
      } else if (status !== 'in_progress' && task.timer_started_at) {
        // Stopping work: calculate elapsed time and add to actual_hours
        const startedAt = new Date(task.timer_started_at);
        const now = new Date();
        const elapsedHours = (now - startedAt) / (1000 * 60 * 60);
        const currentActual = parseFloat(task.actual_hours) || 0;
        updates.actual_hours = Math.round((currentActual + elapsedHours) * 100) / 100;
        updates.timer_started_at = null;
      }
    }

    let updated = await Task.update(req.params.id, updates);
    // If no fields were updated (e.g. only assigneeIds sent), use the original task
    if (!updated) {
      updated = task;
    }

    // Check if actual_hours now exceeds estimated_hours and notify assignees
    if (updated && updated.estimated_hours && parseFloat(updated.actual_hours) > parseFloat(updated.estimated_hours)) {
      const prevActual = parseFloat(task.actual_hours) || 0;
      const wasNotOver = prevActual <= parseFloat(task.estimated_hours);
      if (wasNotOver) {
        // Just crossed the threshold - notify all assignees
        try {
          const { rows: taskAssignees } = await pool.query(
            'SELECT user_id FROM task_assignees WHERE task_id = $1',
            [req.params.id]
          );
          const project = await Project.findById(task.project_id);
          const overNotifications = [];
          const notifyIds = new Set();
          for (const ta of taskAssignees) {
            notifyIds.add(ta.user_id);
          }
          if (task.assignee_id) notifyIds.add(task.assignee_id);
          if (task.reporter_id) notifyIds.add(task.reporter_id);

          for (const uid of notifyIds) {
            overNotifications.push({
              userId: uid,
              type: 'hours_exceeded',
              title: `Horas excedidas: "${updated.title}"`,
              message: `A tarefa "${updated.title}" no projeto "${project ? project.name : ''}" ultrapassou as horas estimadas (${parseFloat(updated.actual_hours).toFixed(1)}h / ${updated.estimated_hours}h).`,
              referenceId: updated.id,
              referenceType: 'task',
            });
          }
          if (overNotifications.length > 0) {
            await Notification.createBulk(overNotifications);
            const io = req.app.get('io');
            if (io) {
              for (const uid of notifyIds) {
                io.to(`user:${uid}`).emit('notification', {
                  type: 'hours_exceeded',
                  title: `Horas excedidas: "${updated.title}"`,
                  task_id: updated.id,
                });
              }
            }
          }
        } catch (notifyErr) {
          console.error('Failed to send hours exceeded notification:', notifyErr.message);
        }
      }
    }

    // Auto-create calendar event when due date is set/changed
    if (dueDate !== undefined && dueDate && dueDate !== (task.due_date ? new Date(task.due_date).toISOString() : null)) {
      try {
        const startTime = new Date(dueDate);
        const endTime = new Date(startTime.getTime() + 60 * 60 * 1000);
        await pool.query(
          `INSERT INTO calendar_events (project_id, title, description, start_time, end_time, type, created_by)
           VALUES ($1, $2, $3, $4, $5, 'deadline', $6)`,
          [task.project_id, updated.title || task.title, updated.description || task.description || '', startTime, endTime, req.user.id]
        );
      } catch (calErr) {
        console.error('Failed to auto-create calendar event on task update:', calErr.message);
      }
    }

    // Sync multiple assignees if provided
    const { assigneeIds } = req.body;
    if (assigneeIds && Array.isArray(assigneeIds)) {
      try {
        // Remove all existing assignees and re-add
        await pool.query('DELETE FROM task_assignees WHERE task_id = $1', [req.params.id]);
        for (const uid of assigneeIds) {
          await pool.query(
            'INSERT INTO task_assignees (task_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [req.params.id, uid]
          );
        }
        // Update legacy assignee_id
        if (assigneeIds.length > 0) {
          await pool.query('UPDATE tasks SET assignee_id = $1 WHERE id = $2', [assigneeIds[0], req.params.id]);
        } else {
          await pool.query('UPDATE tasks SET assignee_id = NULL WHERE id = $1', [req.params.id]);
        }
      } catch (assigneeErr) {
        console.error('Failed to sync task assignees on update:', assigneeErr.message, assigneeErr.stack);
      }
    }

    // Re-fetch the task to get fresh data after assignee sync
    let enrichedTask;
    try {
      const freshTask = await Task.findById(req.params.id);
      if (freshTask) {
        await Task.enrichWithAssignees([freshTask]);
        enrichedTask = freshTask;
      } else {
        enrichedTask = updated;
        enrichedTask.assignees = [];
      }
    } catch (enrichErr) {
      console.error('Failed to enrich task with assignees on update:', enrichErr.message);
      enrichedTask = updated;
      enrichedTask.assignees = [];
    }

    // Notify on assignment change
    if (assigneeId && assigneeId !== task.assignee_id && assigneeId !== req.user.id) {
      const project = await Project.findById(task.project_id);
      await Notification.create({
        userId: assigneeId,
        type: 'task_assigned',
        title: `Task assigned: "${updated.title}"`,
        message: `${req.user.name} assigned you a task in "${project.name}".`,
        referenceId: updated.id,
        referenceType: 'task',
      });

      const io = req.app.get('io');
      if (io) {
        io.to(`user:${assigneeId}`).emit('notification', {
          type: 'task_assigned',
          title: `Task assigned: "${updated.title}"`,
          task_id: updated.id,
        });
        io.to(`user:${assigneeId}`).emit('task_assigned', updated);
      }
    }

    // Notify on status change
    if (status && status !== task.status) {
      const statusLabels = { todo: 'A fazer', in_progress: 'Em andamento', review: 'Em revisão', done: 'Concluído' };
      const notifyUserIds = new Set();
      if (task.assignee_id && task.assignee_id !== req.user.id) notifyUserIds.add(task.assignee_id);
      if (task.reporter_id && task.reporter_id !== req.user.id) notifyUserIds.add(task.reporter_id);

      // Also notify project managers
      const statusManagerIds = await getProjectNotifyIds(task.project_id, req.user.id);
      for (const mid of statusManagerIds) notifyUserIds.add(mid);

      const notifications = [];
      for (const uid of notifyUserIds) {
        notifications.push({
          userId: uid,
          type: 'task_updated',
          title: `Tarefa "${updated.title}" alterada`,
          message: `${req.user.name} alterou o status de "${statusLabels[task.status] || task.status}" para "${statusLabels[status] || status}".`,
          referenceId: updated.id,
          referenceType: 'task',
        });
      }
      if (notifications.length > 0) {
        await Notification.createBulk(notifications);
        const io = req.app.get('io');
        if (io) {
          for (const uid of notifyUserIds) {
            io.to(`user:${uid}`).emit('notification', {
              type: 'task_updated',
              title: `Tarefa "${updated.title}" alterada`,
              task_id: updated.id,
            });
          }
        }
      }
    }

    await logAudit({
      userId: req.user.id,
      action: 'update',
      entityType: 'task',
      entityId: req.params.id,
      details: updates,
      ipAddress: getClientIp(req),
    });

    const io2 = req.app.get('io');
    if (io2) {
      io2.to(`project:${task.project_id}`).emit('task_updated', enrichedTask);
    }

    res.json({ task: enrichedTask });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/tasks/:id - soft delete (move to trash)
// Only the task author (reporter) can delete
router.delete('/tasks/:id', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Only author (reporter) or admin can delete
    if (task.reporter_id !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Only the task author can delete this task.' });
    }

    const deleted = await Task.softDelete(req.params.id, req.user.id);

    await logAudit({
      userId: req.user.id,
      action: 'soft_delete',
      entityType: 'task',
      entityId: req.params.id,
      details: { title: task.title, project_id: task.project_id },
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${task.project_id}`).emit('task_updated', {
        id: task.id,
        deleted: true,
        project_id: task.project_id,
      });
    }

    res.json({ message: 'Task moved to trash.', task: deleted });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/tasks - list all tasks for the current user
router.get('/tasks', async (req, res, next) => {
  try {
    const { status, priority, search } = req.query;
    // Admin sees all tasks; manager sees tasks from their projects; others see assigned tasks
    let tasks;
    if (req.user.role === 'admin') {
      tasks = await Task.findAll({ status, priority });
    } else if (req.user.role === 'manager') {
      tasks = await Task.findAll({ status, priority, userId: req.user.id, userRole: 'manager' });
    } else {
      tasks = await Task.findByAssignee(req.user.id, { status, priority });
    }

    // Enrich with assignees
    await Task.enrichWithAssignees(tasks);

    res.json({ tasks });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/v1/tasks/:id/status - quick status update
router.patch('/tasks/:id/status', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    if (req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(task.project_id, req.user.id);
      if (!membership) {
        return res.status(403).json({ error: 'Access denied.' });
      }
    }

    const { status } = req.body;
    if (!status || !['todo', 'in_progress', 'review', 'done'].includes(status)) {
      return res.status(400).json({ error: 'Valid status is required.' });
    }

    // Auto time tracking for quick status change
    const statusUpdates = { status };
    if (status !== task.status) {
      if (status === 'in_progress' && !task.timer_started_at) {
        statusUpdates.timer_started_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
      } else if (status !== 'in_progress' && task.timer_started_at) {
        const startedAt = new Date(task.timer_started_at);
        const now = new Date();
        const elapsedHours = (now - startedAt) / (1000 * 60 * 60);
        const currentActual = parseFloat(task.actual_hours) || 0;
        statusUpdates.actual_hours = Math.round((currentActual + elapsedHours) * 100) / 100;
        statusUpdates.timer_started_at = null;
      }
    }

    const updated = await Task.update(req.params.id, statusUpdates);

    // Check if hours exceeded after auto-timer stop
    if (updated && updated.estimated_hours && parseFloat(updated.actual_hours) > parseFloat(updated.estimated_hours)) {
      const prevActual = parseFloat(task.actual_hours) || 0;
      if (prevActual <= parseFloat(task.estimated_hours)) {
        try {
          const { rows: taskAssignees } = await pool.query(
            'SELECT user_id FROM task_assignees WHERE task_id = $1',
            [req.params.id]
          );
          const project = await Project.findById(task.project_id);
          const notifyIds = new Set();
          for (const ta of taskAssignees) notifyIds.add(ta.user_id);
          if (task.assignee_id) notifyIds.add(task.assignee_id);
          if (task.reporter_id) notifyIds.add(task.reporter_id);

          const overNotifications = [];
          for (const uid of notifyIds) {
            overNotifications.push({
              userId: uid,
              type: 'hours_exceeded',
              title: `Horas excedidas: "${updated.title}"`,
              message: `A tarefa ultrapassou as horas estimadas (${parseFloat(updated.actual_hours).toFixed(1)}h / ${updated.estimated_hours}h).`,
              referenceId: updated.id,
              referenceType: 'task',
            });
          }
          if (overNotifications.length > 0) {
            await Notification.createBulk(overNotifications);
            const ioNotify = req.app.get('io');
            if (ioNotify) {
              for (const uid of notifyIds) {
                ioNotify.to(`user:${uid}`).emit('notification', {
                  type: 'hours_exceeded',
                  title: `Horas excedidas: "${updated.title}"`,
                  task_id: updated.id,
                });
              }
            }
          }
        } catch (notifyErr) {
          console.error('Failed to send hours exceeded notification:', notifyErr.message);
        }
      }
    }

    // Notify on status change
    if (status !== task.status) {
      const statusLabels2 = { todo: 'A fazer', in_progress: 'Em andamento', review: 'Em revisão', done: 'Concluído' };
      const notifyUserIds = new Set();
      if (task.assignee_id && task.assignee_id !== req.user.id) notifyUserIds.add(task.assignee_id);
      if (task.reporter_id && task.reporter_id !== req.user.id) notifyUserIds.add(task.reporter_id);

      // Also notify project managers
      const statusMgrIds = await getProjectNotifyIds(task.project_id, req.user.id);
      for (const mid of statusMgrIds) notifyUserIds.add(mid);

      const notifications = [];
      for (const uid of notifyUserIds) {
        notifications.push({
          userId: uid,
          type: 'task_updated',
          title: `Tarefa "${updated.title}" alterada`,
          message: `${req.user.name} alterou o status de "${statusLabels2[task.status] || task.status}" para "${statusLabels2[status] || status}".`,
          referenceId: updated.id,
          referenceType: 'task',
        });
      }
      if (notifications.length > 0) {
        await Notification.createBulk(notifications);
        const io = req.app.get('io');
        if (io) {
          for (const uid of notifyUserIds) {
            io.to(`user:${uid}`).emit('notification', {
              type: 'task_updated',
              title: `Tarefa "${updated.title}" alterada`,
              task_id: updated.id,
            });
          }
        }
      }
    }

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${task.project_id}`).emit('task_updated', updated);
    }

    res.json({ task: updated });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/v1/tasks/:id/hours - update actual hours
router.patch('/tasks/:id/hours', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    if (req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(task.project_id, req.user.id);
      if (!membership) {
        return res.status(403).json({ error: 'Access denied.' });
      }
    }

    const actualHours = req.body.actual_hours ?? req.body.actualHours;
    if (actualHours === undefined || actualHours === null) {
      return res.status(400).json({ error: 'actual_hours is required.' });
    }

    const updates = { actual_hours: parseFloat(actualHours) || 0 };

    // Auto-start timer when hours are first registered and timer isn't already running
    if (parseFloat(actualHours) > 0 && !task.timer_started_at) {
      updates.timer_started_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
    }

    const updated = await Task.update(req.params.id, updates);

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${task.project_id}`).emit('task_updated', updated);
    }

    res.json({ task: updated });
  } catch (err) {
    next(err);
  }
});

// PUT|PATCH /api/v1/tasks/:id/position - update kanban position
const positionHandler = async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check project access
    if (req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(task.project_id, req.user.id);
      if (!membership) {
        return res.status(403).json({ error: 'Access denied.' });
      }
      // Freelancers can only reposition their own tasks
      if (membership.role === 'freelancer' && task.assignee_id !== req.user.id) {
        return res.status(403).json({ error: 'Freelancers can only move their own tasks.' });
      }
    }

    const { status, position } = req.body;

    if (!status || !['todo', 'in_progress', 'review', 'done'].includes(status)) {
      return res.status(400).json({ error: 'Valid status is required.' });
    }

    if (position === undefined || typeof position !== 'number' || position < 0) {
      return res.status(400).json({ error: 'Valid position (non-negative integer) is required.' });
    }

    // Auto time tracking for kanban drag
    if (task.status !== status) {
      if (status === 'in_progress' && !task.timer_started_at) {
        await Task.update(req.params.id, {
          timer_started_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
        });
      } else if (status !== 'in_progress' && task.timer_started_at) {
        const startedAt = new Date(task.timer_started_at);
        const now = new Date();
        const elapsedHours = (now - startedAt) / (1000 * 60 * 60);
        const currentActual = parseFloat(task.actual_hours) || 0;
        await Task.update(req.params.id, {
          actual_hours: Math.round((currentActual + elapsedHours) * 100) / 100,
          timer_started_at: null,
        });
      }
    }

    const updated = await Task.updatePosition(req.params.id, status, position);

    if (task.status !== status) {
      await logAudit({
        userId: req.user.id,
        action: 'move',
        entityType: 'task',
        entityId: task.id,
        details: { title: task.title, from_status: task.status, to_status: status },
        ipAddress: getClientIp(req),
      });
    }

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${task.project_id}`).emit('task_updated', updated);
    }

    res.json({ task: updated });
  } catch (err) {
    next(err);
  }
};
router.put('/tasks/:id/position', positionHandler);
router.patch('/tasks/:id/position', positionHandler);

// POST /api/v1/tasks/:id/assignees - add assignees to task
router.post('/tasks/:id/assignees', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) return res.status(404).json({ error: 'Task not found.' });

    const { userIds } = req.body;
    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ error: 'userIds array is required.' });
    }

    for (const userId of userIds) {
      await pool.query(
        'INSERT INTO task_assignees (task_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [req.params.id, userId]
      );
    }

    // Also set first assignee as the legacy assignee_id for backwards compat
    if (!task.assignee_id && userIds.length > 0) {
      await pool.query('UPDATE tasks SET assignee_id = $1 WHERE id = $2', [userIds[0], req.params.id]);
    }

    // Fetch updated assignees
    const { rows: assignees } = await pool.query(
      `SELECT u.id, u.name, u.email, u.avatar_url
       FROM task_assignees ta JOIN users u ON ta.user_id = u.id
       WHERE ta.task_id = $1 ORDER BY ta.assigned_at`,
      [req.params.id]
    );

    // Notify new assignees
    const io = req.app.get('io');
    for (const userId of userIds) {
      if (userId !== req.user.id) {
        await Notification.create({
          userId,
          type: 'task_assigned',
          title: `Tarefa atribuída: "${task.title}"`,
          message: `${req.user.name} atribuiu você a uma tarefa.`,
          referenceId: task.id,
          referenceType: 'task',
        });
        if (io) {
          io.to(`user:${userId}`).emit('notification', { type: 'task_assigned', task_id: task.id });
        }
      }
    }

    res.json({ assignees });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/tasks/:id/assignees/:userId - remove assignee from task
router.delete('/tasks/:id/assignees/:userId', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) return res.status(404).json({ error: 'Task not found.' });

    await pool.query(
      'DELETE FROM task_assignees WHERE task_id = $1 AND user_id = $2',
      [req.params.id, req.params.userId]
    );

    // If removed user was the legacy assignee, update to next assignee or null
    if (task.assignee_id === req.params.userId) {
      const { rows } = await pool.query(
        'SELECT user_id FROM task_assignees WHERE task_id = $1 ORDER BY assigned_at LIMIT 1',
        [req.params.id]
      );
      await pool.query('UPDATE tasks SET assignee_id = $1 WHERE id = $2',
        [rows.length > 0 ? rows[0].user_id : null, req.params.id]);
    }

    // Fetch updated assignees
    const { rows: assignees } = await pool.query(
      `SELECT u.id, u.name, u.email, u.avatar_url
       FROM task_assignees ta JOIN users u ON ta.user_id = u.id
       WHERE ta.task_id = $1 ORDER BY ta.assigned_at`,
      [req.params.id]
    );

    res.json({ assignees });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/tasks/:id/assignees - list assignees
router.get('/tasks/:id/assignees', async (req, res, next) => {
  try {
    const { rows: assignees } = await pool.query(
      `SELECT u.id, u.name, u.email, u.avatar_url
       FROM task_assignees ta JOIN users u ON ta.user_id = u.id
       WHERE ta.task_id = $1 ORDER BY ta.assigned_at`,
      [req.params.id]
    );
    res.json({ assignees });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/users - list all approved users (for assignee selection)
router.get('/users', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, email, avatar_url, role FROM users WHERE is_approved = TRUE ORDER BY name ASC`
    );
    res.json({ users: rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
