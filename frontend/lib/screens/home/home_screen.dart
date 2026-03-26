import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../projects/projects_list_screen.dart';
import '../tasks/task_board_screen.dart';
import '../deliveries/deliveries_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifProvider = context.read<NotificationProvider>();
      notifProvider.loadNotifications();
      notifProvider.startListening();

      // Initialize push notifications
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) {
        notifProvider.enablePushNotifications(token);
      }
    });
  }

  List<_NavItem> _getNavItems(AuthProvider auth) {
    if (auth.isAdmin || auth.isManager) {
      return [
        _NavItem(
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard,
          label: 'Início',
          screen: DashboardScreen(key: _dashboardKey),
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
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'Admin',
          screen: const AdminDashboardScreen(),
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
          screen: DashboardScreen(key: _dashboardKey),
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
          screen: DashboardScreen(key: _dashboardKey),
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
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: navItems.map((item) => item.screen).toList(),
          ),
          // Global floating notification bell
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/notifications'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        color: AppTheme.textPrimary,
                        size: 22,
                      ),
                      if (notifProvider.unreadCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${notifProvider.unreadCount > 9 ? '9+' : notifProvider.unreadCount}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        // Refresh dashboard data when switching back to it
        if (index == 0) {
          _dashboardKey.currentState?.refreshData();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? (isCompact ? 10 : 16) : (isCompact ? 8 : 12),
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.textPrimary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: isCompact ? 20 : 22,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textTertiary,
            ),
            if (isSelected) ...[
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: isCompact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Poppins',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
