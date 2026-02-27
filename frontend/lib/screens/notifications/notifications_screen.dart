import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_tile.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  void _handleNotificationTap(notification) {
    // Mark as read
    context.read<NotificationProvider>().markAsRead(notification.id);

    // Navigate based on reference type
    if (notification.referenceType != null &&
        notification.referenceId != null) {
      switch (notification.referenceType) {
        case 'project':
          Navigator.pushNamed(context, '/projects/detail',
              arguments: notification.referenceId);
          break;
        case 'task':
          Navigator.pushNamed(context, '/tasks/detail',
              arguments: notification.referenceId);
          break;
        case 'delivery':
          Navigator.pushNamed(context, '/deliveries/detail',
              arguments: notification.referenceId);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: () => provider.markAllAsRead(),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Marcar todas'),
            ),
        ],
      ),
      body: provider.isLoading
          ? const LoadingWidget(message: 'Carregando notificacoes...')
          : provider.notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'Sem notificacoes',
                  subtitle: 'Você será notificado sobre atualizações nos seus projetos',
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadNotifications(),
                  child: ListView.builder(
                    itemCount: provider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = provider.notifications[index];
                      return NotificationTile(
                        notification: notification,
                        onTap: () =>
                            _handleNotificationTap(notification),
                      );
                    },
                  ),
                ),
    );
  }
}
