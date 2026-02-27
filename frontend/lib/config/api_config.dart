class ApiConfig {
  static const String baseUrl = 'http://localhost:3000';
  static const String apiPrefix = '/api/v1';
  static const String wsUrl = 'ws://localhost:3000';

  // Auth
  static const String login = '$apiPrefix/auth/login';
  static const String register = '$apiPrefix/auth/register';
  static const String refreshToken = '$apiPrefix/auth/refresh';
  static const String logout = '$apiPrefix/auth/logout';
  static const String me = '$apiPrefix/auth/me';
  static const String updateProfile = '$apiPrefix/auth/profile';

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
  static String deliveryById(String id) => '$apiPrefix/deliveries/$id';
  static String deliveryApprove(String id) => '$apiPrefix/deliveries/$id/approve';
  static String deliveryReject(String id) => '$apiPrefix/deliveries/$id/reject';
  static String deliveryRevision(String id) =>
      '$apiPrefix/deliveries/$id/request-revision';

  // Comments
  static String comments(String entityType, String entityId) =>
      '$apiPrefix/$entityType/$entityId/comments';
  static String commentById(String id) => '$apiPrefix/comments/$id';

  // Notifications
  static const String notifications = '$apiPrefix/notifications';
  static String notificationRead(String id) =>
      '$apiPrefix/notifications/$id/read';
  static const String notificationsReadAll = '$apiPrefix/notifications/read-all';

  // Admin
  static const String adminUsers = '$apiPrefix/admin/users';
  static String adminUserById(String id) => '$apiPrefix/admin/users/$id';
  static const String adminStats = '$apiPrefix/admin/stats';
  static const String adminAuditLog = '$apiPrefix/admin/audit-log';
}
