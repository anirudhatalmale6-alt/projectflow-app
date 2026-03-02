const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || '/tmp',
  port: parseInt(process.env.DB_PORT, 10) || 5433,
  database: process.env.DB_NAME || 'videoflow',
  user: process.env.DB_USER || 'freelancer3',
  password: process.env.DB_PASSWORD || undefined,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle database client', err);
  process.exit(-1);
});

module.exports = pool;
