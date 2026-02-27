require('dotenv').config();
const fs = require('fs');
const path = require('path');
const pool = require('../config/database');

async function runMigrations() {
  const client = await pool.connect();
  try {
    const sqlPath = path.join(__dirname, '001_initial.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Running migrations for video editing platform...');
    await client.query(sql);
    console.log('Migrations completed successfully.');
    console.log('Tables created: users, clients, projects, project_members, delivery_jobs, tasks, approvals, comments, notifications, audit_log, refresh_tokens');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigrations();
