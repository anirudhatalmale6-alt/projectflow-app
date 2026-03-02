const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  // Accept all common file types for video editing platform
  // Only block potentially dangerous types
  const blockedMimes = ['application/x-msdownload', 'application/x-executable'];
  if (blockedMimes.includes(file.mimetype)) {
    cb(new Error(`File type ${file.mimetype} not allowed`), false);
  } else {
    cb(null, true);
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
