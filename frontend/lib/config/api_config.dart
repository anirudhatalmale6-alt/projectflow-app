class ApiConfig {
  // Base URL - change this to your server address
  static const String baseUrl = 'http://localhost:3000';
  static const String apiVersion = '/api';
  static const String apiBase = '$baseUrl$apiVersion';

  // Socket.IO
  static const String socketUrl = baseUrl;

  // Auth endpoints
  static const String login = '$apiBase/auth/login';
  static const String register = '$apiBase/auth/register';
  static const String profile = '$apiBase/auth/profile';
  static const String updateProfile = '$apiBase/auth/profile';

  // Project endpoints
  static String projects = '$apiBase/projects';
  static String project(String id) => '$apiBase/projects/$id';
  static String projectMembers(String id) => '$apiBase/projects/$id/members';
  static String projectMember(String projectId, String userId) =>
      '$apiBase/projects/$projectId/members/$userId';
  static String projectStats(String id) => '$apiBase/projects/$id/stats';

  // Task endpoints
  static String tasks(String projectId) => '$apiBase/projects/$projectId/tasks';
  static String task(String projectId, String taskId) =>
      '$apiBase/projects/$projectId/tasks/$taskId';
  static String taskStatus(String projectId, String taskId) =>
      '$apiBase/projects/$projectId/tasks/$taskId/status';
  static String taskAssign(String projectId, String taskId) =>
      '$apiBase/projects/$projectId/tasks/$taskId/assign';
  static String myTasks = '$apiBase/tasks/my-tasks';

  // Comment endpoints
  static String comments(String taskId) => '$apiBase/tasks/$taskId/comments';
  static String comment(String taskId, String commentId) =>
      '$apiBase/tasks/$taskId/comments/$commentId';

  // Notification endpoints
  static String notifications = '$apiBase/notifications';
  static String notificationRead(String id) => '$apiBase/notifications/$id/read';
  static String notificationsReadAll = '$apiBase/notifications/read-all';

  // Admin endpoints
  static String adminUsers = '$apiBase/admin/users';
  static String adminUser(String id) => '$apiBase/admin/users/$id';
  static String adminStats = '$apiBase/admin/stats';

  // Request timeout
  static const Duration timeout = Duration(seconds: 30);
}
