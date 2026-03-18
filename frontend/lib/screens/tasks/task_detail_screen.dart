import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/api_service.dart';
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
  final ApiService _api = ApiService();
  List<Comment> _comments = [];
  List<dynamic> _deliveries = [];
  bool _loadingComments = false;
  bool _loadingDeliveries = false;
  bool _sendingComment = false;
  bool _uploading = false;
  String? _taskId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id != _taskId) {
      _taskId = id;
      context.read<TaskProvider>().loadTask(id);
      _loadComments();
      _loadDeliveries();
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

  Future<void> _loadDeliveries() async {
    if (_taskId == null) return;
    setState(() => _loadingDeliveries = true);
    try {
      final data = await _api.get(ApiConfig.deliveriesByTask(_taskId!));
      final list = data['deliveries'] ?? data['data'] ?? [];
      setState(() => _deliveries = List<dynamic>.from(list));
    } catch (_) {
      setState(() => _deliveries = []);
    }
    setState(() => _loadingDeliveries = false);
  }

  Future<void> _uploadDelivery() async {
    final task = context.read<TaskProvider>().currentTask;
    if (task == null || _taskId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    // Ask if this file needs approval
    final requiresApproval = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tipo de arquivo'),
        content: const Text(
          'Este arquivo precisa de aprovação do gerente/administrador?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não, apenas anexo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Sim, enviar para aprovação'),
          ),
        ],
      ),
    );

    if (requiresApproval == null) return; // dismissed

    setState(() => _uploading = true);

    try {
      await _api.multipartPostBytes(
        ApiConfig.deliveriesByTask(_taskId!),
        fields: {
          'title': file.name,
          'requires_approval': requiresApproval ? 'true' : 'false',
        },
        fileBytes: file.bytes!,
        fileName: file.name,
        fileField: 'file',
      );
      await _loadDeliveries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(requiresApproval
                ? 'Arquivo enviado para aprovação!'
                : 'Arquivo anexado com sucesso!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _uploading = false);
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

  bool _canDeleteDelivery(Map<String, dynamic> d, AuthProvider auth) {
    final isApproved = d['status'] == 'approved';
    final isUploader = d['uploaded_by'] == auth.user?.id;
    final isManagerOrAdmin = auth.canManageProjects;
    // Approved files: only admin/manager can delete
    if (isApproved) return isManagerOrAdmin;
    // Non-approved files: uploader or admin/manager
    return isUploader || isManagerOrAdmin;
  }

  String? _extractFormat(String? fileName) {
    if (fileName == null) return null;
    final dot = fileName.lastIndexOf('.');
    if (dot >= 0 && dot < fileName.length - 1) {
      return fileName.substring(dot + 1).toLowerCase();
    }
    return null;
  }

  bool _isPreviewable(String? ext) {
    if (ext == null) return false;
    return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp',
            'pdf', 'txt', 'csv', 'doc', 'docx', 'xls', 'xlsx'].contains(ext);
  }

  void _openDeliveryFile(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum arquivo anexado a esta entrega.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // Construct URL directly (no async API call) to avoid browser popup blocker
    final url = '${ApiConfig.baseUrl}/uploads/$fileUrl';
    launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
  }

  Future<void> _deleteDelivery(String deliveryId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir arquivo'),
        content: Text(
            'Mover "$title" para a lixeira? Você pode restaurar em até 5 dias.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.delete(ApiConfig.deliveryById(deliveryId));
      await _loadDeliveries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arquivo movido para a lixeira'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'uploaded':
        return 'Enviado';
      case 'in_review':
        return 'Em Revisão';
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Rejeitado';
      case 'revision_requested':
        return 'Revisão Solicitada';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      case 'in_review':
        return AppTheme.warningColor;
      case 'uploaded':
        return AppTheme.primaryColor;
      case 'revision_requested':
        return Colors.orange;
      default:
        return AppTheme.textTertiary;
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'psd':
      case 'ai':
      case 'svg':
        return Icons.design_services;
      case 'prproj':
      case 'aep':
      case 'drp':
        return Icons.movie_creation;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final task = taskProvider.currentTask;
    final auth = context.watch<AuthProvider>();

    if (taskProvider.loadingTask) {
      return Scaffold(
        appBar: AppBar(),
        body: const LoadingWidget(message: 'Carregando tarefa...'),
      );
    }

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                taskProvider.errorMessage ?? 'Tarefa não encontrada',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (_taskId != null) {
                    context.read<TaskProvider>().loadTask(_taskId!);
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
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
                        // Multiple assignees display
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.people_outlined, size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 10),
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'Responsáveis',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: task.assignees.isNotEmpty
                                  ? Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: task.assignees.map((a) {
                                        return Chip(
                                          avatar: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: AppTheme.primaryColor,
                                            backgroundImage: a.avatarUrl != null && a.avatarUrl!.isNotEmpty
                                                ? NetworkImage(
                                                    a.avatarUrl!.startsWith('http')
                                                        ? a.avatarUrl!
                                                        : '${ApiConfig.baseUrl}/uploads/${a.avatarUrl}',
                                                  )
                                                : null,
                                            child: a.avatarUrl == null || a.avatarUrl!.isEmpty
                                                ? Text(
                                                    a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                                                    style: const TextStyle(fontSize: 10, color: Colors.white),
                                                  )
                                                : null,
                                          ),
                                          label: Text(a.name, style: const TextStyle(fontSize: 12)),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    )
                                  : Text(
                                      task.assigneeName ?? 'Não atribuído',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                            ),
                          ],
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

                  // ============ DELIVERIES SECTION ============
                  Row(
                    children: [
                      const Icon(Icons.upload_file,
                          size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Entregas / Arquivos',
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
                          '${_deliveries.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _uploading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: AppTheme.primaryColor),
                              tooltip: 'Enviar arquivo',
                              onPressed: _uploadDelivery,
                            ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Upload button area
                  InkWell(
                    onTap: _uploading ? null : _uploadDelivery,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _uploading
                                ? Icons.hourglass_top
                                : Icons.cloud_upload_outlined,
                            size: 36,
                            color: AppTheme.primaryColor.withOpacity(0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _uploading
                                ? 'Enviando arquivo...'
                                : 'Toque para enviar arquivo',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.primaryColor.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Videos, imagens, PDFs, arquivos de projeto...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Delivery list
                  _loadingDeliveries
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _deliveries.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Nenhuma entrega ainda',
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : Column(
                              children: _deliveries.map((d) {
                                final title = d['title'] ?? 'Sem título';
                                final status = d['status'] ?? 'pending';
                                final fileSize = d['file_size'];
                                final uploadedBy =
                                    d['uploaded_by_name'] ?? 'Desconhecido';
                                final createdAt = d['created_at'] != null
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(
                                        DateTime.parse(d['created_at'])
                                            .toLocal())
                                    : '';
                                final version = d['version'] ?? 1;
                                final needsApproval = d['requires_approval'] == true;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/deliveries/detail',
                                      arguments: d['id']?.toString(),
                                    ),
                                    child: ListTile(
                                    leading: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _getFileIcon(title),
                                        color: _getStatusColor(status),
                                        size: 22,
                                      ),
                                    ),
                                    title: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getStatusLabel(status),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      _getStatusColor(status),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'v$version',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textTertiary,
                                              ),
                                            ),
                                            if (fileSize != null) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatFileSize(fileSize),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppTheme.textTertiary,
                                                ),
                                              ),
                                            ],
                                            if (needsApproval) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.approval, size: 10, color: Colors.orange),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      'Aprovação',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.orange,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$uploadedBy • $createdAt',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    dense: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _openDeliveryFile(d['file_url']?.toString()),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              _isPreviewable(_extractFormat(title))
                                                  ? Icons.visibility_outlined
                                                  : Icons.download_outlined,
                                              size: 20,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        if (_canDeleteDelivery(d, context.read<AuthProvider>()))
                                          InkWell(
                                            onTap: () => _deleteDelivery(
                                              d['id']?.toString() ?? '',
                                              title,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(Icons.delete_outline,
                                                  size: 18, color: Colors.red[300]),
                                            ),
                                          ),
                                        Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                                      ],
                                    ),
                                  ),
                                  ),
                                );
                              }).toList(),
                            ),
                  const SizedBox(height: 24),

                  // ============ COMMENTS SECTION ============
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

  void _downloadDeliveryFile(String? fileUrl) {
    _openDeliveryFile(fileUrl);
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
