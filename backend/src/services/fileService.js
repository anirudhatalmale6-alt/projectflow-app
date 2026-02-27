const { PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { s3Client, BUCKET_NAME } = require('../config/s3');
const fs = require('fs');
const path = require('path');

class FileService {
  // Upload file to S3 (from buffer)
  static async uploadToS3(fileBuffer, key, contentType) {
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: fileBuffer,
      ContentType: contentType,
      ServerSideEncryption: 'AES256',
    });
    await s3Client.send(command);
    return key;
  }

  // Upload file to local storage (fallback when S3 not configured)
  static async uploadToLocal(fileBuffer, key) {
    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    const filePath = path.join(uploadDir, key);
    const dir = path.dirname(filePath);

    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(filePath, fileBuffer);
    return key;
  }

  // Get presigned download URL from S3
  static async getPresignedUrl(key, expiresIn = 3600) {
    const command = new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
    });
    return getSignedUrl(s3Client, command, { expiresIn });
  }

  // Get local file URL
  static getLocalUrl(key) {
    return `/uploads/${key}`;
  }

  // Delete file from S3
  static async deleteFromS3(key) {
    const command = new DeleteObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
    });
    await s3Client.send(command);
  }

  // Delete local file
  static deleteLocal(key) {
    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    const filePath = path.join(uploadDir, key);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  }

  // Smart upload - uses S3 if configured, local otherwise
  static async upload(fileBuffer, key, contentType) {
    if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
      return this.uploadToS3(fileBuffer, key, contentType);
    }
    return this.uploadToLocal(fileBuffer, key);
  }

  // Smart get URL - presigned for S3, local path otherwise
  static async getDownloadUrl(key) {
    if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
      return this.getPresignedUrl(key);
    }
    return this.getLocalUrl(key);
  }

  // Smart delete
  static async delete(key) {
    if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
      return this.deleteFromS3(key);
    }
    return this.deleteLocal(key);
  }
}

module.exports = FileService;
