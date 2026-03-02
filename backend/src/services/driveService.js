const { google } = require('googleapis');
const pool = require('../config/database');

const SUBFOLDER_NAMES = ['Brutos', 'Edições', 'Exports', 'Revisões', 'Documentos'];

class DriveService {
  /**
   * Create an OAuth2 client authenticated with a user's stored Google tokens.
   */
  static _getOAuth2Client(accessToken, refreshToken) {
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET
    );
    oauth2Client.setCredentials({
      access_token: accessToken,
      refresh_token: refreshToken,
    });
    return oauth2Client;
  }

  /**
   * Get an authenticated Drive client for a given user ID.
   */
  static async _getDriveForUser(userId) {
    const { rows } = await pool.query(
      'SELECT google_access_token, google_refresh_token FROM users WHERE id = $1',
      [userId]
    );
    if (!rows.length || !rows[0].google_refresh_token) {
      throw new Error('USER_NOT_GOOGLE_LINKED');
    }
    const auth = DriveService._getOAuth2Client(
      rows[0].google_access_token,
      rows[0].google_refresh_token
    );

    // Listen for token refresh events to update stored tokens
    auth.on('tokens', async (tokens) => {
      if (tokens.access_token) {
        await pool.query(
          'UPDATE users SET google_access_token = $1 WHERE id = $2',
          [tokens.access_token, userId]
        );
      }
    });

    return google.drive({ version: 'v3', auth });
  }

  /**
   * Create a folder in Google Drive.
   */
  static async _createFolder(drive, name, parentId) {
    const res = await drive.files.create({
      requestBody: {
        name,
        mimeType: 'application/vnd.google-apps.folder',
        ...(parentId ? { parents: [parentId] } : {}),
      },
      fields: 'id, name, webViewLink',
    });
    return res.data;
  }

  /**
   * Find an existing folder by name inside a parent.
   */
  static async _findFolder(drive, name, parentId) {
    const q = parentId
      ? `name='${name}' and '${parentId}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false`
      : `name='${name}' and mimeType='application/vnd.google-apps.folder' and trashed=false`;
    const res = await drive.files.list({
      q,
      fields: 'files(id, name, webViewLink)',
      pageSize: 1,
    });
    return res.data.files.length > 0 ? res.data.files[0] : null;
  }

  /**
   * Create the full project folder structure on Google Drive:
   * ProjectName/
   *   Brutos/
   *   Edições/
   *   Exports/
   *   Revisões/
   *   Documentos/
   */
  static async createProjectFolders(userId, projectName) {
    const drive = await DriveService._getDriveForUser(userId);

    // Create or find root "Duozz Flow" folder
    let rootFolder = await DriveService._findFolder(drive, 'Duozz Flow', null);
    if (!rootFolder) {
      rootFolder = await DriveService._createFolder(drive, 'Duozz Flow', null);
    }

    // Create project folder
    let projectFolder = await DriveService._findFolder(drive, projectName, rootFolder.id);
    if (!projectFolder) {
      projectFolder = await DriveService._createFolder(drive, projectName, rootFolder.id);
    }

    // Create subfolders
    const subfolders = {};
    for (const name of SUBFOLDER_NAMES) {
      let sub = await DriveService._findFolder(drive, name, projectFolder.id);
      if (!sub) {
        sub = await DriveService._createFolder(drive, name, projectFolder.id);
      }
      subfolders[name] = sub.id;
    }

    return {
      drive_folder_id: projectFolder.id,
      drive_folder_url: projectFolder.webViewLink,
      drive_folders: {
        root: projectFolder.id,
        brutos: subfolders['Brutos'],
        edicoes: subfolders['Edições'],
        exports: subfolders['Exports'],
        revisoes: subfolders['Revisões'],
        documentos: subfolders['Documentos'],
      },
    };
  }

  /**
   * List files in a specific Drive folder.
   */
  static async listFiles(userId, folderId, { pageSize = 50, pageToken, query } = {}) {
    const drive = await DriveService._getDriveForUser(userId);

    let q = `'${folderId}' in parents and trashed=false`;
    if (query) {
      q += ` and name contains '${query.replace(/'/g, "\\'")}'`;
    }

    const res = await drive.files.list({
      q,
      fields: 'nextPageToken, files(id, name, mimeType, size, modifiedTime, webViewLink, webContentLink, thumbnailLink, iconLink)',
      pageSize,
      pageToken: pageToken || undefined,
      orderBy: 'modifiedTime desc',
    });

    return {
      files: res.data.files || [],
      nextPageToken: res.data.nextPageToken || null,
    };
  }

  /**
   * Upload a file to a specific Drive folder.
   */
  static async uploadFile(userId, folderId, fileBuffer, fileName, mimeType) {
    const drive = await DriveService._getDriveForUser(userId);
    const { Readable } = require('stream');

    const stream = new Readable();
    stream.push(fileBuffer);
    stream.push(null);

    const res = await drive.files.create({
      requestBody: {
        name: fileName,
        parents: [folderId],
      },
      media: {
        mimeType,
        body: stream,
      },
      fields: 'id, name, webViewLink, webContentLink, size, mimeType',
    });

    return res.data;
  }

  /**
   * Get a shareable download/view link for a file.
   */
  static async getFileLink(userId, fileId) {
    const drive = await DriveService._getDriveForUser(userId);

    // Make file viewable by anyone with link
    try {
      await drive.permissions.create({
        fileId,
        requestBody: { role: 'reader', type: 'anyone' },
      });
    } catch (e) {
      // Permission might already exist
    }

    const res = await drive.files.get({
      fileId,
      fields: 'id, name, webViewLink, webContentLink, mimeType, size',
    });

    return res.data;
  }

  /**
   * Delete a file from Drive.
   */
  static async deleteFile(userId, fileId) {
    const drive = await DriveService._getDriveForUser(userId);
    await drive.files.delete({ fileId });
  }

  /**
   * Check if user has valid Google Drive tokens.
   */
  static async hasGoogleDrive(userId) {
    const { rows } = await pool.query(
      'SELECT google_refresh_token FROM users WHERE id = $1',
      [userId]
    );
    return rows.length > 0 && !!rows[0].google_refresh_token;
  }
}

module.exports = DriveService;
