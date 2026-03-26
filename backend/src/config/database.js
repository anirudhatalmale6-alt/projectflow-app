const mysql = require('mysql2/promise');
const { v4: uuidv4 } = require('uuid');

// Tables that use INT AUTO_INCREMENT for id (skip UUID injection)
const AUTO_INCREMENT_TABLES = ['project_members', 'push_subscriptions', 'refresh_tokens', 'role_permissions', 'audit_log', 'task_assignees'];

// Create MySQL pool
const poolConfig = {
  database: process.env.DB_NAME || 'duozzflow',
  user: process.env.DB_USER || 'duozzflow_user',
  password: process.env.DB_PASSWORD || '',
  waitForConnections: true,
  connectionLimit: 20,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  // Return dates as strings to match pg behavior
  dateStrings: true,
  // Handle timezone
  timezone: '+00:00',
};

// Support socket path or TCP host
if (process.env.DB_SOCKET) {
  poolConfig.socketPath = process.env.DB_SOCKET;
} else {
  poolConfig.host = process.env.DB_HOST || 'localhost';
  poolConfig.port = parseInt(process.env.DB_PORT, 10) || 3306;
}

const pool = mysql.createPool(poolConfig);

/**
 * PostgreSQL → MySQL compatibility wrapper.
 * - Converts $1, $2 placeholders to ?
 * - Handles RETURNING clause by doing INSERT/UPDATE + SELECT
 * - Returns { rows: [...], rowCount: N } like pg
 * - Handles ::int, ::text type casts
 * - Converts ILIKE to LIKE
 * - Converts ANY($N) to IN (?)
 * - Converts INTERVAL syntax
 * - Converts COUNT(*) FILTER (WHERE ...)
 */
function convertQuery(text, params) {
  let sql = text;
  let newParams = params ? [...params] : [];

  // Remove type casts: ::int, ::text, ::numeric, ::uuid, ::int[], ::timestamp
  sql = sql.replace(/::(?:int|integer|bigint|text|numeric|uuid|boolean|timestamp|date|jsonb|json|varchar)(?:\[\])?/gi, '');

  // Convert ILIKE to LIKE (MariaDB default collation is case-insensitive)
  sql = sql.replace(/\bILIKE\b/gi, 'LIKE');

  // Convert INTERVAL syntax: INTERVAL '24 hours' → INTERVAL 24 HOUR
  sql = sql.replace(/INTERVAL\s+'(\d+)\s+(hours?|days?|minutes?|seconds?|weeks?|months?|years?)'/gi, (match, num, unit) => {
    const u = unit.toUpperCase().replace(/S$/, '');
    return `INTERVAL ${num} ${u}`;
  });

  // Convert COUNT(*) FILTER (WHERE condition) → SUM(CASE WHEN condition THEN 1 ELSE 0 END)
  // Use greedy match up to the last closing paren of FILTER(...)
  sql = sql.replace(/COUNT\s*\(\s*\*\s*\)\s*FILTER\s*\(\s*WHERE\s+([\s\S]*?)\)(?=\s*(?:AS\b|,|\s*$|\n|::))/gi, (match, cond) => {
    return `SUM(CASE WHEN ${cond.trim()} THEN 1 ELSE 0 END)`;
  });

  // Convert NULLS LAST/FIRST - MySQL sorts NULLs differently than PostgreSQL
  // ASC NULLS LAST needs explicit handling (MySQL default: NULLS FIRST for ASC)
  sql = sql.replace(/(\w+(?:\.\w+)?)\s+ASC\s+NULLS\s+LAST/gi,
    'CASE WHEN $1 IS NULL THEN 1 ELSE 0 END, $1 ASC');
  // DESC NULLS FIRST needs explicit handling (MySQL default: NULLS LAST for DESC)
  sql = sql.replace(/(\w+(?:\.\w+)?)\s+DESC\s+NULLS\s+FIRST/gi,
    'CASE WHEN $1 IS NULL THEN 0 ELSE 1 END, $1 DESC');
  // ASC NULLS FIRST and DESC NULLS LAST match MySQL defaults, just remove
  sql = sql.replace(/\bNULLS\s+LAST\b/gi, '');
  sql = sql.replace(/\bNULLS\s+FIRST\b/gi, '');

  // Convert ANY($N) array operations → IN (?)
  // ANY($1) where param is an array → replace with IN (?, ?, ...)
  sql = sql.replace(/=\s*ANY\s*\(\s*\$(\d+)\s*\)/gi, (match, paramNum) => {
    const idx = parseInt(paramNum) - 1;
    if (Array.isArray(newParams[idx])) {
      const arr = newParams[idx];
      if (arr.length === 0) return '= NULL'; // no match
      const placeholders = arr.map(() => '?').join(', ');
      // Replace the single array param with spread values
      newParams.splice(idx, 1, ...arr);
      return `IN (${placeholders})`;
    }
    return match;
  });

  // Convert ARRAY_AGG(...) → GROUP_CONCAT(...)
  sql = sql.replace(/ARRAY_AGG\s*\(([^)]+)\)/gi, 'GROUP_CONCAT($1)');

  // Convert JSONB to JSON
  sql = sql.replace(/\bJSONB\b/gi, 'JSON');

  // Convert ON CONFLICT (cols) DO NOTHING → INSERT IGNORE (handled at query level)
  // Convert ON CONFLICT (cols) DO UPDATE → ON DUPLICATE KEY UPDATE (handled at query level)

  // Convert $1, $2, etc. to ? but maintain parameter order
  // First, collect all $N references and their order
  const paramRefs = [];
  sql = sql.replace(/\$(\d+)/g, (match, num) => {
    paramRefs.push(parseInt(num) - 1); // 0-based index
    return '?';
  });

  // Reorder params based on $N references
  if (paramRefs.length > 0 && newParams.length > 0) {
    const reordered = paramRefs.map(idx => newParams[idx]);
    newParams = reordered;
  }

  return { sql, params: newParams };
}

