import '../config/api_config.dart';
import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _api = ApiService();

  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int? page,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (unreadOnly == true) params['unread'] = 'true';
    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();

    final data =
        await _api.get(ApiConfig.notifications, queryParams: params);
    final list = data['notifications'] ?? data['data'] ?? data;
    return (list as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await _api.patch(ApiConfig.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _api.post(ApiConfig.notificationsReadAll);
  }

  Future<int> getUnreadCount() async {
    final data = await _api.get(
      ApiConfig.notifications,
      queryParams: {'unread': 'true', 'count_only': 'true'},
    );
    return data['count'] ?? 0;
  }
}
