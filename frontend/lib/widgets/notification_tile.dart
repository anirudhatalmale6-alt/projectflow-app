import 'package:flutter/material.dart';
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

  Color get _iconColor {
    switch (notification.iconType) {
      case IconType.taskAssigned:
        return AppTheme.primaryColor;
      case IconType.taskUpdated:
        return AppTheme.warningColor;
      case IconType.taskCompleted:
        return AppTheme.successColor;
      case IconType.comment:
        return AppTheme.secondaryColor;
      case IconType.mention:
        return AppTheme.infoColor;
      case IconType.projectInvite:
        return AppTheme.primaryColor;
      case IconType.general:
        return AppTheme.textSecondary;
    }
  }

  IconData get _iconData {
    switch (notification.iconType) {
      case IconType.taskAssigned:
        return Icons.assignment_ind_outlined;
      case IconType.taskUpdated:
        return Icons.update_rounded;
      case IconType.taskCompleted:
        return Icons.check_circle_outline_rounded;
      case IconType.comment:
        return Icons.chat_bubble_outline_rounded;
      case IconType.mention:
        return Icons.alternate_email_rounded;
      case IconType.projectInvite:
        return Icons.group_add_outlined;
      case IconType.general:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : AppTheme.primaryColor.withOpacity(0.04),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData, size: 20, color: _iconColor),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: AppTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.timeAgo,
                    style: AppTheme.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),

            // Unread indicator
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
