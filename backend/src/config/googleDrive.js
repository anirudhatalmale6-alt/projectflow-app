const { google } = require('googleapis');

function getGoogleDriveClient() {
  const auth = new google.auth.GoogleAuth({
    credentials: {
      client_email: process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL || '',
      private_key: (process.env.GOOGLE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
    },
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  });

  return google.drive({ version: 'v3', auth });
}

const FOLDER_ID = process.env.GOOGLE_DRIVE_FOLDER_ID || '';

module.exports = { getGoogleDriveClient, FOLDER_ID };
