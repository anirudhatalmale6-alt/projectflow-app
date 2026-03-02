import '../config/api_config.dart';
import 'api_service.dart';

class DriveFile {
  final String id;
  final String name;
  final String? mimeType;
  final String? size;
  final String? modifiedTime;
  final String? webViewLink;
  final String? thumbnailLink;
  final String? iconLink;

  DriveFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.size,
    this.modifiedTime,
    this.webViewLink,
    this.thumbnailLink,
    this.iconLink,
  });

  factory DriveFile.fromJson(Map<String, dynamic> json) {
    return DriveFile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      mimeType: json['mimeType'],
      size: json['size']?.toString(),
      modifiedTime: json['modifiedTime'],
      webViewLink: json['webViewLink'],
      thumbnailLink: json['thumbnailLink'],
      iconLink: json['iconLink'],
    );
  }

  bool get isFolder => mimeType == 'application/vnd.google-apps.folder';
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isDocument =>
      mimeType?.contains('document') == true ||
      mimeType?.contains('pdf') == true ||
      mimeType?.contains('text') == true;

  String get sizeFormatted {
    if (size == null) return '';
    final bytes = int.tryParse(size!) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class DriveStatus {
  final bool connected;
  final bool userHasGoogle;
  final String? driveFolderId;
  final String? driveFolderUrl;
  final Map<String, dynamic>? driveFolders;

  DriveStatus({
    required this.connected,
    required this.userHasGoogle,
    this.driveFolderId,
    this.driveFolderUrl,
    this.driveFolders,
  });

  factory DriveStatus.fromJson(Map<String, dynamic> json) {
    return DriveStatus(
      connected: json['connected'] ?? false,
      userHasGoogle: json['user_has_google'] ?? false,
      driveFolderId: json['drive_folder_id'],
      driveFolderUrl: json['drive_folder_url'],
      driveFolders: json['drive_folders'] is Map
          ? Map<String, dynamic>.from(json['drive_folders'])
          : null,
    );
  }
}

class DriveService {
  final ApiService _api = ApiService();

  Future<DriveStatus> getStatus(String projectId) async {
    final data = await _api.get(ApiConfig.driveStatus(projectId));
    return DriveStatus.fromJson(data);
  }

  Future<Map<String, dynamic>> setupDrive(String projectId) async {
    return await _api.post(ApiConfig.driveSetup(projectId));
  }

  Future<List<DriveFile>> listFiles(String projectId,
      {String folder = 'root', String? query}) async {
    String url = '${ApiConfig.driveFiles(projectId)}?folder=$folder';
    if (query != null && query.isNotEmpty) {
      url += '&query=${Uri.encodeComponent(query)}';
    }
    final data = await _api.get(url);
    final list = (data['files'] ?? []) as List;
    return list.map((f) => DriveFile.fromJson(f)).toList();
  }

  Future<Map<String, dynamic>> getFileLink(String fileId) async {
    return await _api.get(ApiConfig.driveFileLink(fileId));
  }

  Future<void> deleteFile(String fileId) async {
    await _api.delete(ApiConfig.driveFileDelete(fileId));
  }
}
