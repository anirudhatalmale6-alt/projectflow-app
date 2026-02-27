import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class TaskBoardScreen extends StatefulWidget {
  final String? projectId;

  const TaskBoardScreen({super.key, this.projectId});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  bool _isKanbanView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<TaskProvider>().loadTasks(
            projectId: widget.projectId,
            assigneeId:
                (auth.isEditor || auth.isFreelancer) ? auth.user?.id : null,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: widget.projectId != null
          ? null
          : AppBar(
              title: Text(
                (auth.isEditor || auth.isFreelancer)
                    ? 'Minhas Tarefas'
                    : 'Tarefas',
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isKanbanView ? Icons.view_list : Icons.view_column,
                  ),
                  tooltip:
                      _isKanbanView ? 'Visualizacao em lista' : 'Kanban',
                  onPressed: () {
                    setState(() => _isKanbanView = !_isKanbanView);
                  },
                ),
              ],
            ),
      body: taskProvider.isLoading
          ? const LoadingWidget(message: 'Carregando tarefas...')
          : taskProvider.tasks.isEmpty
              ? EmptyState(
                  icon: Icons.task_outlined,
                  title: 'Nenhuma tarefa',
                  subtitle: 'As tarefas aparecerao aqui',
                  actionLabel:
                      auth.canAssignTasks ? 'Criar Tarefa' : null,
                  onAction: auth.canAssignTasks
                      ? () => Navigator.pushNamed(context, '/tasks/create',
                          arguments: widget.projectId)
                      : null,
                )
              : _isKanbanView
                  ? _buildKanbanView(taskProvider)
                  : _buildListView(taskProvider),
      floatingActionButton: auth.canAssignTasks
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/tasks/create',
                  arguments: widget.projectId),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildKanbanView(TaskProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKanbanColumn(
            'A Fazer',
            'todo',
            provider.todoTasks,
            AppTheme.statusDraft,
          ),
          _buildKanbanColumn(
            'Em Progresso',
            'in_progress',
            provider.inProgressTasks,
            AppTheme.statusInProgress,
          ),
          _buildKanbanColumn(
            'Revisao',
            'review',
            provider.reviewTasks,
            AppTheme.statusReview,
          ),
          _buildKanbanColumn(
            'Concluido',
            'done',
            provider.doneTasks,
            AppTheme.statusCompleted,
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(
    String title,
    String status,
    List tasks,
    Color color,
  ) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<Map<String, dynamic>>(
              onAcceptWithDetails: (details) {
                final data = details.data;
                context.read<TaskProvider>().moveTask(
                      data['task_id'],
                      status,
                      tasks.length,
                    );
              },
              builder: (context, candidateData, rejectedData) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Draggable<Map<String, dynamic>>(
                      data: {'task_id': task.id, 'from_status': task.status},
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 260,
                          child: TaskCard(task: task),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: TaskCard(task: task),
                      ),
                      child: TaskCard(
                        task: task,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/tasks/detail',
                          arguments: task.id,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(TaskProvider provider) {
    final allTasks = provider.tasks;
    return RefreshIndicator(
      onRefresh: () => provider.loadTasks(projectId: widget.projectId),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allTasks.length,
        itemBuilder: (context, index) {
          final task = allTasks[index];
          return TaskCard(
            task: task,
            onTap: () => Navigator.pushNamed(context, '/tasks/detail',
                arguments: task.id),
          );
        },
      ),
    );
  }
}
