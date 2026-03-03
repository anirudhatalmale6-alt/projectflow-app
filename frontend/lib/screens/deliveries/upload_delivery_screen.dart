import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../providers/delivery_provider.dart';
import '../../services/api_service.dart';
import '../../models/delivery_job.dart';
import '../../widgets/loading_widget.dart';

class UploadDeliveryScreen extends StatefulWidget {
  const UploadDeliveryScreen({super.key});

  @override
  State<UploadDeliveryScreen> createState() => _UploadDeliveryScreenState();
}

class _UploadDeliveryScreenState extends State<UploadDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String _format = 'mp4';
  String? _projectId;
  PlatformFile? _selectedFile;
  bool _uploading = false;

  static const _formats = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'prproj',
    'aep',
    'drp',
    'mp3',
    'wav',
    'aac',
    'psd',
    'ai',
    'png',
    'jpg',
    'pdf',
    'zip',
    'outro',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && _projectId == null) {
      _projectId = arg;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        // Auto-detect format from extension
        final ext = _selectedFile!.extension?.toLowerCase() ?? '';
        if (_formats.contains(ext)) {
          _format = ext;
        }
      });
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projeto não encontrado.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final api = ApiService();
      final fields = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'format': _format,
      };

      Map<String, dynamic> data;
      if (_selectedFile != null && _selectedFile!.bytes != null) {
        data = await api.multipartPostBytes(
          ApiConfig.deliveriesByProject(_projectId!),
          fields: fields,
          fileBytes: _selectedFile!.bytes!,
          fileName: _selectedFile!.name,
          fileField: 'file',
        );
      } else {
        data = await api.post(
          ApiConfig.deliveriesByProject(_projectId!),
          body: {...fields, 'project_id': _projectId},
        );
      }

      if (mounted) {
        // Reload deliveries
        context.read<DeliveryProvider>().loadDeliveries(projectId: _projectId);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrega enviada com sucesso!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _uploading = false);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Entrega'),
      ),
      body: LoadingOverlay(
        isLoading: _uploading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File upload area
                InkWell(
                  onTap: _selectFile,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.secondaryColor.withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _selectedFile != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 40,
                                color: AppTheme.successColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFile!.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_selectedFile!.size > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _formatSize(_selectedFile!.size),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _selectFile,
                                child: const Text('Trocar arquivo'),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: AppTheme.secondaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Toque para selecionar arquivo',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Video, audio, imagem ou projeto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titulo da Entrega *',
                    hintText: 'Ex: Corte Final - Video Institucional',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o titulo da entrega';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descricao',
                    hintText: 'Descreva o que foi feito nesta versao...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                // Format selector
                DropdownButtonFormField<String>(
                  value: _format,
                  decoration: const InputDecoration(
                    labelText: 'Formato do Arquivo',
                    prefixIcon: Icon(Icons.file_present_outlined),
                  ),
                  items: _formats.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(f.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _format = value ?? 'mp4'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas para o revisor',
                    hintText: 'Observacoes sobre esta entrega...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _upload,
                    icon: _uploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file),
                    label: Text(
                      _uploading ? 'Enviando...' : 'Enviar Entrega',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
