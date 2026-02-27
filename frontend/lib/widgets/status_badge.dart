import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/task.dart';

class StatusBadge extends StatelessWidget {
  final TaskStatus status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color get _color {
    switch (status) {
      case TaskStatus.todo:
        return AppTheme.statusTodo;
      case TaskStatus.inProgress:
        return AppTheme.statusInProgress;
      case TaskStatus.review:
        return AppTheme.statusReview;
      case TaskStatus.done:
        return AppTheme.statusDone;
    }
  }

  IconData get _icon {
    switch (status) {
      case TaskStatus.todo:
        return Icons.circle_outlined;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case TaskStatus.review:
        return Icons.visibility_outlined;
      case TaskStatus.done:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
