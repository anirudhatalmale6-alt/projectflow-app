require('dotenv').config();
const fs = require('fs');
const path = require('path');
const pool = require('../config/database');

function parseSqlStatements(sql) {
  // Remove single-line comments
  const lines = sql.split('\n');
  const cleaned = [];
  let inDelimiter = false;
  const triggers = [];
  let triggerLines = [];

  for (const line of lines) {
    const trimmed = line.trim();

    // Handle DELIMITER blocks for triggers
    if (trimmed === 'DELIMITER //') {
      inDelimiter = true;
      triggerLines = [];
      continue;
    }
    if (trimmed === 'DELIMITER ;') {
      inDelimiter = false;
      if (triggerLines.length > 0) {
        // Join trigger lines removing the trailing //
        let triggerSql = triggerLines.join('\n').replace(/\/\/\s*$/, '').trim();
        if (triggerSql) triggers.push(triggerSql);
      }
      continue;
    }

    if (inDelimiter) {
      triggerLines.push(line);
      continue;
    }

    // Skip pure comment lines
    if (trimmed.startsWith('--')) continue;
    // Skip empty lines
    if (trimmed === '') continue;

    cleaned.push(line);
  }

  // Now join and split on semicolons at end of statements
  const joined = cleaned.join('\n');
  const statements = joined.split(';')
    .map(s => s.trim())
    .filter(s => s.length > 0);

  return { statements, triggers };
}

async function runMigrations() {
  try {
    const sqlPath = path.join(__dirname, 'mysql_schema.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Running MySQL migrations for Duozz Flow...');

    const { statements, triggers } = parseSqlStatements(sql);
    console.log(`Found ${statements.length} statements, ${triggers.length} triggers`);

    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      try {
        await pool.query(stmt);
        // Show progress for CREATE TABLE
        const tableMatch = stmt.match(/CREATE TABLE IF NOT EXISTS (\w+)/i);
        if (tableMatch) {
          console.log(`  Created table: ${tableMatch[1]}`);
        }
      } catch (err) {
        if (err.code === 'ER_TABLE_EXISTS_ERROR' || err.errno === 1050) {
          console.log(`  Table already exists, skipping...`);
        } else if (err.code === 'ER_DUP_KEYNAME' || err.errno === 1061) {
          console.log(`  Index already exists, skipping...`);
        } else if (err.code === 'ER_FK_DUP_KEY' || err.errno === 1826) {
          console.log(`  Foreign key already exists, skipping...`);
        } else if (err.code === 'ER_DUP_FIELDNAME' || err.errno === 1060) {
          console.log(`  Column already exists, skipping...`);
        } else if (err.errno === 1022) {
          console.log(`  Duplicate key, skipping...`);
        } else {
          console.error(`  Error [${i}]: ${stmt.substring(0, 100)}...`);
          console.error(`    ${err.message}`);
        }
      }
    }

    // Run triggers
    for (const triggerSql of triggers) {
      try {
        await pool.query(triggerSql);
        const match = triggerSql.match(/CREATE TRIGGER (\w+)/i);
        console.log(`  Created trigger: ${match ? match[1] : 'unknown'}`);
      } catch (err) {
        if (err.errno === 1359) {
          console.log(`  Trigger already exists, skipping...`);
        } else {
          console.error(`  Trigger error: ${err.message}`);
        }
      }
    }

    console.log('\nMySQL migrations completed successfully.');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigrations();
