import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/comment_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/hours_tracker.dart';
import '../../widgets/comment_widget.dart';
import '../../widgets/loading_widget.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final CommentService _commentService = CommentService();
  List<Comment> _comments = [];
  bool _loadingComments = false;
  bool _sendingComment = false;
  String? _taskId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id != _taskId) {
      _taskId = id;
      context.read<TaskProvider>().loadTask(id);
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    if (_taskId == null) return;
    setState(() => _loadingComments = true);
    try {
      _comments = await _commentService.getComments('task', _taskId!);
    } catch (_) {}
    setState(() => _loadingComments = false);
  }

  Future<void> _addComment(String content) async {
    if (_taskId == null) return;
    setState(() => _sendingComment = true);
    try {
      final comment =
          await _commentService.createComment('task', _taskId!, content);
      setState(() {
        _comments.insert(0, comment);
      });
    } catch (_) {}
    setState(() => _sendingComment = false);
  }

  void _changeStatus(String newStatus) {
    context.read<TaskProvider>().updateTaskStatus(_taskId!, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final task = taskProvider.currentTask;
    final auth = context.watch<AuthProvider>();

    if (taskProvider.isLoading || task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const LoadingWidget(message: 'Carregando tarefa...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Tarefa'),
        actions: [
          if (auth.canAssignTasks)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.pushNamed(context, '/tasks/create',
                      arguments: task);
                } else if (value == 'delete') {
                  _confirmDelete();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and status
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatusBadge.task(task.status),
                      const SizedBox(width: 8),
                      PriorityBadge(priority: task.priority),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Status change buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (task.status != 'todo')
                          _buildStatusButton(
                              'A Fazer', 'todo', AppTheme.statusDraft),
                        if (task.status != 'in_progress')
                          _buildStatusButton('Em Progresso', 'in_progress',
                              AppTheme.statusInProgress),
                        if (task.status != 'review')
                          _buildStatusButton(
                              'Revisao', 'review', AppTheme.statusReview),
                        if (task.status != 'done')
                          _buildStatusButton(
                              'Concluido', 'done', AppTheme.statusCompleted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const Text(
                      'Descricao',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.description!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Info cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.person_outlined,
                          'Responsavel',
                          task.assigneeName ?? 'Nao atribuido',
                        ),
                        const Divider(height: 20),
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          'Prazo',
                          task.dueDate != null
                              ? DateFormat('dd/MM/yyyy').format(task.dueDate!)
                              : 'Sem prazo',
                        ),
                        if (task.tags.isNotEmpty) ...[
                          const Divider(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.label_outlined,
                                  size: 18, color: AppTheme.textSecondary),
                              const SizedBox(width: 10),
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Tags',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: task.tags
                                      .map((tag) => Chip(
                                            label: Text(tag),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Hours tracker
                  HoursTracker(
                    estimatedHours: task.estimatedHours,
                    actualHours: task.actualHours,
                    editable: true,
                    onHoursChanged: (hours) {
                      context
                          .read<TaskProvider>()
                          .updateHours(task.id, hours);
                    },
                  ),
                  const SizedBox(height: 24),
                  // Comments
                  Row(
                    children: [
                      const Text(
                        'Comentarios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_comments.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _loadingComments
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : _comments.isEmpty
                          ? const Text(
                              'Nenhum comentario ainda',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Column(
                              children: _comments
                                  .map((c) => CommentWidget(
                                        comment: c,
                                        canDelete: c.userId == auth.user?.id,
                                        onDelete: () async {
                                          await _commentService
                                              .deleteComment(c.id);
                                          _loadComments();
                                        },
                                      ))
                                  .toList(),
                            ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          CommentInput(
            onSubmit: _addComment,
            isLoading: _sendingComment,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: () => _changeStatus(status),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Tarefa'),
        content:
            const Text('Tem certeza que deseja excluir esta tarefa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<TaskProvider>()
                  .deleteTask(_taskId!);
              if (success && mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