/**
 * Handle RETURNING clause for INSERT/UPDATE/DELETE
 * Returns the columns that would have been returned by RETURNING
 */
function extractReturning(sql) {
  const match = sql.match(/\bRETURNING\s+(.+?)$/i);
  if (!match) return { cleanSql: sql, returningCols: null };

  const returningCols = match[1].trim();
  const cleanSql = sql.substring(0, match.index).trim();
  return { cleanSql, returningCols };
}

/**
 * Determine the table name from an INSERT/UPDATE/DELETE query
 */
function extractTable(sql) {
  let match = sql.match(/INSERT\s+INTO\s+(\w+)/i);
  if (match) return match[1];
  match = sql.match(/UPDATE\s+(\w+)/i);
  if (match) return match[1];
  match = sql.match(/DELETE\s+FROM\s+(\w+)/i);
  if (match) return match[1];
  return null;
}

/**
 * Extract WHERE clause from UPDATE/DELETE for re-selecting
 */
function extractWhere(sql) {
  const match = sql.match(/\bWHERE\s+(.+?)(?:\s+RETURNING|\s*$)/i);
  return match ? match[1].trim() : null;
}

/**
 * Compatibility query function that mimics pg's pool.query interface
 */
async function query(text, params) {
  let { sql, params: convertedParams } = convertQuery(text, params);

  // Handle RETURNING clause
  const { cleanSql, returningCols } = extractReturning(sql);

  if (returningCols) {
    const table = extractTable(cleanSql);
    const isInsert = /^\s*INSERT/i.test(cleanSql);
    const isUpdate = /^\s*UPDATE/i.test(cleanSql);
    const isDelete = /^\s*DELETE/i.test(cleanSql);

    // Handle ON CONFLICT DO NOTHING for INSERT
    let finalSql = cleanSql;
    const onConflictNothing = finalSql.match(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i);
    if (onConflictNothing) {
      finalSql = finalSql.replace(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i, '');
      finalSql = finalSql.replace(/^INSERT\s+INTO/i, 'INSERT IGNORE INTO');
    }

    // Handle ON CONFLICT DO UPDATE
    const onConflictUpdate = finalSql.match(/ON\s+CONFLICT\s*\([^)]*\)\s*DO\s+UPDATE\s+SET\s+(.+)/i);
    if (onConflictUpdate) {
      const setClauses = onConflictUpdate[1];
      finalSql = finalSql.replace(/ON\s+CONFLICT\s*\([^)]*\)\s*DO\s+UPDATE\s+SET\s+.+/i, '');
      // Convert excluded.col to VALUES(col)
      let mysqlSet = setClauses.replace(/excluded\.(\w+)/g, 'VALUES($1)');
      finalSql = finalSql.trimEnd() + ` ON DUPLICATE KEY UPDATE ${mysqlSet}`;
    }

    // For INSERT without explicit 'id', inject a UUID (skip auto-increment tables)
    const isInsertFinal = /^\s*INSERT/i.test(finalSql);
    let generatedId = null;
    if (isInsertFinal) {
      const colsMatch = finalSql.match(/INSERT\s+(?:IGNORE\s+)?INTO\s+\w+\s*\(([^)]+)\)/i);
      if (colsMatch) {
        const cols = colsMatch[1].split(',').map(c => c.trim());
        if (!cols.includes('id') && !AUTO_INCREMENT_TABLES.includes(table)) {
          // Auto-inject id column and UUID value
          generatedId = uuidv4();
          const newCols = ['id', ...cols].join(', ');
          finalSql = finalSql.replace(
            /INSERT\s+(IGNORE\s+)?INTO\s+(\w+)\s*\([^)]+\)/i,
            `INSERT $1INTO $2 (${newCols})`
          );
          convertedParams = [generatedId, ...convertedParams];
          // Add an extra ? for the id value
          finalSql = finalSql.replace(/VALUES\s*\(/, 'VALUES (?, ');
        }
      }
    }

    // Execute the main query
    const [result] = await pool.query(finalSql, convertedParams);

    if (isInsert && table) {
      const selectCols = returningCols === '*' ? '*' : returningCols;

      // Use generated UUID or find the id from params
      let idValue = generatedId;
      if (!idValue) {
        const colsMatch2 = cleanSql.match(/INSERT\s+(?:IGNORE\s+)?INTO\s+\w+\s*\(([^)]+)\)/i);
        if (colsMatch2) {
          const cols = colsMatch2[1].split(',').map(c => c.trim());
          const idIdx = cols.indexOf('id');
          if (idIdx >= 0 && convertedParams[idIdx]) {
            idValue = convertedParams[idIdx];
          }
        }
      }

      if (idValue) {
        const [rows] = await pool.query(
          `SELECT ${selectCols} FROM ${table} WHERE id = ?`,
          [idValue]
        );
        return { rows, rowCount: result.affectedRows };
      }

      // Fallback: use LAST_INSERT_ID for auto-increment tables
      if (result.insertId) {
        const [rows] = await pool.query(
          `SELECT ${selectCols} FROM ${table} WHERE id = ?`,
          [result.insertId]
        );
        return { rows, rowCount: result.affectedRows };
      }

      return { rows: [], rowCount: result.affectedRows };

    } else if ((isUpdate || isDelete) && table) {
      // For UPDATE/DELETE, re-select using the WHERE clause
      const whereParts = extractWhere(cleanSql);
      if (whereParts) {
        // Get WHERE params (params used in the WHERE clause)
        const selectCols = returningCols === '*' ? '*' : returningCols;
        // Re-extract WHERE params from the original converted params
        const whereParamCount = (whereParts.match(/\?/g) || []).length;
        const updateParamCount = convertedParams.length - whereParamCount;
        const whereParams = convertedParams.slice(updateParamCount);

        const [rows] = await pool.query(
          `SELECT ${selectCols} FROM ${table} WHERE ${whereParts}`,
          whereParams
        );
        return { rows, rowCount: result.affectedRows };
      }
      return { rows: [], rowCount: result.affectedRows };
    }

    return { rows: [], rowCount: result.affectedRows };
  }

  // Handle ON CONFLICT without RETURNING
  const onConflictNothing = sql.match(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i);
  if (onConflictNothing) {
    sql = sql.replace(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i, '');
    sql = sql.replace(/^INSERT\s+INTO/i, 'INSERT IGNORE INTO');
  }

  const onConflictUpdate = sql.match(/ON\s+CONFLICT\s*\([^)]*\)\s*DO\s+UPDATE\s+SET\s+(.+)/i);
  if (onConflictUpdate) {
    const setClauses = onConflictUpdate[1];
    sql = sql.replace(/ON\s+CONFLICT\s*\([^)]*\)\s*DO\s+UPDATE\s+SET\s+.+/i, '');
    let mysqlSet = setClauses.replace(/excluded\.(\w+)/g, 'VALUES($1)');
    sql = sql.trimEnd() + ` ON DUPLICATE KEY UPDATE ${mysqlSet}`;
  }

  // Regular query (SELECT, INSERT without RETURNING, etc.)
  const [result] = await pool.query(sql, convertedParams);

  // For SELECT queries, result is an array of rows
  if (Array.isArray(result)) {
    return { rows: result, rowCount: result.length };
  }

  // For INSERT/UPDATE/DELETE, result is a ResultSetHeader
  return { rows: [], rowCount: result.affectedRows || 0, insertId: result.insertId };
}

