const pool = require('../config/database');

/**
 * Log an action to the audit_log table.
 *
 * @param {object} params
 * @param {string} params.userId    - UUID of the user performing the action
 * @param {string} params.action    - Action description (e.g. 'create', 'update', 'delete')
 * @param {string} params.entityType - Type of entity (e.g. 'project', 'task', 'delivery')
 * @param {string} params.entityId   - UUID of the entity
 * @param {object} params.details    - Additional details (stored as JSONB)
 * @param {string} params.ipAddress  - IP address of the request
 */
async function logAudit({ userId, action, entityType, entityId, details = {}, ipAddress = null }) {
  try {
    await pool.query(
      `INSERT INTO audit_log (user_id, action, entity_type, entity_id, details, ip_address)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [userId, action, entityType, entityId || null, JSON.stringify(details), ipAddress]
    );
  } catch (err) {
    // Audit logging should never crash the request
    console.error('Audit log error:', err.message);
  }
}

/**
 * Extract client IP address from an Express request.
 */
function getClientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0]?.trim()
    || req.socket?.remoteAddress
    || null;
}

module.exports = { logAudit, getClientIp };
