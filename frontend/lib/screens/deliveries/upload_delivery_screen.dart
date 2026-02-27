import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/delivery_provider.dart';
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
  String? _selectedFilePath;
  String? _selectedFileName;

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

  void _selectFile() {
    // File picker placeholder
    setState(() {
      _selectedFileName = 'video_final_v1.mp4';
      _selectedFilePath = '/tmp/video_final_v1.mp4';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selecao de arquivo (placeholder) - Arquivo simulado selecionado'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<DeliveryProvider>();
    final data = {
      if (_projectId != null) 'project_id': _projectId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'format': _format,
      'status': 'uploaded',
    };

    final delivery = await provider.createDelivery(
      data,
      filePath: _selectedFilePath,
    );

    if (delivery != null && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrega enviada com sucesso!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryProvider = context.watch<DeliveryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Entrega'),
      ),
      body: LoadingOverlay(
        isLoading: deliveryProvider.isLoading,
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
                    child: _selectedFileName != null
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
                                _selectedFileName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
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
                    onPressed: _upload,
                    icon: const Icon(Icons.upload_file),
                    label: const Text(
                      'Enviar Entrega',
                      style: TextStyle(fontSize: 16),
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
