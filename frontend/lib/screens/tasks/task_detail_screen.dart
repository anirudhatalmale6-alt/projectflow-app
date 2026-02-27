import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../models/comment.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/comment_service.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/comment_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class TaskDetailScreen extends StatefulWidget {
  final String projectId;
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.projectId,
    required this.taskId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final CommentService _commentService = CommentService();
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  List<Comment> _comments = [];
  bool _loadingComments = false;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTask(widget.projectId, widget.taskId);
      _loadComments();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      _comments = await _commentService.getComments(widget.taskId);
    } catch (e) {
      // Silently fail -- comments are secondary
    }
    if (mounted) setState(() => _loadingComments = false);
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sendingComment = true);

    // Extract @mentions
    final mentionRegex = RegExp(r'@(\w+)');
    final mentions = mentionRegex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toList();

    try {
      final comment = await _commentService.addComment(
        widget.taskId,
        content,
        mentions: mentions,
      );
      _comments.add(comment);
      _commentController.clear();
      _commentFocusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    if (mounted) setState(() => _sendingComment = false);
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _commentService.deleteComment(widget.taskId, commentId);
      _comments.removeWhere((c) => c.id == commentId);
      if (mounted) setState(() {});
    } catch (e) {
      // ignore
    }
  }

  void _showStatusPicker(Task task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Status', style: AppTheme.headingSmall),
              const SizedBox(height: 16),
              ...TaskStatus.values.map((status) => ListTile(
                    leading: StatusBadge(status: status),
                    title: Text(status.label),
                    trailing: task.status == status
                        ? const Icon(Icons.check_rounded,
                            color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (task.status != status) {
                        context.read<TaskProvider>().updateTaskStatus(
                              widget.projectId,
                              widget.taskId,
                              status,
                            );
                      }
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().user;

    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final task = provider.selectedTask;

        if (provider.isLoading && task == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const LoadingWidget(message: 'Loading task...'),
          );
        }

        if (task == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorState(
              message: provider.errorMessage ?? 'Task not found',
              onRetry: () =>
                  provider.loadTask(widget.projectId, widget.taskId),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Task Details'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Task'),
                        content: const Text(
                            'Are you sure you want to delete this task?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppTheme.errorColor),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      final success = await provider.deleteTask(
                          widget.projectId, widget.taskId);
                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20,
                            color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('Delete Task',
                            style: TextStyle(color: AppTheme.errorColor)),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(task.title, style: AppTheme.headingMedium),
                      const SizedBox(height: 12),

                      // Status and priority row
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showStatusPicker(task),
                            child: StatusBadge(status: task.status),
                          ),
                          const SizedBox(width: 8),
                          PriorityBadge(priority: task.priority),
                          const Spacer(),
                          if (task.isOverdue)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 14, color: AppTheme.errorColor),
                                  SizedBox(width: 4),
                                  Text(
                                    'Overdue',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      if (task.description.isNotEmpty) ...[
                        Text('Description', style: AppTheme.labelMedium),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            task.description,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Details grid
                      _buildDetailSection(task),
                      const SizedBox(height: 20),

                      // Tags
                      if (task.tags.isNotEmpty) ...[
                        Text('Tags', style: AppTheme.labelMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: task.tags.map((tag) => Chip(
                                label: Text(tag),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Comments section
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Comments', style: AppTheme.headingSmall),
                          const SizedBox(width: 8),
                          if (_comments.isNotEmpty)
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

                      if (_loadingComments)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'No comments yet. Be the first to comment!',
                              style: AppTheme.bodySmall,
                            ),
                          ),
                        )
                      else
                        ..._comments.map((comment) => CommentWidget(
                              comment: comment,
                              isOwn: comment.author?.id == currentUser?.id,
                              onDelete: () => _deleteComment(comment.id),
                            )),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // Comment input
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Add a comment... (use @name to mention)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onFieldSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _sendingComment ? null : _addComment,
                        icon: _sendingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(Task task) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.person_outline_rounded,
            'Assignee',
            task.assignee?.name ?? 'Unassigned',
          ),
          const Divider(height: 20),
          _buildDetailRow(
            Icons.person_outlined,
            'Creator',
            task.creator?.name ?? 'Unknown',
          ),
          const Divider(height: 20),
          _buildDetailRow(
            Icons.calendar_today_rounded,
            'Due Date',
            task.dueDate != null
                ? DateFormat('EEEE, MMM d, yyyy').format(task.dueDate!)
                : 'No due date',
          ),
          const Divider(height: 20),
          _buildDetailRow(
            Icons.access_time_rounded,
            'Created',
            DateFormat('MMM d, yyyy').format(task.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textTertiary),
        const SizedBox(width: 10),
        Text(label, style: AppTheme.caption),
        const Spacer(),
        Text(
          value,
          style: AppTheme.labelMedium,
        ),
      ],
    );
  }
}