/**
 * Get a connection from the pool (mimics pg's pool.connect())
 */
async function connect() {
  const conn = await pool.getConnection();

  return {
    query: async (text, params) => {
      let { sql, params: convertedParams } = convertQuery(text, params);

      // Handle RETURNING for connection queries too
      const { cleanSql, returningCols } = extractReturning(sql);
      if (returningCols) {
        // Same logic as pool.query RETURNING handler but using conn
        let finalSql = cleanSql;
        const onConflictNothing = finalSql.match(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i);
        if (onConflictNothing) {
          finalSql = finalSql.replace(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i, '');
          finalSql = finalSql.replace(/^INSERT\s+INTO/i, 'INSERT IGNORE INTO');
        }

        const onConflictUpdate = finalSql.match(/ON\s+CONFLICT\s*\([^)]*\)\s*DO\s+UPDATE\s+SET\s+(.+)/i);
        if (onConflictUpdate) {
          const setClauses = onConflictUpdate[1];
          finalSql = finalSql.replace(/ON\s+CONFLICT\s*\([^)]*\)\s*DO\s+UPDATE\s+SET\s+.+/i, '');
          let mysqlSet = setClauses.replace(/excluded\.(\w+)/g, 'VALUES($1)');
          finalSql = finalSql.trimEnd() + ` ON DUPLICATE KEY UPDATE ${mysqlSet}`;
        }

        // For INSERT without explicit 'id', inject a UUID (skip auto-increment tables)
        const isInsertFinal = /^\s*INSERT/i.test(finalSql);
        const connTable = extractTable(finalSql);
        let generatedId = null;
        if (isInsertFinal) {
          const colsMatch = finalSql.match(/INSERT\s+(?:IGNORE\s+)?INTO\s+\w+\s*\(([^)]+)\)/i);
          if (colsMatch) {
            const cols = colsMatch[1].split(',').map(c => c.trim());
            if (!cols.includes('id') && !AUTO_INCREMENT_TABLES.includes(connTable)) {
              generatedId = uuidv4();
              const newCols = ['id', ...cols].join(', ');
              finalSql = finalSql.replace(
                /INSERT\s+(IGNORE\s+)?INTO\s+(\w+)\s*\([^)]+\)/i,
                `INSERT $1INTO $2 (${newCols})`
              );
              convertedParams = [generatedId, ...convertedParams];
              finalSql = finalSql.replace(/VALUES\s*\(/, 'VALUES (?, ');
            }
          }
        }

        const [result] = await conn.query(finalSql, convertedParams);
        const table = connTable;
        if (table) {
          const selectCols = returningCols === '*' ? '*' : returningCols;

          // Use generated UUID
          let idValue = generatedId;
          if (!idValue) {
            const colsMatch2 = finalSql.match(/INSERT\s+(?:IGNORE\s+)?INTO\s+\w+\s*\(([^)]+)\)/i);
            if (colsMatch2) {
              const cols = colsMatch2[1].split(',').map(c => c.trim());
              const idIdx = cols.indexOf('id');
              if (idIdx >= 0 && convertedParams[idIdx]) {
                idValue = convertedParams[idIdx];
              }
            }
          }

          if (idValue) {
            const [rows] = await conn.query(`SELECT ${selectCols} FROM ${table} WHERE id = ?`, [idValue]);
            return { rows, rowCount: result.affectedRows };
          }

          if (result.insertId) {
            const [rows] = await conn.query(`SELECT ${selectCols} FROM ${table} WHERE id = ?`, [result.insertId]);
            return { rows, rowCount: result.affectedRows };
          }
          // For UPDATE/DELETE with RETURNING
          const whereParts = extractWhere(cleanSql);
          if (whereParts) {
            const selectCols2 = returningCols === '*' ? '*' : returningCols;
            const whereParamCount = (whereParts.match(/\?/g) || []).length;
            const updateParamCount = convertedParams.length - whereParamCount;
            const whereParams = convertedParams.slice(updateParamCount);
            const [rows] = await conn.query(`SELECT ${selectCols2} FROM ${table} WHERE ${whereParts}`, whereParams);
            return { rows, rowCount: result.affectedRows };
          }
        }
        return { rows: [], rowCount: result.affectedRows };
      }

      // Handle ON CONFLICT without RETURNING
      const onConflictNothing2 = sql.match(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i);
      if (onConflictNothing2) {
        sql = sql.replace(/ON\s+CONFLICT\s*(?:\([^)]*\))?\s*DO\s+NOTHING/i, '');
        sql = sql.replace(/^INSERT\s+INTO/i, 'INSERT IGNORE INTO');
      }

      const [result] = await conn.query(sql, convertedParams);
      if (Array.isArray(result)) {
        return { rows: result, rowCount: result.length };
      }
      return { rows: [], rowCount: result.affectedRows || 0 };
    },
    release: () => conn.release(),
  };
}

// Export a pg-compatible interface
const wrapper = {
  query,
  connect,
  // Expose raw pool for direct access if needed
  _pool: pool,
  // UUID generator helper
  uuid: uuidv4,
  end: () => pool.end(),
};

wrapper.on = (event, handler) => {
  // Compatibility with pg pool.on('error', ...)
  if (event === 'error') {
    pool.on('error', handler);
  }
};

module.exports = wrapper;
