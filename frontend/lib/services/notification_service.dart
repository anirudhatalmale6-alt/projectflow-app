import '../config/api_config.dart';
import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _api = ApiService();

  Future<List<AppNotification>> getNotifications() async {
    final response = await _api.get(ApiConfig.notifications);
    final List<dynamic> data =
        response['notifications'] ?? response['data'] ?? response;
    return data.map((json) => AppNotification.fromJson(json)).toList();
  }

  Future<void> markAsRead(String id) async {
    await _api.patch(ApiConfig.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _api.patch(ApiConfig.notificationsReadAll);
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get(ApiConfig.notifications);
    final List<dynamic> data =
        response['notifications'] ?? response['data'] ?? response;
    return data
        .where((n) => n['isRead'] == false)
        .length;
  }
}
