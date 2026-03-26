const express = require('express');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { requireProjectAccess, requireProjectManager, requireGlobalRole } = require('../middleware/rbac');
const { logAudit, getClientIp } = require('../utils/audit');
const pool = require('../config/database');
const DriveService = require('../services/driveService');

const router = express.Router();

// All routes require auth
router.use(auth);

// GET /api/v1/projects - list projects (filtered by role)
router.get('/', async (req, res, next) => {
  try {
    const { status, client_id, limit = 50, offset = 0 } = req.query;

    const projects = await Project.findAll({
      limit: Math.min(parseInt(limit, 10) || 50, 200),
      offset: parseInt(offset, 10) || 0,
      status: status || undefined,
      clientId: client_id || undefined,
      userId: req.user.id,
      userRole: req.user.role,
    });

    res.json({ projects });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects - create project
// Only admin and manager can create projects
router.post('/', requireGlobalRole('admin', 'manager'), async (req, res, next) => {
  try {
    const { name, description, client_id, status, deadline, budget, currency, color } = req.body;

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({ error: 'Project name is required.' });
    }

    const validStatuses = ['active', 'draft', 'in_progress', 'review', 'delivered', 'completed', 'archived'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({ error: `Invalid status. Must be one of: ${validStatuses.join(', ')}.` });
    }

    if (currency && !['BRL', 'USD', 'EUR'].includes(currency)) {
      return res.status(400).json({ error: 'Invalid currency. Must be BRL, USD, or EUR.' });
    }

    const project = await Project.create({
      name: name.trim(),
      description: description || null,
      clientId: client_id || null,
      status: status || 'active',
      deadline: deadline || null,
      budget: budget || null,
      currency: currency || 'BRL',
      color: color || null,
      createdBy: req.user.id,
    });

    await logAudit({
      userId: req.user.id,
      action: 'create',
      entityType: 'project',
      entityId: project.id,
      details: { name: project.name, status: project.status },
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`user:${req.user.id}`).emit('project_created', project);
    }

    // Auto-create Google Drive folder structure (non-blocking)
    DriveService.hasGoogleDrive(req.user.id).then(async (hasGD) => {
      if (!hasGD) return;
      try {
        const driveResult = await DriveService.createProjectFolders(req.user.id, project.name);
        await pool.query(
          'UPDATE projects SET drive_folder_id = $1, drive_folder_url = $2, drive_folders = $3 WHERE id = $4',
          [driveResult.drive_folder_id, driveResult.drive_folder_url, JSON.stringify(driveResult.drive_folders), project.id]
        );
        console.log(`Drive folders created for project ${project.id}`);
      } catch (e) {
        console.error(`Failed to create Drive folders for project ${project.id}:`, e.message);
      }
    }).catch(() => {});

    res.status(201).json({ project });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/projects/:id - project details with members, task stats, deliveries count
router.get('/:id', requireProjectAccess(), async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    const members = await Project.getMembers(project.id);
    const stats = await Project.getStats(project.id);

    res.json({
      project,
      members,
      stats,
      user_project_role: req.projectRole,
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/projects/:id - update project
// Only admin, global manager, or project manager
router.put('/:id', requireProjectManager(), async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    const { name, description, client_id, status, deadline, budget, currency, color } = req.body;

    const validStatuses = ['active', 'draft', 'in_progress', 'review', 'delivered', 'completed', 'archived'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({ error: `Invalid status. Must be one of: ${validStatuses.join(', ')}.` });
    }

    if (currency && !['BRL', 'USD', 'EUR'].includes(currency)) {
      return res.status(400).json({ error: 'Invalid currency. Must be BRL, USD, or EUR.' });
    }

    const updates = {};
    if (name !== undefined) updates.name = name.trim();
    if (description !== undefined) updates.description = description;
    if (client_id !== undefined) updates.client_id = client_id || null;
    if (status !== undefined) updates.status = status;
    if (deadline !== undefined) updates.deadline = deadline || null;
    if (budget !== undefined) updates.budget = budget;
    if (currency !== undefined) updates.currency = currency;
    if (color !== undefined) updates.color = color || null;

    const updated = await Project.update(req.params.id, updates);

    await logAudit({
      userId: req.user.id,
      action: 'update',
      entityType: 'project',
      entityId: project.id,
      details: updates,
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${project.id}`).emit('project_updated', updated);
    }

    res.json({ project: updated });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/projects/:id - soft delete (move to trash)
// Only the project author (created_by) can delete
router.delete('/:id', auth, async (req, res, next) => {
  try {
    // Use raw query to find even if findById filters deleted
    const { rows } = await pool.query(
      'SELECT * FROM projects WHERE id = $1 AND deleted_at IS NULL',
      [req.params.id]
    );
    const project = rows[0];
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Author, admin, or manager can delete
    if (project.created_by !== req.user.id && req.user.role !== 'admin' && req.user.role !== 'manager') {
      return res.status(403).json({ error: 'Only the project author, admin or manager can delete this project.' });
    }

    const deleted = await Project.softDelete(req.params.id, req.user.id);

    // Cascade: soft-delete all tasks belonging to this project
    await pool.query(
      'UPDATE tasks SET deleted_at = NOW(), deleted_by = $1 WHERE project_id = $2 AND deleted_at IS NULL',
      [req.user.id, req.params.id]
    );

    // Cascade: soft-delete all deliveries belonging to this project
    await pool.query(
      'UPDATE delivery_jobs SET deleted_at = NOW(), deleted_by = $1 WHERE project_id = $2 AND deleted_at IS NULL',
      [req.user.id, req.params.id]
    );

    await logAudit({
      userId: req.user.id,
      action: 'soft_delete',
      entityType: 'project',
      entityId: project.id,
      details: { name: project.name },
      ipAddress: getClientIp(req),
    });

    res.json({ message: 'Project moved to trash.', project: deleted });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/projects/:id/members - list project members
router.get('/:id/members', requireProjectAccess(), async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }
    const members = await Project.getMembers(req.params.id);
    res.json({ members });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:id/members - add member
// Only admin, global manager, or project manager
router.post('/:id/members', requireProjectManager(), async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    const { userId, email, role = 'editor' } = req.body;

    const validProjectRoles = ['manager', 'editor', 'freelancer'];
    if (!validProjectRoles.includes(role)) {
      return res.status(400).json({ error: `Invalid project role. Must be one of: ${validProjectRoles.join(', ')}.` });
    }

    // Find target user by id or email
    let targetUser;
    if (userId) {
      targetUser = await User.findById(userId);
    } else if (email) {
      targetUser = await User.findByEmail(email.toLowerCase().trim());
    } else {
      return res.status(400).json({ error: 'userId or email is required.' });
    }

    if (!targetUser) {
      return res.status(404).json({ error: 'User not found.' });
    }

    await Project.addMember(project.id, targetUser.id, role);

    // Notify the invited user
    await Notification.create({
      userId: targetUser.id,
      type: 'project_invite',
      title: `You were added to "${project.name}"`,
      message: `${req.user.name} added you to the project "${project.name}" as ${role}.`,
      referenceId: project.id,
      referenceType: 'project',
    });

    await logAudit({
      userId: req.user.id,
      action: 'add_member',
      entityType: 'project',
      entityId: project.id,
      details: { member_id: targetUser.id, member_name: targetUser.name, role },
      ipAddress: getClientIp(req),
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`project:${project.id}`).emit('member_joined', {
        project_id: project.id,
        user: targetUser,
        role,
      });
      io.to(`user:${targetUser.id}`).emit('notification', {
        type: 'project_invite',
        title: `You were added to "${project.name}"`,
        project_id: project.id,
      });
    }

    const members = await Project.getMembers(project.id);
    res.status(201).json({ message: 'Member added successfully.', members });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/v1/projects/:id/members/:userId - remove member
router.delete('/:id/members/:userId', requireProjectManager(), async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Cannot remove the project creator
    if (req.params.userId === project.created_by) {
      return res.status(400).json({ error: 'Cannot remove the project creator.' });
    }

    const removed = await Project.removeMember(req.params.id, req.params.userId);
    if (!removed) {
      return res.status(404).json({ error: 'Member not found in project.' });
    }

    await logAudit({
      userId: req.user.id,
      action: 'remove_member',
      entityType: 'project',
      entityId: project.id,
      details: { removed_user_id: req.params.userId },
      ipAddress: getClientIp(req),
    });

    const members = await Project.getMembers(project.id);
    res.json({ message: 'Member removed successfully.', members });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
