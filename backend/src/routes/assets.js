const express = require('express');
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { logAudit, getClientIp } = require('../utils/audit');
const { upload } = require('../middleware/upload');
const FileService = require('../services/fileService');

const router = express.Router();

// GET /api/v1/jobs/:jobId/assets - list assets for a job
router.get('/jobs/:jobId/assets', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT a.*, u.name as uploaded_by_name,
              (SELECT COUNT(*) FROM asset_versions av WHERE av.asset_id = a.id) as version_count
       FROM assets a
       LEFT JOIN users u ON a.uploaded_by = u.id
       WHERE a.job_id = $1
       ORDER BY a.created_at DESC`,
      [req.params.jobId]
    );
    res.json({ assets: rows });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/jobs/:jobId/assets - upload asset to a job
router.post('/jobs/:jobId/assets', auth, upload.single('file'), async (req, res, next) => {
  try {
    const { jobId } = req.params;
    const { name, type } = req.body;

    // Get job to find project_id
    const { rows: jobRows } = await pool.query('SELECT project_id FROM jobs WHERE id = $1', [jobId]);
    if (jobRows.length === 0) {
      return res.status(404).json({ error: 'Job not found.' });
    }
    const projectId = jobRows[0].project_id;

    let fileUrl = null;
    let fileSize = null;
    let mimeType = null;
    let assetName = name;

    if (req.file) {
      const result = await FileService.upload(req.file.buffer, req.file.originalname, req.file.mimetype, projectId);
      fileUrl = result.fileId;
      fileSize = result.size || req.file.size;
      mimeType = req.file.mimetype;
      if (!assetName) assetName = req.file.originalname;
    }

    if (!assetName) {
      return res.status(400).json({ error: 'Name or file is required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO assets (project_id, job_id, name, type, mime_type, file_url, file_size, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [projectId, jobId, assetName, type || 'raw', mimeType, fileUrl, fileSize, req.user.id]
    );

    await logAudit({
      userId: req.user.id, action: 'upload_asset', entityType: 'asset',
      entityId: rows[0].id, details: { name: assetName, type: type || 'raw', job_id: jobId }, ipAddress: getClientIp(req),
    });

    res.status(201).json({ message: 'Asset uploaded.', asset: rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/projects/:projectId/assets
router.get('/projects/:projectId/assets', auth, async (req, res, next) => {
  try {
    const { type } = req.query;
    let query = `
      SELECT a.*, u.name as uploaded_by_name,
             (SELECT COUNT(*) FROM asset_versions av WHERE av.asset_id = a.id) as version_count
      FROM assets a
      LEFT JOIN users u ON a.uploaded_by = u.id
      WHERE a.project_id = $1
    `;
    const params = [req.params.projectId];

    if (type) {
      params.push(type);
      query += ` AND a.type = $${params.length}`;
    }

    query += ' ORDER BY a.created_at DESC';
    const { rows } = await pool.query(query, params);
    res.json({ assets: rows });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/assets
router.post('/assets', auth, async (req, res, next) => {
  try {
    const { project_id, job_id, name, type, mime_type, file_url, file_size, drive_file_id } = req.body;

    if (!project_id || !name) {
      return res.status(400).json({ error: 'project_id and name are required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO assets (project_id, job_id, name, type, mime_type, file_url, file_size, drive_file_id, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [project_id, job_id || null, name, type || 'raw', mime_type || null, file_url || null, file_size || null, drive_file_id || null, req.user.id]
    );

    await logAudit({
      userId: req.user.id, action: 'upload_asset', entityType: 'asset',
      entityId: rows[0].id, details: { name, type, project_id }, ipAddress: getClientIp(req),
    });

    res.status(201).json({ message: 'Asset created.', asset: rows[0] });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/assets/:id/versions
router.post('/assets/:id/versions', auth, async (req, res, next) => {
  try {
    const { file_url, file_size, drive_file_id, notes } = req.body;

    if (!file_url) {
      return res.status(400).json({ error: 'file_url is required.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO asset_versions (asset_id, file_url, file_size, drive_file_id, notes, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.params.id, file_url, file_size || null, drive_file_id || null, notes || null, req.user.id]
    );

    res.status(201).json({ message: 'Version created.', version: rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /api/v1/assets/:id/versions
router.get('/assets/:id/versions', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT av.*, u.name as uploaded_by_name, a2.name as approved_by_name
       FROM asset_versions av
       LEFT JOIN users u ON av.uploaded_by = u.id
       LEFT JOIN users a2 ON av.approved_by = a2.id
       WHERE av.asset_id = $1
       ORDER BY av.version DESC`,
      [req.params.id]
    );
    res.json({ versions: rows });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/versions/:id/approve
router.post('/versions/:id/approve', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE asset_versions SET status = 'approved', approved_by = $1, approved_at = NOW()
       WHERE id = $2 RETURNING *`,
      [req.user.id, req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Version not found.' });
    }

    res.json({ message: 'Version approved.', version: rows[0] });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/versions/:id/reject
router.post('/versions/:id/reject', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE asset_versions SET status = 'rejected' WHERE id = $1 RETURNING *`,
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Version not found.' });
    }

    res.json({ message: 'Version rejected.', version: rows[0] });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
