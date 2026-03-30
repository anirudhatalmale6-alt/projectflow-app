import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import '../config/api_config.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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
  String? _apnsToken;

  String? get currentToken => _currentToken;
  String? get apnsToken => _apnsToken;

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
      // On iOS, get the raw APNs device token for direct APNs sending
      if (Platform.isIOS) {
        _apnsToken = await _messaging.getAPNSToken();
        debugPrint('[FCM] APNs token: $_apnsToken');
      }

      // Also try to get FCM token (may fail on iOS if Firebase Console APNs not configured)
      try {
        _currentToken = await _messaging.getToken();
        debugPrint('[FCM] FCM Token: $_currentToken');
      } catch (e) {
        debugPrint('[FCM] Could not get FCM token (expected on iOS without APNs config): $e');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _sendFcmTokenToServer(newToken);
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

  /// Send tokens to backend after user login
  Future<void> registerToken() async {
    if (kIsWeb) return;

    // Register APNs token for direct iOS push (primary for iOS)
    if (Platform.isIOS && _apnsToken != null) {
      await _sendApnsTokenToServer(_apnsToken!);
    }

    // Also register FCM token if available (for Android or as backup)
    if (_currentToken != null) {
      await _sendFcmTokenToServer(_currentToken!);
    }
  }

  Future<void> _sendFcmTokenToServer(String token) async {
    try {
      await _api.post(ApiConfig.fcmRegister, {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint('[FCM] FCM token registered with server');
    } catch (e) {
      debugPrint('[FCM] Failed to register FCM token: $e');
    }
  }

  Future<void> _sendApnsTokenToServer(String token) async {
    try {
      await _api.post(ApiConfig.apnsRegister, {
        'token': token,
        'platform': 'ios',
      });
      debugPrint('[FCM] APNs token registered with server');
    } catch (e) {
      debugPrint('[FCM] Failed to register APNs token: $e');
    }
  }

  /// Unregister tokens on logout
  Future<void> unregisterToken() async {
    if (kIsWeb) return;
    try {
      if (_apnsToken != null) {
        await _api.post(ApiConfig.apnsUnregister, {'token': _apnsToken});
      }
      if (_currentToken != null) {
        await _api.post(ApiConfig.fcmUnregister, {'token': _currentToken});
      }
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
