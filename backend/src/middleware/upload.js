const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  // Allow video, image, audio, document files
  const allowedMimes = [
    'video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/webm', 'video/x-matroska',
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml',
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/aac',
    'application/pdf',
    'application/zip', 'application/x-zip-compressed',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  ];

  if (allowedMimes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`File type ${file.mimetype} not allowed`), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: parseInt(process.env.MAX_FILE_SIZE) || 524288000, // 500MB default
  },
});

function generateFileKey(projectId, originalName) {
  const ext = path.extname(originalName);
  const hash = crypto.randomBytes(8).toString('hex');
  const timestamp = Date.now();
  return `projects/${projectId}/deliveries/${timestamp}-${hash}${ext}`;
}

module.exports = { upload, generateFileKey };
