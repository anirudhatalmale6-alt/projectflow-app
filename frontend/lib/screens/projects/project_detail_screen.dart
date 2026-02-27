import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().loadProject(widget.projectId);
    });
  }

  @override
  void dispose() {
    // Leave project room
    super.dispose();
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        final project = provider.selectedProject;

        if (provider.isLoading && project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const LoadingWidget(message: 'Loading project...'),
          );
        }

        if (project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorState(
              message: provider.errorMessage ?? 'Project not found',
              onRetry: () => provider.loadProject(widget.projectId),
            ),
          );
        }

        final projectColor = _parseColor(project.color);
        final currentUser = context.read<AuthProvider>().user;
        final isOwner = project.owner?.id == currentUser?.id;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with project color
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: projectColor,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    project.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          projectColor,
                          projectColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.folder_rounded,
                        size: 64,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (isOwner)
                    PopupMenuButton<String>(
                      iconColor: Colors.white,
                      onSelected: (value) async {
                        if (value == 'edit') {
                          // Navigate to edit
                        } else if (value == 'delete') {
                          _showDeleteDialog(context, provider);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Edit Project'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20,
                                  color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text('Delete Project',
                                  style: TextStyle(color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (project.description.isNotEmpty) ...[
                        Text(
                          project.description,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Stats cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Tasks',
                              '${project.taskCount}',
                              Icons.task_alt_rounded,
                              AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Completed',
                              '${project.completedTaskCount}',
                              Icons.check_circle_outline_rounded,
                              AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Members',
                              '${project.memberCount}',
                              Icons.people_outline_rounded,
                              AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Progress
                      _buildProgressSection(project, projectColor),
                      const SizedBox(height: 24),

                      // Quick actions
                      Text('Quick Actions', style: AppTheme.headingSmall),
                      const SizedBox(height: 12),
                      _buildActionTile(
                        Icons.view_kanban_rounded,
                        'Task Board',
                        'View and manage tasks in Kanban view',
                        AppTheme.primaryColor,
                        () => Navigator.of(context).pushNamed(
                          '/task-board',
                          arguments: project.id,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildActionTile(
                        Icons.add_task_rounded,
                        'Create Task',
                        'Add a new task to this project',
                        AppTheme.successColor,
                        () => Navigator.of(context).pushNamed(
                          '/create-task',
                          arguments: project.id,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildActionTile(
                        Icons.people_rounded,
                        'Members',
                        'Manage project members and roles',
                        AppTheme.secondaryColor,
                        () => Navigator.of(context).pushNamed(
                          '/project-members',
                          arguments: project.id,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Owner info
                      if (project.owner != null) ...[
                        Text('Project Owner', style: AppTheme.headingSmall),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: projectColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    project.owner!.initials,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: projectColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.owner!.name,
                                      style: AppTheme.labelMedium,
                                    ),
                                    Text(
                                      project.owner!.email,
                                      style: AppTheme.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(dynamic project, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: AppTheme.labelMedium),
              Text(
                '${(project.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: project.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${project.completedTaskCount} of ${project.taskCount} tasks completed',
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.labelMedium),
                  Text(subtitle, style: AppTheme.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ProjectProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to delete this project? This action cannot be undone and all tasks will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await provider.deleteProject(widget.projectId);
              if (success && mounted) {
                Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
