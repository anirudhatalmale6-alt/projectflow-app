const fs = require('fs');
const sql = fs.readFileSync('src/migrations/mysql_schema.sql', 'utf8');
const statements = sql.split(/;\s*\n/).map(s => s.trim()).filter(s => s.length > 0 && !s.startsWith('--') && !s.startsWith('DELIMITER'));
console.log('Total statements:', statements.length);
statements.forEach((s, i) => {
  console.log(`--- Statement ${i} (${s.length} chars) ---`);
  console.log(s.substring(0, 120));
  if (s.length > 120) console.log('...');
});
