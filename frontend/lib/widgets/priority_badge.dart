import 'package:flutter/material.dart';
import '../config/theme.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getPriorityColor(priority);
    final label = AppTheme.getPriorityLabel(priority);

    IconData icon;
    switch (priority) {
      case 'urgent':
        icon = Icons.keyboard_double_arrow_up;
        break;
      case 'high':
        icon = Icons.keyboard_arrow_up;
        break;
      case 'medium':
        icon = Icons.remove;
        break;
      case 'low':
        icon = Icons.keyboard_arrow_down;
        break;
      default:
        icon = Icons.remove;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
