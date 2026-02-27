const express = require('express');
const Project = require('../models/Project');
const Notification = require('../models/Notification');
const User = require('../models/User');
const auth = require('../middleware/auth');
const pool = require('../config/database');

const router = express.Router();

// GET /api/projects - list user's projects
router.get('/', auth, async (req, res, next) => {
  try {
    const projects = await Project.findByUserId(req.user.id);

    // Attach member count to each project
    const projectsWithCounts = await Promise.all(
      projects.map(async (project) => {
        const { rows } = await pool.query(
          'SELECT COUNT(*)::int AS member_count FROM project_members WHERE project_id = $1',
          [project.id]
        );
        const { rows: taskRows } = await pool.query(
          `SELECT COUNT(*)::int AS task_count,
                  COUNT(*) FILTER (WHERE status = 'done')::int AS done_count
           FROM tasks WHERE project_id = $1`,
          [project.id]
        );
        return {
          ...project,
          member_count: rows[0].member_count,
          task_count: taskRows[0].task_count,
          done_count: taskRows[0].done_count,
        };
      })
    );

    res.json({ projects: projectsWithCounts });
  } catch (err) {
    next(err);
  }
});

// POST /api/projects - create project
router.post('/', auth, async (req, res, next) => {
  try {
    const { name, description, color } = req.body;

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({ error: 'Project name is required.' });
    }

    const project = await Project.create({
      name: name.trim(),
      description: description || null,
      ownerId: req.user.id,
      color: color || '#6366f1',
    });

    // Emit socket event
    const io = req.app.get('io');
    if (io) {
      io.to(`user:${req.user.id}`).emit('project_created', project);
    }

    res.status(201).json({ project });
  } catch (err) {
    next(err);
  }
});

// GET /api/projects/:id - get project details
router.get('/:id', auth, async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Check membership
    const membership = await Project.isMember(project.id, req.user.id);
    if (!membership && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied. You are not a member of this project.' });
    }

    // Get members
    const members = await Project.getMembers(project.id);

    res.json({ project, members, user_role: membership ? membership.role : 'admin' });
  } catch (err) {
    next(err);
  }
});

// PUT /api/projects/:id - update project
router.put('/:id', auth, async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Check permission (owner or project admin)
    const membership = await Project.isMember(project.id, req.user.id);
    if (!membership || (membership.role !== 'owner' && membership.role !== 'admin')) {
      if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Access denied. Only project owners and admins can update projects.' });
      }
    }

    const { name, description, status, color } = req.body;
    const updates = {};
    if (name !== undefined) updates.name = name.trim();
    if (description !== undefined) updates.description = description;
    if (status !== undefined) {
      if (!['active', 'archived', 'completed'].includes(status)) {
        return res.status(400).json({ error: 'Invalid status. Must be active, archived, or completed.' });
      }
      updates.status = status;
    }
    if (color !== undefined) updates.color = color;

    const updated = await Project.update(req.params.id, updates);

    // Log activity
    await pool.query(
      `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
       VALUES ($1, $2, 'updated', 'project', $3, $4)`,
      [project.id, req.user.id, project.id, JSON.stringify(updates)]
    );

    // Emit socket event to project room
    const io = req.app.get('io');
    if (io) {
      io.to(`project:${project.id}`).emit('project_updated', updated);
    }

    res.json({ project: updated });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/projects/:id - archive project
router.delete('/:id', auth, async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Only owner or system admin can archive
    const membership = await Project.isMember(project.id, req.user.id);
    if ((!membership || membership.role !== 'owner') && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied. Only project owners can archive projects.' });
    }

    const archived = await Project.archive(req.params.id);

    // Log activity
    await pool.query(
      `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
       VALUES ($1, $2, 'archived', 'project', $3, $4)`,
      [project.id, req.user.id, project.id, JSON.stringify({ name: project.name })]
    );

    res.json({ message: 'Project archived successfully.', project: archived });
  } catch (err) {
    next(err);
  }
});

// POST /api/projects/:id/members - add member
router.post('/:id/members', auth, async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Check permission
    const membership = await Project.isMember(project.id, req.user.id);
    if (!membership || (membership.role !== 'owner' && membership.role !== 'admin')) {
      if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Access denied. Only project owners and admins can add members.' });
      }
    }

    const { userId, email, role = 'member' } = req.body;

    if (!['owner', 'admin', 'member', 'viewer'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role. Must be owner, admin, member, or viewer.' });
    }

    // Find user by id or email
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

    // Add member
    await Project.addMember(project.id, targetUser.id, role);

    // Create notification for the invited user
    await Notification.create({
      userId: targetUser.id,
      type: 'project_invite',
      title: `You were added to "${project.name}"`,
      message: `${req.user.name} added you to the project "${project.name}" as ${role}.`,
      referenceId: project.id,
      referenceType: 'project',
    });

    // Log activity
    await pool.query(
      `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
       VALUES ($1, $2, 'member_added', 'project', $3, $4)`,
      [project.id, req.user.id, project.id, JSON.stringify({ member_name: targetUser.name, role })]
    );

    // Emit socket events
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

// DELETE /api/projects/:id/members/:userId - remove member
router.delete('/:id/members/:userId', auth, async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Check permission (owner, project admin, or the member themselves)
    const membership = await Project.isMember(project.id, req.user.id);
    const isSelf = req.params.userId === req.user.id;

    if (!isSelf) {
      if (!membership || (membership.role !== 'owner' && membership.role !== 'admin')) {
        if (req.user.role !== 'admin') {
          return res.status(403).json({ error: 'Access denied. Only project owners and admins can remove members.' });
        }
      }
    }

    // Cannot remove the owner
    const targetMembership = await Project.isMember(project.id, req.params.userId);
    if (targetMembership && targetMembership.role === 'owner') {
      return res.status(400).json({ error: 'Cannot remove the project owner.' });
    }

    const removed = await Project.removeMember(req.params.id, req.params.userId);
    if (!removed) {
      return res.status(404).json({ error: 'Member not found in project.' });
    }

    // Log activity
    await pool.query(
      `INSERT INTO activity_log (project_id, user_id, action, entity_type, entity_id, details)
       VALUES ($1, $2, 'member_removed', 'project', $3, $4)`,
      [project.id, req.user.id, project.id, JSON.stringify({ removed_user_id: req.params.userId })]
    );

    const members = await Project.getMembers(project.id);
    res.json({ message: 'Member removed successfully.', members });
  } catch (err) {
    next(err);
  }
});

// GET /api/projects/:id/stats - project stats
router.get('/:id/stats', auth, async (req, res, next) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Check membership
    const membership = await Project.isMember(project.id, req.user.id);
    if (!membership && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied.' });
    }

    const stats = await Project.getStats(req.params.id);

    // Recent activity
    const { rows: recentActivity } = await pool.query(
      `SELECT al.*, u.name AS user_name, u.avatar_url AS user_avatar
       FROM activity_log al
       JOIN users u ON al.user_id = u.id
       WHERE al.project_id = $1
       ORDER BY al.created_at DESC
       LIMIT 20`,
      [req.params.id]
    );

    res.json({ stats, recent_activity: recentActivity });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
