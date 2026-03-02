const express = require('express');
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { upload } = require('../middleware/upload');
const DriveService = require('../services/driveService');
const { logAudit, getClientIp } = require('../utils/audit');

const router = express.Router();

// All routes require auth
router.use(auth);

// GET /api/v1/projects/:id/drive/status
// Check if Google Drive is set up for this project
router.get('/projects/:id/drive/status', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT drive_folder_id, drive_folder_url, drive_folders FROM projects WHERE id = $1',
      [req.params.id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    const hasGoogleDrive = await DriveService.hasGoogleDrive(req.user.id);

    res.json({
      connected: !!rows[0].drive_folder_id,
      user_has_google: hasGoogleDrive,
      drive_folder_id: rows[0].drive_folder_id || null,
      drive_folder_url: rows[0].drive_folder_url || null,
      drive_folders: rows[0].drive_folders || null,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/v1/projects/:id/drive/setup
// Create Google Drive folder structure for a project
router.post('/projects/:id/drive/setup', async (req, res, next) => {
  try {
    // Check if user has Google Drive
    const hasGD = await DriveService.hasGoogleDrive(req.user.id);
    if (!hasGD) {
      return res.status(400).json({
        error: 'Faça login com Google para conectar o Google Drive.',
        code: 'NO_GOOGLE_AUTH',
      });
    }

    // Get project name
    const { rows: projRows } = await pool.query(
      'SELECT name, drive_folder_id FROM projects WHERE id = $1',
      [req.params.id]
    );
    if (!projRows.length) {
      return res.status(404).json({ error: 'Project not found.' });
    }

    // Skip if already set up
    if (projRows[0].drive_folder_id) {
      return res.json({
        message: 'Google Drive already connected.',
        drive_folder_id: projRows[0].drive_folder_id,
      });
    }

    // Create folder structure
    const result = await DriveService.createProjectFolders(req.user.id, projRows[0].name);

    // Store in database
    await pool.query(
      `UPDATE projects SET drive_folder_id = $1, drive_folder_url = $2, drive_folders = $3 WHERE id = $4`,
      [result.drive_folder_id, result.drive_folder_url, JSON.stringify(result.drive_folders), req.params.id]
    );

    await logAudit({
      userId: req.user.id, action: 'setup_drive', entityType: 'project',
      entityId: req.params.id, details: { drive_folder_id: result.drive_folder_id },
      ipAddress: getClientIp(req),
    });

    res.json({
      message: 'Google Drive connected successfully.',
      ...result,
    });
  } catch (err) {
    if (err.message === 'USER_NOT_GOOGLE_LINKED') {
      return res.status(400).json({
        error: 'Faça login com Google para conectar o Google Drive.',
        code: 'NO_GOOGLE_AUTH',
      });
    }
    next(err);
  }
});

// GET /api/v1/projects/:id/drive/files
// List files from a specific subfolder
router.get('/projects/:id/drive/files', async (req, res, next) => {
  try {
    const { folder, query, pageToken, pageSize } = req.query;

    const { rows } = await pool.query(
      'SELECT drive_folders FROM projects WHERE id = $1',
      [req.params.id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Project not found.' });
    }
    if (!rows[0].drive_folders) {
      return res.status(400).json({ error: 'Google Drive not connected for this project.' });
    }

    const folders = typeof rows[0].drive_folders === 'string'
      ? JSON.parse(rows[0].drive_folders)
      : rows[0].drive_folders;

    // Determine which folder to list
    const folderMap = {
      brutos: folders.brutos,
      edicoes: folders.edicoes,
      exports: folders.exports,
      revisoes: folders.revisoes,
      documentos: folders.documentos,
      root: folders.root,
    };

    const folderId = folderMap[folder] || folders.root;
    if (!folderId) {
      return res.status(400).json({ error: 'Folder not found.' });
    }

    const result = await DriveService.listFiles(req.user.id, folderId, {
      pageSize: parseInt(pageSize) || 50,
      pageToken,
      query,
    });

    res.json({
      folder: folder || 'root',
      ...result,
    });
  } catch (err) {
    if (err.message === 'USER_NOT_GOOGLE_LINKED') {
      return res.status(400).json({ error: 'Login com Google necessário.', code: 'NO_GOOGLE_AUTH' });
    }
    next(err);
  }
});

// POST /api/v1/projects/:id/drive/upload
// Upload a file to a project's Drive folder
router.post('/projects/:id/drive/upload', upload.single('file'), async (req, res, next) => {
  try {
    const { folder } = req.body;
    if (!req.file) {
      return res.status(400).json({ error: 'File is required.' });
    }

    const { rows } = await pool.query(
      'SELECT drive_folders FROM projects WHERE id = $1',
      [req.params.id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Project not found.' });
    }
    if (!rows[0].drive_folders) {
      return res.status(400).json({ error: 'Google Drive not connected.' });
    }

    const folders = typeof rows[0].drive_folders === 'string'
      ? JSON.parse(rows[0].drive_folders)
      : rows[0].drive_folders;

    const folderMap = {
      brutos: folders.brutos,
      edicoes: folders.edicoes,
      exports: folders.exports,
      revisoes: folders.revisoes,
      documentos: folders.documentos,
    };
    const folderId = folderMap[folder] || folders.root;

    const result = await DriveService.uploadFile(
      req.user.id,
      folderId,
      req.file.buffer,
      req.file.originalname,
      req.file.mimetype
    );

    await logAudit({
      userId: req.user.id, action: 'drive_upload', entityType: 'project',
      entityId: req.params.id, details: { fileName: result.name, folder },
      ipAddress: getClientIp(req),
    });

    res.json({ message: 'File uploaded to Google Drive.', file: result });
  } catch (err) {
    if (err.message === 'USER_NOT_GOOGLE_LINKED') {
      return res.status(400).json({ error: 'Login com Google necessário.', code: 'NO_GOOGLE_AUTH' });
    }
    next(err);
  }
});

// GET /api/v1/drive/files/:fileId/link
// Get a shareable link for a Drive file
router.get('/drive/files/:fileId/link', async (req, res, next) => {
  try {
    const data = await DriveService.getFileLink(req.user.id, req.params.fileId);
    res.json({ file: data });
  } catch (err) {
    if (err.message === 'USER_NOT_GOOGLE_LINKED') {
      return res.status(400).json({ error: 'Login com Google necessário.', code: 'NO_GOOGLE_AUTH' });
    }
    next(err);
  }
});

// DELETE /api/v1/drive/files/:fileId
// Delete a file from Google Drive
router.delete('/drive/files/:fileId', async (req, res, next) => {
  try {
    await DriveService.deleteFile(req.user.id, req.params.fileId);

    await logAudit({
      userId: req.user.id, action: 'drive_delete', entityType: 'file',
      entityId: req.params.fileId, details: {}, ipAddress: getClientIp(req),
    });

    res.json({ message: 'File deleted from Google Drive.' });
  } catch (err) {
    if (err.message === 'USER_NOT_GOOGLE_LINKED') {
      return res.status(400).json({ error: 'Login com Google necessário.', code: 'NO_GOOGLE_AUTH' });
    }
    next(err);
  }
});

module.exports = router;
