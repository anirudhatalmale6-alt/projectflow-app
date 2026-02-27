import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../projects/projects_list_screen.dart';
import '../tasks/task_board_screen.dart';
import '../deliveries/deliveries_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../clients/clients_list_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load notifications on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  List<_NavItem> _getNavItems(AuthProvider auth) {
    if (auth.isAdmin || auth.isManager) {
      return [
        _NavItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: 'Projetos',
          screen: const ProjectsListScreen(),
        ),
        _NavItem(
          icon: Icons.task_outlined,
          activeIcon: Icons.task,
          label: 'Tarefas',
          screen: const TaskBoardScreen(),
        ),
        _NavItem(
          icon: Icons.video_file_outlined,
          activeIcon: Icons.video_file,
          label: 'Entregas',
          screen: const DeliveriesListScreen(),
        ),
        _NavItem(
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          label: 'Avisos',
          screen: const NotificationsScreen(),
        ),
        _NavItem(
          icon: Icons.person_outlined,
          activeIcon: Icons.person,
          label: 'Perfil',
          screen: const ProfileScreen(),
        ),
      ];
    } else if (auth.isEditor || auth.isFreelancer) {
      return [
        _NavItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: 'Meus Projetos',
          screen: const ProjectsListScreen(),
        ),
        _NavItem(
          icon: Icons.task_outlined,
          activeIcon: Icons.task,
          label: 'Minhas Tarefas',
          screen: const TaskBoardScreen(),
        ),
        _NavItem(
          icon: Icons.video_file_outlined,
          activeIcon: Icons.video_file,
          label: 'Entregas',
          screen: const DeliveriesListScreen(),
        ),
        _NavItem(
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          label: 'Avisos',
          screen: const NotificationsScreen(),
        ),
        _NavItem(
          icon: Icons.person_outlined,
          activeIcon: Icons.person,
          label: 'Perfil',
          screen: const ProfileScreen(),
        ),
      ];
    } else {
      // Client
      return [
        _NavItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: 'Meus Projetos',
          screen: const ProjectsListScreen(),
        ),
        _NavItem(
          icon: Icons.video_file_outlined,
          activeIcon: Icons.video_file,
          label: 'Entregas',
          screen: const DeliveriesListScreen(),
        ),
        _NavItem(
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          label: 'Avisos',
          screen: const NotificationsScreen(),
        ),
        _NavItem(
          icon: Icons.person_outlined,
          activeIcon: Icons.person,
          label: 'Perfil',
          screen: const ProfileScreen(),
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final navItems = _getNavItems(auth);
    final notifProvider = context.watch<NotificationProvider>();

    // Clamp index in case role changes
    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: navItems.map((item) => item.screen).toList(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: navItems.map((item) {
            // Find the notifications tab
            final isNotif = item.label == 'Avisos';
            return BottomNavigationBarItem(
              icon: isNotif && notifProvider.unreadCount > 0
                  ? Badge(
                      label: Text(
                        notifProvider.unreadCount > 99
                            ? '99+'
                            : '${notifProvider.unreadCount}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      child: Icon(item.icon),
                    )
                  : Icon(item.icon),
              activeIcon: isNotif && notifProvider.unreadCount > 0
                  ? Badge(
                      label: Text(
                        notifProvider.unreadCount > 99
                            ? '99+'
                            : '${notifProvider.unreadCount}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      child: Icon(item.activeIcon),
                    )
                  : Icon(item.activeIcon),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
  });
}
