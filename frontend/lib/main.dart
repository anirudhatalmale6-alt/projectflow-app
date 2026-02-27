import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'providers/notification_provider.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/projects/project_detail_screen.dart';
import 'screens/projects/create_project_screen.dart';
import 'screens/projects/project_members_screen.dart';
import 'screens/tasks/task_board_screen.dart';
import 'screens/tasks/task_detail_screen.dart';
import 'screens/tasks/create_task_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_users_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock orientation to portrait on mobile
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProjectManagerApp());
}

class ProjectManagerApp extends StatelessWidget {
  const ProjectManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'ProjectFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case '/':
        page = const SplashScreen();
        break;

      case '/login':
        page = const LoginScreen();
        break;

      case '/register':
        page = const RegisterScreen();
        break;

      case '/home':
        page = const HomeScreen();
        break;

      case '/project-detail':
        final projectId = settings.arguments as String;
        page = ProjectDetailScreen(projectId: projectId);
        break;

      case '/create-project':
        page = const CreateProjectScreen();
        break;

      case '/project-members':
        final projectId = settings.arguments as String;
        page = ProjectMembersScreen(projectId: projectId);
        break;

      case '/task-board':
        final projectId = settings.arguments as String;
        page = TaskBoardScreen(projectId: projectId);
        break;

      case '/task-detail':
        final args = settings.arguments as Map<String, String>;
        page = TaskDetailScreen(
          projectId: args['projectId']!,
          taskId: args['taskId']!,
        );
        break;

      case '/create-task':
        final projectId = settings.arguments as String;
        page = CreateTaskScreen(projectId: projectId);
        break;

      case '/admin-dashboard':
        page = const AdminDashboardScreen();
        break;

      case '/admin-users':
        page = const AdminUsersScreen();
        break;

      default:
        page = const SplashScreen();
    }

    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}
