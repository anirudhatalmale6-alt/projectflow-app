import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../services/api_service.dart';
import '../../services/comment_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/comment_widget.dart';
import '../../widgets/loading_widget.dart';

class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final CommentService _commentService = CommentService();
  final ApiService _api = ApiService();
  List<Comment> _comments = [];
  bool _loadingComments = false;
  bool _sendingComment = false;
  String? _deliveryId;
  final _reviewNotesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id != _deliveryId) {
      _deliveryId = id;
      context.read<DeliveryProvider>().loadDelivery(id);
      _loadComments();
    }
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (_deliveryId == null) return;
    setState(() => _loadingComments = true);
    try {
      _comments =
          await _commentService.getComments('delivery', _deliveryId!);
    } catch (_) {}
    setState(() => _loadingComments = false);
  }

  String? _getFileDownloadUrl(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) return null;
    return '${ApiConfig.baseUrl}/uploads/$fileUrl';
  }

  String? _resolveFormat(String? format, String? title) {
    if (format != null && format.isNotEmpty) return format.toLowerCase();
    if (title == null) return null;
    final dot = title.lastIndexOf('.');
    if (dot >= 0 && dot < title.length - 1) {
      return title.substring(dot + 1).toLowerCase();
    }
    return null;
  }

  bool _isPreviewable(String? format, [String? title]) {
    final f = _resolveFormat(format, title);
    if (f == null) return false;
    return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp',
            'pdf', 'txt', 'csv', 'doc', 'docx', 'xls', 'xlsx'].contains(f);
  }

  bool _isImage(String? format, [String? title]) {
    final f = _resolveFormat(format, title);
    if (f == null) return false;
    return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(f);
  }

  void _openFile(String? url) {
    if (url == null) return;
    launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
  }

  Future<void> _addComment(String content) async {
    if (_deliveryId == null) return;
    setState(() => _sendingComment = true);
    try {
      final comment = await _commentService.createComment(
          'delivery', _deliveryId!, content);
      setState(() => _comments.insert(0, comment));
    } catch (_) {}
    setState(() => _sendingComment = false);
  }

  void _showReviewDialog(String action) {
    final deliveryProvider = context.read<DeliveryProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          action == 'approve'
              ? 'Aprovar Entrega'
              : action == 'reject'
                  ? 'Rejeitar Entrega'
                  : 'Solicitar Revisao',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _reviewNotesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: (action == 'reject' || action == 'revision')
                    ? 'Comentarios (obrigatorio)'
                    : 'Comentarios (opcional)',
                hintText: 'Adicione um comentario...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reviewNotesController.clear();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _reviewNotesController.text.trim();
              // Reject and revision require comments
              if ((action == 'reject' || action == 'revision') && text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comentario obrigatorio para esta acao.')),
                );
                return;
              }
              Navigator.pop(ctx);
              final comments = text.isNotEmpty ? text : null;

              switch (action) {
                case 'approve':
                  await deliveryProvider.approveDelivery(_deliveryId!,
                      comments: comments);
                  break;
                case 'reject':
                  await deliveryProvider.rejectDelivery(_deliveryId!,
                      comments: comments);
                  break;
                case 'revision':
                  await deliveryProvider.requestRevision(_deliveryId!,
                      comments: comments);
                  break;
              }
              _reviewNotesController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve'
                  ? AppTheme.successColor
                  : action == 'reject'
                      ? AppTheme.errorColor
                      : AppTheme.warningColor,
            ),
            child: Text(
              action == 'approve'
                  ? 'Aprovar'
                  : action == 'reject'
                      ? 'Rejeitar'
                      : 'Solicitar Revisao',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryProvider = context.watch<DeliveryProvider>();
    final delivery = deliveryProvider.currentDelivery;
    final auth = context.watch<AuthProvider>();

    if (deliveryProvider.isLoading || delivery == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const LoadingWidget(message: 'Carregando entrega...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Entrega'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File preview area
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 200),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.secondaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: _isImage(delivery.format, delivery.title) && _getFileDownloadUrl(delivery.fileUrl) != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  _getFileDownloadUrl(delivery.fileUrl)!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _buildFilePlaceholder(delivery),
                                ),
                              )
                            : _buildFilePlaceholder(delivery),
                  ),
                  if (_getFileDownloadUrl(delivery.fileUrl) != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_isPreviewable(delivery.format, delivery.title))
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openFile(_getFileDownloadUrl(delivery.fileUrl)),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Visualizar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(color: AppTheme.primaryColor),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        if (_isPreviewable(delivery.format, delivery.title))
                          const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openFile(_getFileDownloadUrl(delivery.fileUrl)),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Baixar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Title and version
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          delivery.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          delivery.versionLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StatusBadge.delivery(delivery.status),
                  const SizedBox(height: 20),
                  // Description
                  if (delivery.description != null &&
                      delivery.description!.isNotEmpty) ...[
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
                      delivery.description!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Info card
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
                            'Enviado por',
                            delivery.uploadedByName ?? '—'),
                        const Divider(height: 20),
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          'Data',
                          delivery.createdAt != null
                              ? DateFormat('dd/MM/yyyy HH:mm')
                                  .format(delivery.createdAt!)
                              : '—',
                        ),
                        if (delivery.reviewedByName != null) ...[
                          const Divider(height: 20),
                          _buildInfoRow(Icons.rate_review_outlined,
                              'Revisado por', delivery.reviewedByName!),
                        ],
                        if (delivery.reviewNotes != null &&
                            delivery.reviewNotes!.isNotEmpty) ...[
                          const Divider(height: 20),
                          _buildInfoRow(Icons.notes_outlined,
                              'Notas da revisao', delivery.reviewNotes!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Status selector - dropdown style
                  const Text(
                    'Status da Entrega',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (auth.canApproveDeliveries && delivery.requiresApproval) ...[
                    // Clickable status options for admin/manager (only when approval required)
                    _buildStatusOption(
                      'approved',
                      'Aprovado',
                      Icons.check_circle,
                      AppTheme.successColor,
                      delivery.status == 'approved',
                      () => _showReviewDialog('approve'),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      'revision_requested',
                      'Sendo Alterado',
                      Icons.replay_circle_filled,
                      AppTheme.warningColor,
                      delivery.status == 'revision_requested',
                      () => _showReviewDialog('revision'),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      'in_review',
                      'Aguardando Aprovacao',
                      Icons.hourglass_top,
                      Colors.amber.shade700,
                      delivery.status == 'in_review' || delivery.status == 'uploaded',
                      null, // current status, no action
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      'rejected',
                      'Rejeitado',
                      Icons.cancel,
                      AppTheme.errorColor,
                      delivery.status == 'rejected',
                      () => _showReviewDialog('reject'),
                    ),
                  ] else ...[
                    // Read-only status display for non-admins
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(delivery.status).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(delivery.status).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(delivery.status),
                            color: _getStatusColor(delivery.status),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getStatusLabel(delivery.status),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(delivery.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                          color: AppTheme.secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_comments.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryColor,
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
                                  .map((c) => CommentWidget(comment: c))
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

  Widget _buildFilePlaceholder(delivery) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFormatIcon(delivery.format, delivery.title),
            size: 56,
            color: AppTheme.secondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            (_resolveFormat(delivery.format, delivery.title) ?? 'arquivo').toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            delivery.fileSizeFormatted,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
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

  Widget _buildStatusOption(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: isSelected ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade400, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? color : AppTheme.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.radio_button_checked, color: color, size: 22)
            else if (onTap != null)
              Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 22),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      case 'revision_requested':
        return AppTheme.warningColor;
      case 'in_review':
        return Colors.amber.shade700;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'revision_requested':
        return Icons.replay_circle_filled;
      case 'in_review':
        return Icons.hourglass_top;
      default:
        return Icons.upload_file;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Rejeitado';
      case 'revision_requested':
        return 'Revisao Solicitada';
      case 'in_review':
        return 'Aguardando Aprovacao';
      default:
        return 'Enviado';
    }
  }

  IconData _getFormatIcon(String? format, [String? title]) {
    final f = _resolveFormat(format, title);
    switch (f) {
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return Icons.videocam_outlined;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audiotrack_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'psd':
      case 'ai':
      case 'svg':
        return Icons.design_services_outlined;
      case 'prproj':
      case 'aep':
        return Icons.movie_creation_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
