const express = require('express');
const Task = require('../models/Task');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const pool = require('../config/database');

const router = express.Router();

// GET /api/projects/:projectId/tasks - list tasks
router.get('/projects/:projectId/tasks', auth, async (req, res, next) => {
  try {
    const { projectId } = req.params;

    // Check membership
    const membership = await Project.isMember(projectId, req.user.id);
    if (!membership && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied.' });
    }

    const { status, assignee, priority, search } = req.query;
    const tasks = await Task.findByProjectId(projectId, {
      status,
      assigneeId: assignee,
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

// POST /api/projects/:projectId/tasks - create task
router.post('/projects/:projectId/tasks', auth, async (req, res, next) => {
  try {
    const { projectId } = req.params;

    // Check membership (viewers cannot create tasks)
    const membership = await Project.isMember(projectId, req.user.id);
    if (!membership) {
      if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Access denied.' });
      }
    } else if (membership.role === 'viewer') {
      return res.status(403).json({ error: 'Viewers cannot create tasks.' });
    }

    const { title, description, status, priority, assigneeId, dueDate, parentTaskId } = req.body;

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
      if (!assigneeMembership) {
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
      }
    }

    // Emit socket event to project room
    const io = req.app.get('io');
    if (io) {
      io.to(`project:${projectId}`).emit('task_created', task);
    }

    res.status(201).json({ task });
  } catch (err) {
    next(err);
  }
});

// GET /api/tasks/:id - get task detail
router.get('/tasks/:id', auth, async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check membership
    const membership = await Project.isMember(task.project_id, req.user.id);
    if (!membership && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied.' });
    }

    // Get subtasks
    const subtasks = await Task.getSubtasks(task.id);

    // Get comment count
    const { rows } = await pool.query(
      'SELECT COUNT(*)::int AS count FROM comments WHERE task_id = $1',
      [task.id]
    );

    res.json({
      task,
      subtasks,
      comment_count: rows[0].count,
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/tasks/:id - update task
router.put('/tasks/:id', auth, async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check membership (viewers cannot update tasks)
    const membership = await Project.isMember(task.project_id, req.user.id);
    if (!membership) {
      if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Access denied.' });
      }
    } else if (membership.role === 'viewer') {
      return res.status(403).json({ error: 'Viewers cannot update tasks.' });
    }

    const { title, description, status, priority, assigneeId, dueDate, parentTaskId } = req.body;

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

    const updated = await Task.update(req.params.id, updates, req.user.id);

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
      }
    }

    // Notify on status change (notify assignee and reporter)
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

    // Emit socket event to project room
    const io = req.app.get('io');
    if (io) {
      io.to(`project:${task.project_id}`).emit('task_updated', updated);
    }

    res.json({ task: updated });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/tasks/:id - delete task
router.delete('/tasks/:id', auth, async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check permission (owner, admin, reporter)
    const membership = await Project.isMember(task.project_id, req.user.id);
    if (!membership) {
      if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Access denied.' });
      }
    } else if (membership.role === 'viewer' || membership.role === 'member') {
      // Members can only delete their own tasks
      if (task.reporter_id !== req.user.id) {
        return res.status(403).json({ error: 'You can only delete tasks you reported.' });
      }
    }

    await Task.delete(req.params.id, req.user.id);

    // Emit socket event
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

// PUT /api/tasks/:id/position - update kanban position
router.put('/tasks/:id/position', auth, async (req, res, next) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ error: 'Task not found.' });
    }

    // Check membership
    const membership = await Project.isMember(task.project_id, req.user.id);
    if (!membership) {
      if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Access denied.' });
      }
    } else if (membership.role === 'viewer') {
      return res.status(403).json({ error: 'Viewers cannot move tasks.' });
    }

    const { status, position } = req.body;

    if (!status || !['todo', 'in_progress', 'review', 'done'].includes(status)) {
      return res.status(400).json({ error: 'Valid status is required.' });
    }

    if (position === undefined || typeof position !== 'number' || position < 0) {
      return res.status(400).json({ error: 'Valid position (non-negative integer) is required.' });
    }

    const updated = await Task.updatePosition(req.params.id, status, position);

    // Log activity if status changed
    if (task.status !== status) {
      await pool.query(
        `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
         VALUES ($1, $2, 'moved', 'task', $3, $4)`,
        [task.project_id, req.user.id, task.id, JSON.stringify({
          title: task.title,
          from_status: task.status,
          to_status: status,
        })]
      );
    }

    // Emit socket event
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
