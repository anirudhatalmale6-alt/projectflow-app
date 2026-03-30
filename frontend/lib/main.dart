import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'config/api_config.dart';
import 'services/fcm_service.dart';
import 'config/theme.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/job_provider.dart';
import 'providers/calendar_provider.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/projects/projects_list_screen.dart';
import 'screens/projects/project_detail_screen.dart';
import 'screens/projects/create_project_screen.dart';
import 'screens/clients/clients_list_screen.dart';
import 'screens/clients/create_client_screen.dart';
import 'screens/tasks/task_board_screen.dart';
import 'screens/tasks/task_detail_screen.dart';
import 'screens/tasks/create_task_screen.dart';
import 'screens/deliveries/deliveries_list_screen.dart';
import 'screens/deliveries/delivery_detail_screen.dart';
import 'screens/deliveries/upload_delivery_screen.dart';
import 'screens/deliveries/trash_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/audit_log_screen.dart';
import 'screens/chat/chat_channels_screen.dart';
import 'screens/chat/chat_messages_screen.dart';
import 'screens/jobs/jobs_list_screen.dart';
import 'screens/jobs/job_detail_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/reviews/review_player_screen.dart';
import 'screens/drive/drive_files_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ApiConfig.loadConfig();
  } catch (_) {
    // Ignore config load errors, will use defaults
  }

  // Initialize Firebase for mobile push notifications
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FcmService().initialize();
    } catch (e) {
      // Firebase not available on this platform - continue without it
    }
  }

  runApp(const DuozzFlowApp());
}

class DuozzFlowApp extends StatefulWidget {
  const DuozzFlowApp({super.key});

  @override
  State<DuozzFlowApp> createState() => _DuozzFlowAppState();
}

class _DuozzFlowAppState extends State<DuozzFlowApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // For web: listen for visibility changes (tab switching)
    if (kIsWeb) {
      _setupWebVisibilityListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - refresh token proactively
      _refreshTokenOnResume();
    }
  }

  void _setupWebVisibilityListener() {
    // On web, WidgetsBindingObserver does not reliably detect tab switches.
    // We use the HTML visibilitychange event via dart:ui's ChannelBuffers
    // or we rely on the fact that Flutter web 3.13+ maps visibilitychange
    // to AppLifecycleState. For older versions, the _ensureValidToken in
    // ApiService handles it on the next API call.
  }

  Future<void> _refreshTokenOnResume() async {
    try {
      final apiService = ApiService();
      await apiService.loadTokens();
      if (apiService.hasTokens) {
        // The _ensureValidToken check in ApiService will handle
        // proactive refresh on the next API call. We can also
        // trigger it here explicitly.
        await apiService.loadTokens(); // Re-parse expiry
      }
    } catch (_) {
      // Silently ignore - next API call will handle it
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: MaterialApp(
        title: 'Duozz Flow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/projects': (context) => const ProjectsListScreen(),
          '/projects/detail': (context) => const ProjectDetailScreen(),
          '/projects/create': (context) => const CreateProjectScreen(),
          '/clients': (context) => const ClientsListScreen(),
          '/clients/create': (context) => const CreateClientScreen(),
          '/tasks': (context) => const TaskBoardScreen(),
          '/tasks/detail': (context) => const TaskDetailScreen(),
          '/tasks/create': (context) => const CreateTaskScreen(),
          '/deliveries': (context) => const DeliveriesListScreen(),
          '/deliveries/detail': (context) => const DeliveryDetailScreen(),
          '/deliveries/upload': (context) => const UploadDeliveryScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
          '/admin/users': (context) => const AdminUsersScreen(),
          '/admin/audit-log': (context) => const AuditLogScreen(),
          '/chat': (context) => const ChatChannelsScreen(),
          '/chat/messages': (context) => const ChatMessagesScreen(),
          '/jobs': (context) => const JobsListScreen(),
          '/jobs/detail': (context) => const JobDetailScreen(),
          '/calendar': (context) => const CalendarScreen(),
          '/reviews/player': (context) => const ReviewPlayerScreen(),
          '/trash': (context) => const TrashScreen(),
          '/drive': (context) => const DriveFilesScreen(),
        },
      ),
    );
  }
}
