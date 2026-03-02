import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../services/api_service.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  String? _jobId;
  Job? _job;
  bool _loading = true;
  List<dynamic> _assets = [];
  List<dynamic> _reviews = [];
  bool _loadingAssets = false;
  bool _loadingReviews = false;
  bool _uploading = false;

  static const List<Map<String, dynamic>> _pipelineStages = [
    {'key': 'pending', 'label': 'Pendente', 'icon': Icons.hourglass_empty},
    {'key': 'in_progress', 'label': 'Em Progresso', 'icon': Icons.play_circle_outline},
    {'key': 'in_review', 'label': 'Em Revisão', 'icon': Icons.rate_review_outlined},
    {'key': 'revision', 'label': 'Revisão', 'icon': Icons.replay},
    {'key': 'approved', 'label': 'Aprovado', 'icon': Icons.check_circle_outline},
    {'key': 'delivered', 'label': 'Entregue', 'icon': Icons.local_shipping_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id != _jobId) {
      _jobId = id;
      _loadJob();
    }
  }

  Future<void> _loadJob() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get(ApiConfig.jobById(_jobId!));
      setState(() {
        _job = Job.fromJson(data['job']);
        _loading = false;
      });
      _loadAssets();
      _loadReviews();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar job: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _loadAssets() async {
    if (_jobId == null) return;
    setState(() => _loadingAssets = true);
    try {
      final data = await _api.get(ApiConfig.assetsByJob(_jobId!));
      setState(() => _assets = List<dynamic>.from(data['assets'] ?? []));
    } catch (_) {}
    setState(() => _loadingAssets = false);
  }

  Future<void> _loadReviews() async {
    if (_jobId == null) return;
    setState(() => _loadingReviews = true);
    try {
      final data = await _api.get(ApiConfig.reviewsByJob(_jobId!));
      setState(() => _reviews = List<dynamic>.from(data['reviews'] ?? []));
    } catch (_) {}
    setState(() => _loadingReviews = false);
  }

  Future<void> _changeStatus(String newStatus) async {
    try {
      final data = await _api.put(ApiConfig.jobById(_jobId!), body: {'status': newStatus});
      setState(() => _job = Job.fromJson(data['job']));
      if (_job != null) {
        context.read<JobProvider>().loadJobs(_job!.projectId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _uploadAsset() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      await _api.multipartPostBytes(
        ApiConfig.assetsByJob(_jobId!),
        fields: {'type': 'raw'},
        fileBytes: file.bytes!,
        fileName: file.name,
        fileField: 'file',
      );
      await _loadAssets();
      await _loadJob();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset enviado!'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
    setState(() => _uploading = false);
  }

  Future<void> _deleteJob() async {
    try {
      await _api.delete(ApiConfig.jobById(_jobId!));
      if (_job != null) {
        context.read<JobProvider>().loadJobs(_job!.projectId);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _createReview() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Revisão'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Resumo da revisão',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _api.post(ApiConfig.reviewsByJob(_jobId!), body: {'summary': result});
        await _loadReviews();
        await _loadJob();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.grey;
      case 'in_progress': return const Color(0xFF2563EB);
      case 'in_review': return const Color(0xFFF59E0B);
      case 'revision': return Colors.orange;
      case 'approved': return const Color(0xFF16A34A);
      case 'delivered': return const Color(0xFF059669);
      default: return Colors.grey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'edit': return const Color(0xFF2563EB);
      case 'color_grade': return const Color(0xFF7C3AED);
      case 'motion_graphics': return const Color(0xFFEC4899);
      case 'audio_mix': return const Color(0xFF14B8A6);
      case 'subtitles': return const Color(0xFFF59E0B);
      case 'vfx': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low': return Colors.grey;
      case 'medium': return const Color(0xFF2563EB);
      case 'high': return const Color(0xFFF59E0B);
      case 'urgent': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4': case 'mov': case 'avi': case 'mkv': case 'webm':
        return Icons.video_file;
      case 'mp3': case 'wav': case 'aac':
        return Icons.audio_file;
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip': case 'rar': case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes do Job')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final job = _job!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(job.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (auth.canAssignTasks)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _showEditJob();
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Editar'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Excluir', style: TextStyle(color: Colors.red)),
                ])),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          _buildPipeline(job),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textTertiary,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              const Tab(text: 'Detalhes', icon: Icon(Icons.info_outline, size: 18)),
              Tab(
                icon: Badge(
                  label: Text('${_assets.length}', style: const TextStyle(fontSize: 10)),
                  isLabelVisible: _assets.isNotEmpty,
                  child: const Icon(Icons.attachment, size: 18),
                ),
                text: 'Assets',
              ),
              Tab(
                icon: Badge(
                  label: Text('${_reviews.length}', style: const TextStyle(fontSize: 10)),
                  isLabelVisible: _reviews.isNotEmpty,
                  child: const Icon(Icons.rate_review_outlined, size: 18),
                ),
                text: 'Revisões',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(job),
                _buildAssetsTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipeline(Job job) {
    final currentIndex = _pipelineStages.indexWhere((s) => s['key'] == job.status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_pipelineStages.length, (index) {
            final stage = _pipelineStages[index];
            final isActive = index == currentIndex;
            final isPast = index < currentIndex;
            final color = isActive
                ? _getStatusColor(stage['key'])
                : isPast
                    ? _getStatusColor(stage['key']).withOpacity(0.5)
                    : Colors.grey[300]!;

            return GestureDetector(
              onTap: () => _changeStatus(stage['key']),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isActive ? color : color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: isActive ? 2.5 : 1.5),
                        ),
                        child: Icon(
                          isPast ? Icons.check : stage['icon'] as IconData,
                          color: isActive ? Colors.white : color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          stage['label'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? color : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (index < _pipelineStages.length - 1)
                    Container(
                      width: 20,
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isPast ? color : Colors.grey[300],
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDetailsTab(Job job) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBadge(Job.typeLabel(job.type), _getTypeColor(job.type)),
              const SizedBox(width: 8),
              _buildBadge(Job.priorityLabel(job.priority), _getPriorityColor(job.priority)),
              const SizedBox(width: 8),
              _buildBadge(Job.statusLabel(job.status), _getStatusColor(job.status)),
            ],
          ),
          const SizedBox(height: 20),
          if (job.description != null && job.description!.isNotEmpty) ...[
            const Text('Descrição', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(job.description!, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.5)),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_outlined, 'Responsável', job.assigneeName ?? 'Não atribuído'),
                const Divider(height: 20),
                _buildInfoRow(Icons.calendar_today_outlined, 'Prazo',
                    job.dueDate != null ? DateFormat('dd/MM/yyyy').format(job.dueDate!) : 'Sem prazo'),
                const Divider(height: 20),
                _buildInfoRow(Icons.person_add_outlined, 'Criado por', job.createdByName ?? '-'),
                const Divider(height: 20),
                _buildInfoRow(Icons.access_time, 'Criado em',
                    job.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(job.createdAt!.toLocal()) : '-'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Ações Rápidas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pipelineStages
                .where((s) => s['key'] != job.status)
                .map((s) => OutlinedButton.icon(
                      onPressed: () => _changeStatus(s['key'] as String),
                      icon: Icon(s['icon'] as IconData, size: 16),
                      label: Text(s['label'] as String, style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _getStatusColor(s['key'] as String),
                        side: BorderSide(color: _getStatusColor(s['key'] as String)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: _uploading ? null : _uploadAsset,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _uploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    _uploading ? 'Enviando...' : 'Enviar Asset',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingAssets
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _assets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Nenhum asset ainda', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _assets.length,
                      itemBuilder: (ctx, index) => _buildAssetCard(_assets[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final name = asset['name'] ?? 'Sem nome';
    final type = asset['type'] ?? 'raw';
    final fileSize = asset['file_size'];
    final uploadedBy = asset['uploaded_by_name'] ?? '';
    final createdAt = asset['created_at'] != null
        ? DateFormat('dd/MM HH:mm').format(DateTime.parse(asset['created_at']).toLocal())
        : '';
    final versionCount = asset['version_count'] ?? 0;

    const typeLabels = {
      'raw': 'Bruto', 'project_file': 'Projeto', 'proxy': 'Proxy',
      'export': 'Export', 'final_delivery': 'Final', 'document': 'Doc', 'other': 'Outro',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getFileIcon(name), color: AppTheme.primaryColor, size: 22),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            _buildMiniTag(typeLabels[type] ?? type, AppTheme.primaryColor),
            if (fileSize != null) ...[
              const SizedBox(width: 6),
              Text(_formatFileSize(fileSize), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
            if (versionCount > 0) ...[
              const SizedBox(width: 6),
              Text('v$versionCount', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ],
        ),
        trailing: Text('$uploadedBy\n$createdAt',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        dense: true,
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _createReview,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Nova Revisão'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingReviews
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _reviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Nenhuma revisão ainda', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _reviews.length,
                      itemBuilder: (ctx, index) => _buildReviewCard(_reviews[index]),
                    ),
        ),
      ],
    );
  }

  String? _findFirstVideoUrl() {
    const videoExts = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];
    for (final asset in _assets) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      final fileUrl = asset['file_url'] as String?;
      if (fileUrl != null && videoExts.any((ext) => name.endsWith(ext))) {
        return fileUrl;
      }
    }
    // Fallback: return first asset's file_url if any
    if (_assets.isNotEmpty) {
      return _assets.first['file_url'] as String?;
    }
    return null;
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final status = review['status'] ?? 'pending';
    final summary = review['summary'] ?? 'Sem resumo';
    final reviewerName = review['reviewer_name'] ?? '';
    final commentCount = review['comment_count'] ?? 0;
    final createdAt = review['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(review['created_at']).toLocal())
        : '';

    const statusColors = {
      'pending': Colors.grey,
      'approved': Color(0xFF16A34A),
      'rejected': Color(0xFFEF4444),
      'revision_requested': Colors.orange,
    };
    const statusLabels = {
      'pending': 'Pendente', 'in_progress': 'Em Análise',
      'approved': 'Aprovado', 'rejected': 'Rejeitado',
      'revision_requested': 'Revisão Solicitada',
    };

    final color = statusColors[status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.pushNamed(context, '/reviews/player', arguments: {
            'reviewId': review['id']?.toString() ?? '',
            'jobId': _jobId,
            'videoUrl': _findFirstVideoUrl(),
            'assetName': _job?.title ?? 'Review',
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(Icons.person, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reviewerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(createdAt, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  _buildMiniTag(statusLabels[status] ?? status, color),
                ],
              ),
              const SizedBox(height: 10),
              Text(summary, style: const TextStyle(fontSize: 14, height: 1.4)),
              Row(
                children: [
                  if (commentCount > 0) ...[
                    Icon(Icons.comment_outlined, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('$commentCount comentários', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  Icon(Icons.play_circle_outline, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Text('Abrir Player', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Expanded(flex: 3, child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
      ],
    );
  }

  void _showEditJob() {
    if (_job == null) return;
    final titleCtrl = TextEditingController(text: _job!.title);
    final descCtrl = TextEditingController(text: _job!.description ?? '');
    String selectedType = _job!.type;
    String selectedPriority = _job!.priority;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Editar Job', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'edit', child: Text('Edição')),
                      DropdownMenuItem(value: 'color_grade', child: Text('Cor')),
                      DropdownMenuItem(value: 'motion_graphics', child: Text('Motion')),
                      DropdownMenuItem(value: 'audio_mix', child: Text('Áudio')),
                      DropdownMenuItem(value: 'subtitles', child: Text('Legendas')),
                      DropdownMenuItem(value: 'vfx', child: Text('VFX')),
                      DropdownMenuItem(value: 'other', child: Text('Outro')),
                    ],
                    onChanged: (v) => setSheetState(() => selectedType = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Baixa')),
                      DropdownMenuItem(value: 'medium', child: Text('Média')),
                      DropdownMenuItem(value: 'high', child: Text('Alta')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                    ],
                    onChanged: (v) => setSheetState(() => selectedPriority = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final data = await _api.put(ApiConfig.jobById(_jobId!), body: {
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'type': selectedType,
                        'priority': selectedPriority,
                      });
                      setState(() => _job = Job.fromJson(data['job']));
                      if (_job != null) context.read<JobProvider>().loadJobs(_job!.projectId);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.errorColor),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Job'),
        content: const Text('Tem certeza que deseja excluir este job?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _deleteJob(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
