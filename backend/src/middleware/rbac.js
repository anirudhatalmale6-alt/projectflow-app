const pool = require('../config/database');

/**
 * RBAC (Role-Based Access Control) middleware for the video editing platform.
 *
 * Checks BOTH the user's global role AND their project-level role.
 *
 * Global roles hierarchy: admin > manager > editor > freelancer > client
 * Project roles: manager, editor, freelancer
 *
 * Usage:
 *   rbac.requireGlobalRole('admin', 'manager')       -- only admin or manager
 *   rbac.requireProjectRole('manager', 'editor')     -- project-level role check
 *   rbac.requireProjectAccess()                       -- any project member or admin
 */

// Global role hierarchy (higher number = more access)
const ROLE_HIERARCHY = {
  client: 1,
  freelancer: 2,
  editor: 3,
  manager: 4,
  admin: 5,
};

/**
 * Require the user to have one of the specified global roles.
 */
function requireGlobalRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    if (req.user.role === 'admin') {
      // Admin always passes global role checks
      return next();
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: `Access denied. Required role: ${allowedRoles.join(' or ')}.`,
      });
    }

    next();
  };
}

/**
 * Require the user to be a member of the project (from req.params.projectId or req.params.id)
 * with one of the specified project roles, OR be an admin/manager globally.
 *
 * Also attaches req.projectRole with the user's project-level role.
 *
 * If allowedProjectRoles is empty, any project member is allowed.
 */
function requireProjectRole(...allowedProjectRoles) {
  return async (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required.' });
      }

      const projectId = req.params.projectId || req.params.id;
      if (!projectId) {
        return res.status(400).json({ error: 'Project ID is required.' });
      }

      // Admin has full access
      if (req.user.role === 'admin') {
        req.projectRole = 'admin';
        return next();
      }

      // Check project membership
      const { rows } = await pool.query(
        'SELECT role FROM project_members WHERE project_id = $1 AND user_id = $2',
        [projectId, req.user.id]
      );

      if (rows.length === 0) {
        // Global managers can access any project
        if (req.user.role === 'manager') {
          req.projectRole = 'manager';
          return next();
        }

        // Clients can view their own projects
        if (req.user.role === 'client') {
          const { rows: projectRows } = await pool.query(
            `SELECT p.id FROM projects p
             JOIN clients c ON p.client_id = c.id
             JOIN users u ON u.email = c.email
             WHERE p.id = $1 AND u.id = $2`,
            [projectId, req.user.id]
          );
          if (projectRows.length > 0) {
            req.projectRole = 'client';
            return next();
          }
        }

        return res.status(403).json({ error: 'Access denied. You are not a member of this project.' });
      }

      const projectRole = rows[0].role;
      req.projectRole = projectRole;

      // If specific project roles are required, check them
      if (allowedProjectRoles.length > 0 && !allowedProjectRoles.includes(projectRole)) {
        return res.status(403).json({
          error: `Access denied. Required project role: ${allowedProjectRoles.join(' or ')}.`,
        });
      }

      next();
    } catch (err) {
      next(err);
    }
  };
}

/**
 * Require the user to be a member of the project (any role) or be admin/manager.
 */
function requireProjectAccess() {
  return requireProjectRole(); // No specific roles = any member
}

/**
 * Check if a user's global role meets a minimum level.
 */
function hasMinimumRole(userRole, minimumRole) {
  return (ROLE_HIERARCHY[userRole] || 0) >= (ROLE_HIERARCHY[minimumRole] || 0);
}

/**
 * Middleware that checks if the user can manage a specific project
 * (is admin, global manager, or project-level manager).
 */
function requireProjectManager() {
  return requireProjectRole('manager');
}

module.exports = {
  requireGlobalRole,
  requireProjectRole,
  requireProjectAccess,
  requireProjectManager,
  hasMinimumRole,
  ROLE_HIERARCHY,
};
