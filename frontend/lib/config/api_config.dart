import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const String _serverUrl = 'https://duozzflow.com';

  static Future<void> loadConfig() async {
    // Using hardcoded HTTPS URL
  }

  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return origin;
    }
    return _serverUrl;
  }

  static const String apiPrefix = '/api/v1';

  static String get wsUrl {
    // Socket.IO client internally converts https→wss for WebSocket transport.
    // Dart's Uri treats wss:// as unknown scheme → port defaults to 0.
    // Fix: always include explicit port so the library never infers port 0.
    if (kIsWeb) {
      final uri = Uri.base;
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      return '${uri.scheme}://${uri.host}:$port';
    }
    return 'https://duozzflow.com:443';
  }

  // Auth
  static const String login = '$apiPrefix/auth/login';
  static const String register = '$apiPrefix/auth/register';
  static const String refreshToken = '$apiPrefix/auth/refresh';
  static const String logout = '$apiPrefix/auth/logout';
  static const String me = '$apiPrefix/auth/me';
  static const String updateProfile = '$apiPrefix/auth/profile';
  static const String googleAuth = '$apiPrefix/auth/google';

  // Clients
  static const String clients = '$apiPrefix/clients';
  static String clientById(String id) => '$apiPrefix/clients/$id';

  // Projects
  static const String projects = '$apiPrefix/projects';
  static String projectById(String id) => '$apiPrefix/projects/$id';
  static String projectMembers(String id) => '$apiPrefix/projects/$id/members';
  static String projectMember(String projectId, String userId) =>
      '$apiPrefix/projects/$projectId/members/$userId';

  // Tasks
  static const String tasks = '$apiPrefix/tasks';
  static String tasksByProject(String projectId) =>
      '$apiPrefix/projects/$projectId/tasks';
  static String taskById(String id) => '$apiPrefix/tasks/$id';
  static String taskStatus(String id) => '$apiPrefix/tasks/$id/status';
  static String taskPosition(String id) => '$apiPrefix/tasks/$id/position';
  static String taskHours(String id) => '$apiPrefix/tasks/$id/hours';

  // Deliveries
  static const String deliveries = '$apiPrefix/deliveries';
  static String deliveriesByProject(String projectId) =>
      '$apiPrefix/projects/$projectId/deliveries';
  static String deliveriesByTask(String taskId) =>
      '$apiPrefix/tasks/$taskId/deliveries';
  static String deliveryById(String id) => '$apiPrefix/deliveries/$id';
  static String deliveryDownload(String id) => '$apiPrefix/deliveries/$id/download';
  static String deliveryApprove(String id) => '$apiPrefix/deliveries/$id/approve';
  static String deliveryReject(String id) => '$apiPrefix/deliveries/$id/reject';
  static String deliveryRevision(String id) =>
      '$apiPrefix/deliveries/$id/request-revision';

  // Trash
  static const String trash = '$apiPrefix/trash';
  static String trashRestore(String id) => '$apiPrefix/trash/$id/restore';
  static String trashDelete(String id) => '$apiPrefix/trash/$id';

  // Comments
  static String comments(String entityType, String entityId) =>
      '$apiPrefix/$entityType/$entityId/comments';
  static String commentById(String id) => '$apiPrefix/comments/$id';

  // Notifications
  static const String notifications = '$apiPrefix/notifications';
  static String notificationRead(String id) =>
      '$apiPrefix/notifications/$id/read';
  static const String notificationsReadAll = '$apiPrefix/notifications/read-all';

  // Jobs
  static String jobsByProject(String projectId) =>
      '$apiPrefix/projects/$projectId/jobs';
  static String jobById(String id) => '$apiPrefix/jobs/$id';
  static String jobStatus(String id) => '$apiPrefix/jobs/$id/status';

  // Assets
  static String assetsByJob(String jobId) => '$apiPrefix/jobs/$jobId/assets';
  static String assetById(String id) => '$apiPrefix/assets/$id';
  static String assetVersions(String id) => '$apiPrefix/assets/$id/versions';

  // Reviews
  static String reviewsByJob(String jobId) =>
      '$apiPrefix/jobs/$jobId/reviews';
  static String reviewById(String id) => '$apiPrefix/reviews/$id';
  static String reviewComments(String id) => '$apiPrefix/reviews/$id/comments';

  // Chat
  static String chatChannels(String projectId) =>
      '$apiPrefix/projects/$projectId/channels';
  static String channelMessages(String channelId) =>
      '$apiPrefix/channels/$channelId/messages';

  // Calendar
  static String calendarEvents(String projectId) =>
      '$apiPrefix/projects/$projectId/calendar/events';
  static String calendarEventById(String id) =>
      '$apiPrefix/calendar/events/$id';
  static const String googleCalendarStatus = '$apiPrefix/calendar/google/status';
  static String googleCalendarImport(String projectId) =>
      '$apiPrefix/projects/$projectId/calendar/sync/import';
  static String googleCalendarExport(String projectId) =>
      '$apiPrefix/projects/$projectId/calendar/sync/export';

  // Google Drive
  static String driveStatus(String projectId) =>
      '$apiPrefix/projects/$projectId/drive/status';
  static String driveSetup(String projectId) =>
      '$apiPrefix/projects/$projectId/drive/setup';
  static String driveFiles(String projectId) =>
      '$apiPrefix/projects/$projectId/drive/files';
  static String driveUpload(String projectId) =>
      '$apiPrefix/projects/$projectId/drive/upload';
  static String driveFileLink(String fileId) =>
      '$apiPrefix/drive/files/$fileId/link';
  static String driveFileDelete(String fileId) =>
      '$apiPrefix/drive/files/$fileId';

  // Admin
  static const String adminUsers = '$apiPrefix/admin/users';
  static String adminUserById(String id) => '$apiPrefix/admin/users/$id';
  static const String adminPendingUsers = '$apiPrefix/admin/users/pending';
  static String adminApproveUser(String id) => '$apiPrefix/admin/users/$id/approve';
  static String adminRejectUser(String id) => '$apiPrefix/admin/users/$id/reject';
  static const String adminStats = '$apiPrefix/admin/stats';
  static const String adminAuditLog = '$apiPrefix/admin/audit-log';

  // FCM Push Notifications (mobile)
  static const String fcmRegister = '$apiPrefix/push/fcm/register';
  static const String fcmUnregister = '$apiPrefix/push/fcm/unregister';

  // Users (public - any authenticated user)
  static const String allUsers = '$apiPrefix/users';
}
