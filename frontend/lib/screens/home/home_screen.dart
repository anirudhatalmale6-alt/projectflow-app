import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../projects/projects_list_screen.dart';
import '../tasks/my_tasks_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ProjectsListScreen(),
    MyTasksScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load notifications for badge count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Consumer<NotificationProvider>(
              builder: (context, notifProvider, _) {
                return BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) => setState(() => _currentIndex = index),
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.folder_outlined),
                      activeIcon: Icon(Icons.folder_rounded),
                      label: 'Projects',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.task_alt_outlined),
                      activeIcon: Icon(Icons.task_alt_rounded),
                      label: 'My Tasks',
                    ),
                    BottomNavigationBarItem(
                      icon: Badge(
                        isLabelVisible: notifProvider.unreadCount > 0,
                        label: Text(
                          notifProvider.unreadCount > 99
                              ? '99+'
                              : '${notifProvider.unreadCount}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        child: const Icon(Icons.notifications_outlined),
                      ),
                      activeIcon: Badge(
                        isLabelVisible: notifProvider.unreadCount > 0,
                        label: Text(
                          notifProvider.unreadCount > 99
                              ? '99+'
                              : '${notifProvider.unreadCount}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        child: const Icon(Icons.notifications_rounded),
                      ),
                      label: 'Notifications',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person_outlined),
                      activeIcon: Icon(Icons.person_rounded),
                      label: 'Profile',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
