import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/notification_sound_stub.dart'
    if (dart.library.html) '../utils/notification_sound_web.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final SocketService _socket = SocketService();
  bool _socketListening = false;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  /// Start listening for real-time notification events via socket
  void startListening() {
    if (_socketListening) return;
    _socketListening = true;

    _socket.on('notification', (data) {
      if (data is Map<String, dynamic>) {
        try {
          final type = data['type'] ?? 'general';
          final title = data['title'] ?? _defaultTitle(type, data);
          final id = data['delivery_id']?.toString() ??
              data['task_id']?.toString() ??
              data['comment_id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString();

          final notification = AppNotification(
            id: id,
            type: type,
            title: title,
            message: data['message'] ?? '',
            isRead: false,
            createdAt: DateTime.now(),
          );
          addNotification(notification);
        } catch (_) {}
      }
    });
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _notificationService.getNotifications();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      _errorMessage = _parseError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await _notificationService.getUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    try {
      await _notificationService.markAsRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index >= 0) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    try {
      await _notificationService.clearAll();
      _notifications.clear();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
      // Play sound for new unread notifications
      try {
        playNotificationSound();
      } catch (_) {}
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _defaultTitle(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'task_assigned':
        return 'Nova tarefa atribuída';
      case 'task_updated':
        return 'Tarefa atualizada';
      case 'delivery_uploaded':
        return 'Novo arquivo enviado';
      case 'approval_requested':
        return 'Aprovação solicitada';
      case 'approval_result':
        final status = data['status'] ?? '';
        if (status == 'approved') return 'Entrega aprovada';
        if (status == 'rejected') return 'Entrega rejeitada';
        return 'Revisão solicitada';
      case 'comment':
        return 'Novo comentário';
      case 'project_invite':
        return 'Convite para projeto';
      default:
        return 'Notificação';
    }
  }

  String _parseError(dynamic error) {
    if (error is ApiException) return error.message;
    return 'Ocorreu um erro. Tente novamente.';
  }
}
