import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'config/theme.dart';
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
  runApp(const DuozzFlowApp());
}

class DuozzFlowApp extends StatelessWidget {
  const DuozzFlowApp({super.key});

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
