const express = require('express');
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { logAudit, getClientIp } = require('../utils/audit');

const router = express.Router();

// POST /api/v1/jobs/:jobId/reviews
router.post('/jobs/:jobId/reviews', auth, async (req, res, next) => {
  try {
    const { asset_version_id, summary } = req.body;

    const { rows } = await pool.query(
      `INSERT INTO reviews (job_id, asset_version_id, reviewer_id, summary)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.params.jobId, asset_version_id || null, req.user.id, summary || null]
    );

    await logAudit({
      userId: req.user.id, action: 'create_review', entityType: 'review',
      entityId: rows[0].id, details: { job_id: req.params.jobId }, ipAddress: getClientIp(req),
    });

    res.status(201).json({ message: 'Review created.', review: rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/jobs/:jobId/reviews
router.get('/jobs/:jobId/reviews', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT r.*, u.name as reviewer_name, u.avatar_url as reviewer_avatar,
              (SELECT COUNT(*) FROM review_comments rc WHERE rc.review_id = r.id) as comment_count
       FROM reviews r
       LEFT JOIN users u ON r.reviewer_id = u.id
       WHERE r.job_id = $1
       ORDER BY r.created_at DESC`,
      [req.params.jobId]
    );
    res.json({ reviews: rows });
  } catch (err) {
    next(err);
  }
});

// PUT /api/v1/reviews/:id
router.put('/reviews/:id', auth, async (req, res, next) => {
  try {
    const { status, summary } = req.body;
    const fields = [];
    const values = [];
    let idx = 1;

    if (status !== undefined) { fields.push(`status = $${idx++}`); values.push(status); }
    if (summary !== undefined) { fields.push(`summary = $${idx++}`); values.push(summary); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update.' });
    }

    values.push(req.params.id);
    const { rows } = await pool.query(
      `UPDATE reviews SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Review not found.' });
    }

    res.json({ message: 'Review updated.', review: rows[0] });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/reviews/:id/comments
router.post('/reviews/:id/comments', auth, async (req, res, next) => {
  try {
    const { content, timecode, frame_url } = req.body;

    if (!content) {
      return res.status(400).json({ error: 'Content is required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO review_comments (review_id, user_id, content, timecode, frame_url)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.params.id, req.user.id, content, timecode || null, frame_url || null]
    );

    res.status(201).json({ message: 'Comment added.', comment: rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/reviews/:id/comments
router.get('/reviews/:id/comments', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT rc.*, u.name as user_name, u.avatar_url as user_avatar
       FROM review_comments rc
       LEFT JOIN users u ON rc.user_id = u.id
       WHERE rc.review_id = $1
       ORDER BY rc.created_at ASC`,
      [req.params.id]
    );
    res.json({ comments: rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
