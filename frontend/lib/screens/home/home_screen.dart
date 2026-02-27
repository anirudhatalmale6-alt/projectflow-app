import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../projects/projects_list_screen.dart';
import '../tasks/task_board_screen.dart';
import '../deliveries/deliveries_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  List<_NavItem> _getNavItems(AuthProvider auth) {
    if (auth.isAdmin || auth.isManager) {
      return [
        _NavItem(
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard,
          label: 'Início',
          screen: const DashboardScreen(),
        ),
        _NavItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: 'Projetos',
          screen: const ProjectsListScreen(),
        ),
        _NavItem(
          icon: Icons.view_kanban_outlined,
          activeIcon: Icons.view_kanban,
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
          icon: Icons.person_outlined,
          activeIcon: Icons.person,
          label: 'Perfil',
          screen: const ProfileScreen(),
        ),
      ];
    } else if (auth.isEditor || auth.isFreelancer) {
      return [
        _NavItem(
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard,
          label: 'Início',
          screen: const DashboardScreen(),
        ),
        _NavItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: 'Projetos',
          screen: const ProjectsListScreen(),
        ),
        _NavItem(
          icon: Icons.view_kanban_outlined,
          activeIcon: Icons.view_kanban,
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
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard,
          label: 'Início',
          screen: const DashboardScreen(),
        ),
        _NavItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: 'Projetos',
          screen: const ProjectsListScreen(),
        ),
        _NavItem(
          icon: Icons.video_file_outlined,
          activeIcon: Icons.video_file,
          label: 'Entregas',
          screen: const DeliveriesListScreen(),
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = _currentIndex == index;
                return _buildNavItem(item, isSelected, index, notifProvider);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      _NavItem item, bool isSelected, int index, NotificationProvider notifs) {
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 22,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ],
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
