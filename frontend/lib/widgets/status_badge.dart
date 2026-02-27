import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    required this.label,
    required this.color,
    this.fontSize = 11,
  });

  factory StatusBadge.project(String status) {
    return StatusBadge(
      status: status,
      label: AppTheme.getProjectStatusLabel(status),
      color: AppTheme.getProjectStatusColor(status),
    );
  }

  factory StatusBadge.task(String status) {
    return StatusBadge(
      status: status,
      label: AppTheme.getTaskStatusLabel(status),
      color: AppTheme.getTaskStatusColor(status),
    );
  }

  factory StatusBadge.delivery(String status) {
    return StatusBadge(
      status: status,
      label: AppTheme.getDeliveryStatusLabel(status),
      color: AppTheme.getDeliveryStatusColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
