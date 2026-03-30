import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import '../config/api_config.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this is called
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService();

  bool _initialized = false;
  String? _currentToken;

  String? get currentToken => _currentToken;

  /// Initialize FCM for mobile platforms
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    // Setup local notifications for foreground display
    await _setupLocalNotifications();

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get FCM token
      _currentToken = await _messaging.getToken();
      debugPrint('[FCM] Token: $_currentToken');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _sendTokenToServer(newToken);
      });

      // Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background message tap (app was in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    }
  }

  /// Send FCM token to backend after user login
  Future<void> registerToken() async {
    if (kIsWeb || _currentToken == null) return;
    await _sendTokenToServer(_currentToken!);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await _api.post(ApiConfig.fcmRegister, {
        'token': token,
        'platform': 'ios',
      });
      debugPrint('[FCM] Token registered with server');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }
  }

  /// Unregister token on logout
  Future<void> unregisterToken() async {
    if (kIsWeb || _currentToken == null) return;
    try {
      await _api.post(ApiConfig.fcmUnregister, {
        'token': _currentToken,
      });
    } catch (_) {}
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap from local notification
        if (response.payload != null) {
          _navigateFromPayload(response.payload!);
        }
      },
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'duozzflow_notifications',
      'Duozz Flow',
      description: 'Notificacoes do Duozz Flow',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show local notification since app is in foreground
    _localNotifications.show(
      message.hashCode,
      notification.title ?? 'Duozz Flow',
      notification.body ?? '',
      NotificationDetails(
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: const AndroidNotificationDetails(
          'duozzflow_notifications',
          'Duozz Flow',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[FCM] Message tap: ${message.data}');
    // Navigation will be handled by the app's navigation system
    // The data payload should contain route info
    final data = message.data;
    if (data.containsKey('route')) {
      _navigateFromPayload(jsonEncode(data));
    }
  }

  void _navigateFromPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final route = data['route'] as String?;
      if (route != null) {
        // Store the route for the app to pick up on next frame
        _pendingRoute = route;
        _pendingRouteArgs = data['route_args'] as String?;
      }
    } catch (_) {}
  }

  // Pending navigation from notification tap
  String? _pendingRoute;
  String? _pendingRouteArgs;

  /// Check and consume pending navigation from notification tap
  (String?, String?) consumePendingRoute() {
    final route = _pendingRoute;
    final args = _pendingRouteArgs;
    _pendingRoute = null;
    _pendingRouteArgs = null;
    return (route, args);
  }
}

void debugPrint(String message) {
  if (kIsWeb) return;
  // ignore: avoid_print
  print(message);
}
