import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class TaskBoardScreen extends StatefulWidget {
  final String projectId;

  const TaskBoardScreen({super.key, required this.projectId});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks(widget.projectId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              // Could add filter options
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<TaskProvider>().loadTasks(widget.projectId);
            },
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.tasks.isEmpty) {
            return const LoadingWidget(message: 'Loading tasks...');
          }

          if (provider.errorMessage != null && provider.tasks.isEmpty) {
            return ErrorState(
              message: provider.errorMessage!,
              onRetry: () => provider.loadTasks(widget.projectId),
            );
          }

          if (provider.tasks.isEmpty) {
            return EmptyState(
              icon: Icons.view_kanban_outlined,
              title: 'No tasks yet',
              subtitle: 'Create your first task to get the board going',
              actionLabel: 'Create Task',
              onAction: () => Navigator.of(context).pushNamed(
                '/create-task',
                arguments: widget.projectId,
              ),
            );
          }

          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KanbanColumn(
                  status: TaskStatus.todo,
                  title: 'To Do',
                  color: AppTheme.statusTodo,
                  icon: Icons.circle_outlined,
                  tasks: provider.todoTasks,
                  projectId: widget.projectId,
                ),
                const SizedBox(width: 12),
                _KanbanColumn(
                  status: TaskStatus.inProgress,
                  title: 'In Progress',
                  color: AppTheme.statusInProgress,
                  icon: Icons.play_circle_outline_rounded,
                  tasks: provider.inProgressTasks,
                  projectId: widget.projectId,
                ),
                const SizedBox(width: 12),
                _KanbanColumn(
                  status: TaskStatus.review,
                  title: 'Review',
                  color: AppTheme.statusReview,
                  icon: Icons.visibility_outlined,
                  tasks: provider.reviewTasks,
                  projectId: widget.projectId,
                ),
                const SizedBox(width: 12),
                _KanbanColumn(
                  status: TaskStatus.done,
                  title: 'Done',
                  color: AppTheme.statusDone,
                  icon: Icons.check_circle_outline_rounded,
                  tasks: provider.doneTasks,
                  projectId: widget.projectId,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(
          '/create-task',
          arguments: widget.projectId,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final TaskStatus status;
  final String title;
  final Color color;
  final IconData icon;
  final List<Task> tasks;
  final String projectId;

  const _KanbanColumn({
    required this.status,
    required this.title,
    required this.color,
    required this.icon,
    required this.tasks,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.75;
    final columnWidth = width.clamp(280.0, 320.0);

    return Container(
      width: columnWidth,
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Task cards area (scrollable + drag target)
          Expanded(
            child: DragTarget<Task>(
              onAcceptWithDetails: (details) {
                final task = details.data;
                if (task.status != status) {
                  context.read<TaskProvider>().updateTaskStatus(
                        projectId,
                        task.id,
                        status,
                      );
                }
              },
              onWillAcceptWithDetails: (details) {
                return details.data.status != status;
              },
              builder: (context, candidateData, rejectedData) {
                final isHighlighted = candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? color.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              isHighlighted
                                  ? 'Drop here'
                                  : 'No tasks',
                              style: TextStyle(
                                fontSize: 13,
                                color: color.withOpacity(0.5),
                                fontWeight: isHighlighted
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return LongPressDraggable<Task>(
                              data: task,
                              feedback: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: columnWidth - 16,
                                  child: TaskCard(
                                    task: task,
                                    isDragging: true,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: TaskCard(task: task),
                              ),
                              child: TaskCard(
                                task: task,
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    '/task-detail',
                                    arguments: {
                                      'projectId': projectId,
                                      'taskId': task.id,
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
