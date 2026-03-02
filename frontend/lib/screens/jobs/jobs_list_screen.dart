import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/job_provider.dart';
import '../../models/job.dart';
import 'package:intl/intl.dart';

class JobsListScreen extends StatefulWidget {
  const JobsListScreen({super.key});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  String? _projectId;
  String? _statusFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args != _projectId) {
      _projectId = args;
      context.read<JobProvider>().loadJobs(_projectId!);
    }
  }

  List<Job> _filteredJobs(List<Job> jobs) {
    if (_statusFilter == null) return jobs;
    return jobs.where((j) => j.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final filtered = _filteredJobs(jobProvider.jobs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: jobProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () => jobProvider.loadJobs(_projectId!),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildJobCard(filtered[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _projectId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateJob(),
              icon: const Icon(Icons.add),
              label: const Text('Novo Job'),
            )
          : null,
    );
  }

  Widget _buildFilters() {
    final filters = [
      {'value': null, 'label': 'Todos'},
      {'value': 'pending', 'label': 'Pendente'},
      {'value': 'in_progress', 'label': 'Em Progresso'},
      {'value': 'review', 'label': 'Revisão'},
      {'value': 'done', 'label': 'Concluído'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _statusFilter == f['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _statusFilter = f['value'] as String?;
                });
              },
              selectedColor: AppTheme.primaryColor.withAlpha(25),
              checkmarkColor: AppTheme.primaryColor,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhum job encontrado',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie um novo job para este projeto',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    final statusColor = _getStatusColor(job.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(context, '/jobs/detail', arguments: job.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(job.type).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Job.typeLabel(job.type),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getTypeColor(job.type),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Job.statusLabel(job.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (job.dueDate != null)
                    Text(
                      DateFormat('dd/MM').format(job.dueDate!),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (job.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  job.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (job.assigneeName != null) ...[
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      job.assigneeName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.attachment, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${job.assetCount} arquivos',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.rate_review_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${job.reviewCount} revisões',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.grey;
      case 'in_progress': return const Color(0xFF2563EB);
      case 'review': return const Color(0xFFF59E0B);
      case 'approved': return const Color(0xFF16A34A);
      case 'done': return const Color(0xFF16A34A);
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

  void _showCreateJob() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'edit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Novo Job',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final job = await context.read<JobProvider>().createJob(
                      _projectId!,
                      {
                        'title': title,
                        'description': descController.text.trim(),
                        'type': selectedType,
                      },
                    );
                    if (job != null && ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Criar Job'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
