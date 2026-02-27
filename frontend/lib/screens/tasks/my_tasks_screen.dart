import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedFilter;

  final _filters = [
    {'label': 'All', 'value': null},
    {'label': 'To Do', 'value': 'todo'},
    {'label': 'In Progress', 'value': 'in_progress'},
    {'label': 'Review', 'value': 'review'},
    {'label': 'Done', 'value': 'done'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadMyTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Task> _getFilteredTasks(List<Task> tasks) {
    if (_selectedFilter == null) return tasks;
    return tasks
        .where((t) => t.status.value == _selectedFilter)
        .toList();
  }

  List<Task> _getOverdueTasks(List<Task> tasks) {
    return tasks.where((t) => t.isOverdue).toList();
  }

  List<Task> _getUpcomingTasks(List<Task> tasks) {
    return tasks.where((t) => t.isDueSoon && !t.isOverdue).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Tasks'),
            Tab(text: 'Timeline'),
          ],
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
        ),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.myTasks.isEmpty) {
            return const LoadingWidget(message: 'Loading your tasks...');
          }

          if (provider.errorMessage != null && provider.myTasks.isEmpty) {
            return ErrorState(
              message: provider.errorMessage!,
              onRetry: () => provider.loadMyTasks(),
            );
          }

          if (provider.myTasks.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No tasks assigned',
              subtitle: 'Tasks assigned to you will appear here',
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // All tasks tab
              _buildAllTasksTab(provider),
              // Timeline tab
              _buildTimelineTab(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllTasksTab(TaskProvider provider) {
    final filtered = _getFilteredTasks(provider.myTasks);

    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected =
                  _selectedFilter == filter['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter['label'] as String),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter =
                          selected ? filter['value'] as String? : null;
                    });
                  },
                  selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),

        // Task count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${filtered.length} task${filtered.length != 1 ? 's' : ''}',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),

        // Task list
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.filter_list_off_rounded,
                  title: 'No tasks match filter',
                  subtitle: 'Try a different filter',
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadMyTasks(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildTaskListTile(filtered[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab(TaskProvider provider) {
    final overdue = _getOverdueTasks(provider.myTasks);
    final upcoming = _getUpcomingTasks(provider.myTasks);
    final rest = provider.myTasks
        .where((t) => !t.isOverdue && !t.isDueSoon && t.status != TaskStatus.done)
        .toList();
    final done = provider.myTasks
        .where((t) => t.status == TaskStatus.done)
        .toList();

    return RefreshIndicator(
      onRefresh: () => provider.loadMyTasks(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overdue.isNotEmpty) ...[
            _buildSectionHeader(
              'Overdue',
              Icons.warning_amber_rounded,
              AppTheme.errorColor,
              overdue.length,
            ),
            ...overdue.map(_buildTaskListTile),
            const SizedBox(height: 16),
          ],
          if (upcoming.isNotEmpty) ...[
            _buildSectionHeader(
              'Due Soon',
              Icons.schedule_rounded,
              AppTheme.warningColor,
              upcoming.length,
            ),
            ...upcoming.map(_buildTaskListTile),
            const SizedBox(height: 16),
          ],
          if (rest.isNotEmpty) ...[
            _buildSectionHeader(
              'Other',
              Icons.task_alt_outlined,
              AppTheme.textSecondary,
              rest.length,
            ),
            ...rest.map(_buildTaskListTile),
            const SizedBox(height: 16),
          ],
          if (done.isNotEmpty) ...[
            _buildSectionHeader(
              'Completed',
              Icons.check_circle_outline_rounded,
              AppTheme.successColor,
              done.length,
            ),
            ...done.map(_buildTaskListTile),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskListTile(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/task-detail',
            arguments: {
              'projectId': task.projectId,
              'taskId': task.id,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor(task.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        decoration: task.status == TaskStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PriorityBadge(priority: task.priority, compact: true),
                        const SizedBox(width: 8),
                        StatusBadge(status: task.status),
                        if (task.dueDate != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: task.isOverdue
                                ? AppTheme.errorColor
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat('MMM d').format(task.dueDate!),
                            style: TextStyle(
                              fontSize: 11,
                              color: task.isOverdue
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

              Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(TaskStatus status) {
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
}
