const express = require('express');
const Task = require('../models/Task');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const { requireProjectAccess, requireProjectRole } = require('../middleware/rbac');
const { logAudit, getClientIp } = require('../utils/audit');
const pool = require('../config/database');

const router = express.Router();

// All routes require auth
router.use(auth);

// GET /api/v1/projects/:projectId/tasks - list tasks for a project
router.get('/projects/:projectId/tasks', requireProjectAccess(), async (req, res, next) => {
  try {
    const { projectId } = req.params;
    const { status, assignee, priority, search } = req.query;

    // Freelancers can only see their own tasks
    let assigneeId = assignee;
    if (req.user.role === 'freelancer' && req.projectRole === 'freelancer') {
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

    // Notify assignee if different from reporter
    if (assigneeId && assigneeId !== req.user.id) {
      const project = await Project.findById(projectId);
      await Notification.create({
        userId: assigneeId,
        type: 'task_assigned',
        title: `New task assigned: "${task.title}"`,
        message: `${req.user.name} assigned you a task in "${project.name}".`,
        referenceId: task.id,
        referenceType: 'task',
      });

      const io = req.app.get('io');
      if (io) {
        io.to(`user:${assigneeId}`).emit('notification', {
          type: 'task_assigned',
          title: `New task assigned: "${task.title}"`,
          task_id: task.id,
        });
        io.to(`user:${assigneeId}`).emit('task_assigned', task);
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

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${projectId}`).emit('task_created', task);
    }

    res.status(201).json({ task });
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
        // Freelancers can only see tasks assigned to them
        if (req.user.role === 'freelancer' && task.assignee_id !== req.user.id) {
          return res.status(403).json({ error: 'Access denied.' });
        }
        if (!membership) {
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

    const updated = await Task.update(req.params.id, updates);

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
      const notifyUserIds = new Set();
      if (task.assignee_id && task.assignee_id !== req.user.id) notifyUserIds.add(task.assignee_id);
      if (task.reporter_id && task.reporter_id !== req.user.id) notifyUserIds.add(task.reporter_id);

      const notifications = [];
      for (const uid of notifyUserIds) {
        notifications.push({
          userId: uid,
          type: 'task_updated',
          title: `Task status changed: "${updated.title}"`,
          message: `${req.user.name} changed status from "${task.status}" to "${status}".`,
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
              title: `Task status changed: "${updated.title}"`,
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

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${task.project_id}`).emit('task_updated', updated);
    }

    res.json({ task: updated });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/tasks/:id - delete task
router.delete('/tasks/:id', async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Only admin, manager, or project manager can delete tasks
    if (req.user.role !== 'admin' && req.user.role !== 'manager') {
      const membership = await Project.isMember(task.project_id, req.user.id);
      if (!membership || membership.role !== 'manager') {
        // Editors can delete their own reported tasks
        if (membership && membership.role === 'editor' && task.reporter_id === req.user.id) {
          // OK, allow
        } else {
          return res.status(403).json({ error: 'Access denied. Only managers can delete tasks.' });
        }
      }
    }

    await Task.delete(req.params.id);

    await logAudit({
      userId: req.user.id,
      action: 'delete',
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

    res.json({ message: 'Task deleted successfully.' });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/tasks/:id/position - update kanban position
router.put('/tasks/:id/position', async (req, res, next) => {
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
});

module.exports = router;
