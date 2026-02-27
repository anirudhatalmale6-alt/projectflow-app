import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/task.dart';
import 'priority_badge.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final bool showProject;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.showProject = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PriorityBadge(priority: task.priority),
                ],
              ),
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: task.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (task.assigneeName != null) ...[
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                      child: Text(
                        task.assigneeName!.isNotEmpty
                            ? task.assigneeName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.assigneeName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Expanded(
                      child: Text(
                        'Sem responsavel',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (task.dueDate != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 13,
                      color: task.isOverdue
                          ? AppTheme.errorColor
                          : AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('dd/MM').format(task.dueDate!),
                      style: TextStyle(
                        fontSize: 11,
                        color: task.isOverdue
                            ? AppTheme.errorColor
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                  if (task.estimatedHours != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: task.hoursProgress > 1.0
                          ? AppTheme.errorColor
                          : AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${task.actualHours?.toStringAsFixed(1) ?? '0'}/${task.estimatedHours!.toStringAsFixed(0)}h',
                      style: TextStyle(
                        fontSize: 11,
                        color: task.hoursProgress > 1.0
                            ? AppTheme.errorColor
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
