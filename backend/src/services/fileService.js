const { getGoogleDriveClient, FOLDER_ID } = require('../config/googleDrive');
const { Readable } = require('stream');
const fs = require('fs');
const path = require('path');

class FileService {
  // Upload file to Google Drive
  static async uploadToGoogleDrive(fileBuffer, fileName, mimeType, projectId) {
    const drive = getGoogleDriveClient();

    // Create project subfolder if needed
    let folderId = FOLDER_ID;
    if (projectId) {
      folderId = await FileService._getOrCreateFolder(drive, projectId, FOLDER_ID);
    }

    const stream = new Readable();
    stream.push(fileBuffer);
    stream.push(null);

    const response = await drive.files.create({
      requestBody: {
        name: fileName,
        parents: [folderId],
      },
      media: {
        mimeType: mimeType,
        body: stream,
      },
      fields: 'id, name, webViewLink, webContentLink, size',
    });

    return {
      fileId: response.data.id,
      fileName: response.data.name,
      webViewLink: response.data.webViewLink,
      size: response.data.size,
    };
  }

  // Get or create a project subfolder in Google Drive
  static async _getOrCreateFolder(drive, folderName, parentId) {
    // Search for existing folder
    const search = await drive.files.list({
      q: `name='${folderName}' and '${parentId}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false`,
      fields: 'files(id, name)',
    });

    if (search.data.files.length > 0) {
      return search.data.files[0].id;
    }

    // Create new folder
    const folder = await drive.files.create({
      requestBody: {
        name: folderName,
        mimeType: 'application/vnd.google-apps.folder',
        parents: [parentId],
      },
      fields: 'id',
    });

    return folder.data.id;
  }

  // Generate a shareable download link
  static async getDownloadLink(fileId) {
    const drive = getGoogleDriveClient();

    // Set file to "anyone with link can view"
    await drive.permissions.create({
      fileId: fileId,
      requestBody: {
        role: 'reader',
        type: 'anyone',
      },
    });

    const file = await drive.files.get({
      fileId: fileId,
      fields: 'webContentLink, webViewLink',
    });

    return {
      downloadUrl: file.data.webContentLink,
      viewUrl: file.data.webViewLink,
    };
  }

  // Delete file from Google Drive
  static async deleteFromGoogleDrive(fileId) {
    const drive = getGoogleDriveClient();
    await drive.files.delete({ fileId });
  }

  // Upload to local storage (fallback)
  static async uploadToLocal(fileBuffer, key) {
    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    const filePath = path.join(uploadDir, key);
    const dir = path.dirname(filePath);

    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(filePath, fileBuffer);
    return { fileId: key, fileName: path.basename(key), size: fileBuffer.length };
  }

  static getLocalUrl(key) {
    return `/uploads/${key}`;
  }

  static deleteLocal(key) {
    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    const filePath = path.join(uploadDir, key);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  }

  // Smart upload - uses Google Drive if configured, local otherwise
  static async upload(fileBuffer, fileName, mimeType, projectId) {
    if (process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL && process.env.GOOGLE_PRIVATE_KEY) {
      return FileService.uploadToGoogleDrive(fileBuffer, fileName, mimeType, projectId);
    }
    const key = `projects/${projectId || 'unknown'}/deliveries/${Date.now()}-${fileName}`;
    return FileService.uploadToLocal(fileBuffer, key);
  }

  // Smart get URL
  static async getDownloadUrl(fileId) {
    if (process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL && process.env.GOOGLE_PRIVATE_KEY) {
      const links = await FileService.getDownloadLink(fileId);
      return links.downloadUrl;
    }
    return FileService.getLocalUrl(fileId);
  }

  // Smart delete
  static async delete(fileId) {
    if (process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL && process.env.GOOGLE_PRIVATE_KEY) {
      return FileService.deleteFromGoogleDrive(fileId);
    }
    return FileService.deleteLocal(fileId);
  }
}

module.exports = FileService;
