import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/project.dart';
import 'status_badge.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback? onTap;

  const ProjectCard({super.key, required this.project, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: project.color != null
                          ? Color(int.parse('0xFF${project.color!.replaceAll('#', '')}'))
                          : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (project.clientName != null)
                          Text(
                            project.clientName!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  StatusBadge.project(project.status),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: project.taskStats.progress,
                  backgroundColor: AppTheme.dividerColor,
                  color: AppTheme.primaryColor,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${(project.taskStats.progress * 100).toInt()}% concluido',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (project.taskStats.total > 0)
                    Text(
                      '${project.taskStats.done}/${project.taskStats.total} tarefas',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (project.deadline != null) ...[
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: project.isOverdue
                          ? AppTheme.errorColor
                          : AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy').format(project.deadline!),
                      style: TextStyle(
                        fontSize: 12,
                        color: project.isOverdue
                            ? AppTheme.errorColor
                            : AppTheme.textTertiary,
                        fontWeight: project.isOverdue
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (project.deliveryCount > 0) ...[
                    const Icon(
                      Icons.video_file_outlined,
                      size: 14,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${project.deliveryCount} entregas',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Member avatars
                  if (project.members.isNotEmpty)
                    SizedBox(
                      height: 28,
                      child: _buildMemberAvatars(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberAvatars() {
    const maxShow = 3;
    final showMembers = project.members.take(maxShow).toList();
    final remaining = project.members.length - maxShow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...showMembers.asMap().entries.map((entry) {
          return Transform.translate(
            offset: Offset(-entry.key * 8.0, 0),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                entry.value.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
        if (remaining > 0)
          Transform.translate(
            offset: Offset(-showMembers.length * 8.0, 0),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.textTertiary,
              child: Text(
                '+$remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
