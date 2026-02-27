import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/notification.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  IconData _getTypeIcon() {
    switch (notification.type) {
      case 'project':
        return Icons.folder_outlined;
      case 'task':
        return Icons.task_outlined;
      case 'delivery':
        return Icons.video_file_outlined;
      case 'comment':
        return Icons.comment_outlined;
      case 'approval':
        return Icons.check_circle_outline;
      case 'member':
        return Icons.group_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getTypeColor() {
    switch (notification.type) {
      case 'project':
        return AppTheme.primaryColor;
      case 'task':
        return AppTheme.secondaryColor;
      case 'delivery':
        return const Color(0xFFF59E0B);
      case 'comment':
        return const Color(0xFF06B6D4);
      case 'approval':
        return AppTheme.successColor;
      case 'member':
        return const Color(0xFFEC4899);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : AppTheme.primaryColor.withOpacity(0.04),
          border: Border(
            bottom: BorderSide(color: AppTheme.dividerColor),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTypeIcon(),
                color: typeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (notification.createdAt != null)
                    Text(
                      _timeAgo(notification.createdAt!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'Ha ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Ha ${diff.inHours}h';
    if (diff.inDays < 7) return 'Ha ${diff.inDays} dias';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}
