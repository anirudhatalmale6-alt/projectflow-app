import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/task.dart';
import 'priority_badge.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final bool showProject;
  final bool isDragging;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.showProject = false,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDragging
                ? AppTheme.primaryColor
                : Colors.grey.shade200,
            width: isDragging ? 2 : 1,
          ),
          boxShadow: isDragging
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority and due date row
              Row(
                children: [
                  PriorityBadge(priority: task.priority, compact: false),
                  const Spacer(),
                  if (task.dueDate != null)
                    _buildDueDate(),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: AppTheme.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),

              // Bottom row: tags, comments, assignee
              Row(
                children: [
                  if (task.tags.isNotEmpty) ...[
                    ...task.tags.take(2).map((tag) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )),
                    if (task.tags.length > 2)
                      Text(
                        '+${task.tags.length - 2}',
                        style: AppTheme.caption.copyWith(fontSize: 10),
                      ),
                  ],
                  const Spacer(),
                  if (task.commentCount > 0) ...[
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 2),
                    Text(
                      '${task.commentCount}',
                      style: AppTheme.caption.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildAssigneeAvatar(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDueDate() {
    final isOverdue = task.isOverdue;
    final isDueSoon = task.isDueSoon;
    final color = isOverdue
        ? AppTheme.errorColor
        : isDueSoon
            ? AppTheme.warningColor
            : AppTheme.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          DateFormat('MMM d').format(task.dueDate!),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeAvatar() {
    if (task.assignee == null) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: 14,
          color: AppTheme.textTertiary,
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          task.assignee!.initials,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}
