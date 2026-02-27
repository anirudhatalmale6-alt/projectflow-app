// Deprecated: Use rbac.js middleware instead.
// This file is kept for backward compatibility only.
const { requireGlobalRole } = require('./rbac');
module.exports = requireGlobalRole('admin');
