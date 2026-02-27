const pool = require('../config/database');

/**
 * Parse @mentions from text content.
 * Supports formats:
 *   @username       (matches against user name, case-insensitive)
 *   @user.name      (names with dots)
 *   @"Full Name"    (quoted full names with spaces)
 *
 * Returns an array of user objects { id, name, email } for matched users.
 */
async function parseMentions(content) {
  if (!content) return [];

  // Match @"Full Name" or @word.word or @word
  const mentionPattern = /@"([^"]+)"|@([\w.]+)/g;
  const mentionNames = [];
  let match;

  while ((match = mentionPattern.exec(content)) !== null) {
    const name = match[1] || match[2]; // quoted name or simple name
    if (name) {
      mentionNames.push(name);
    }
  }

  if (mentionNames.length === 0) return [];

  // Look up each mention in the database
  const uniqueNames = [...new Set(mentionNames)];
  const placeholders = uniqueNames.map((_, i) => `$${i + 1}`).join(', ');

  // Match against name or email prefix (before @)
  const conditions = uniqueNames
    .map((_, i) => `LOWER(u.name) = LOWER($${i + 1}) OR LOWER(SPLIT_PART(u.email, '@', 1)) = LOWER($${i + 1})`)
    .join(' OR ');

  const { rows } = await pool.query(
    `SELECT DISTINCT u.id, u.name, u.email
     FROM users u
     WHERE ${conditions}`,
    uniqueNames
  );

  return rows;
}

/**
 * Extract raw mention strings from content (without DB lookup).
 * Useful for quick extraction.
 */
function extractMentionStrings(content) {
  if (!content) return [];

  const mentionPattern = /@"([^"]+)"|@([\w.]+)/g;
  const mentions = [];
  let match;

  while ((match = mentionPattern.exec(content)) !== null) {
    const name = match[1] || match[2];
    if (name) {
      mentions.push(name);
    }
  }

  return [...new Set(mentions)];
}

module.exports = { parseMentions, extractMentionStrings };
