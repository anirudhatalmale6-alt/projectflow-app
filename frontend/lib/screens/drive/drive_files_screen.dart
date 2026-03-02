import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../services/drive_service.dart';

class DriveFilesScreen extends StatefulWidget {
  const DriveFilesScreen({super.key});

  @override
  State<DriveFilesScreen> createState() => _DriveFilesScreenState();
}

class _DriveFilesScreenState extends State<DriveFilesScreen> {
  final DriveService _driveService = DriveService();

  String? _projectId;
  String? _projectName;
  DriveStatus? _status;
  List<DriveFile> _files = [];
  bool _isLoading = true;
  bool _isSettingUp = false;
  String? _error;
  String _currentFolder = 'root';

  static const _folderLabels = {
    'root': 'Raiz',
    'brutos': 'Brutos',
    'edicoes': 'Edições',
    'exports': 'Exports',
    'revisoes': 'Revisões',
    'documentos': 'Documentos',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['projectId'] != _projectId) {
      _projectId = args['projectId'] as String?;
      _projectName = args['projectName'] as String?;
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    if (_projectId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _status = await _driveService.getStatus(_projectId!);
      if (_status!.connected) {
        await _loadFiles();
      }
    } catch (e) {
      _error = 'Erro ao verificar status do Drive: $e';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadFiles() async {
    if (_projectId == null) return;
    try {
      _files = await _driveService.listFiles(_projectId!, folder: _currentFolder);
    } catch (e) {
      _error = 'Erro ao carregar arquivos: $e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _setupDrive() async {
    if (_projectId == null) return;
    setState(() => _isSettingUp = true);

    try {
      await _driveService.setupDrive(_projectId!);
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Drive conectado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _isSettingUp = false);
  }

  Future<void> _openFile(DriveFile file) async {
    if (file.webViewLink != null) {
      final uri = Uri.parse(file.webViewLink!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      try {
        final data = await _driveService.getFileLink(file.id);
        final link = data['file']?['webViewLink'] as String?;
        if (link != null) {
          final uri = Uri.parse(link);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir: $e')),
          );
        }
      }
    }
  }

  void _openDriveFolder() {
    if (_status?.driveFolderUrl != null) {
      final uri = Uri.parse(_status!.driveFolderUrl!);
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_projectName ?? 'Google Drive'),
        actions: [
          if (_status?.connected == true)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Abrir no Google Drive',
              onPressed: _openDriveFolder,
            ),
          if (_status?.connected == true)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFiles,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _status?.connected == true
                  ? _buildConnected()
                  : _buildNotConnected(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStatus,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConnected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Drive logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_to_drive,
                size: 40,
                color: Colors.green[600],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Conectar Google Drive',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _status?.userHasGoogle == true
                  ? 'Crie pastas automaticamente no seu Google Drive para organizar os arquivos do projeto.'
                  : 'Faça login com Google primeiro para conectar o Google Drive ao projeto.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 8),
            if (_status?.userHasGoogle == true) ...[
              Text(
                'Estrutura de pastas:\nBrutos / Edições / Exports / Revisões / Documentos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: _isSettingUp ? null : _setupDrive,
                  icon: _isSettingUp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_to_drive),
                  label: Text(_isSettingUp ? 'Conectando...' : 'Conectar Drive'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              Text(
                'Faça login com Google na tela de login para habilitar esta funcionalidade.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.orange[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnected() {
    return Column(
      children: [
        // Folder tabs
        _buildFolderTabs(),
        // File list
        Expanded(
          child: _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Pasta vazia',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Faça upload de arquivos pelo Google Drive',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _files.length,
                    itemBuilder: (ctx, index) => _buildFileCard(_files[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFolderTabs() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: _folderLabels.entries.map((entry) {
          final isActive = _currentFolder == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(entry.value, style: TextStyle(fontSize: 13,
                  color: isActive ? Colors.white : AppTheme.textPrimary)),
              selected: isActive,
              selectedColor: AppTheme.primaryColor,
              backgroundColor: Colors.grey[100],
              onSelected: (_) {
                setState(() => _currentFolder = entry.key);
                _loadFiles();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFileCard(DriveFile file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _getFileColor(file).withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getFileIcon(file), color: _getFileColor(file), size: 22),
        ),
        title: Text(
          file.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (file.sizeFormatted.isNotEmpty)
              Text(file.sizeFormatted,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (file.modifiedTime != null) ...[
              if (file.sizeFormatted.isNotEmpty)
                Text(' · ', style: TextStyle(color: Colors.grey[400])),
              Text(
                _formatDate(file.modifiedTime!),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          color: AppTheme.primaryColor,
          onPressed: () => _openFile(file),
        ),
        onTap: () => _openFile(file),
      ),
    );
  }

  IconData _getFileIcon(DriveFile file) {
    if (file.isFolder) return Icons.folder;
    if (file.isVideo) return Icons.videocam;
    if (file.isImage) return Icons.image;
    if (file.isDocument) return Icons.description;
    final name = file.name.toLowerCase();
    if (name.endsWith('.zip') || name.endsWith('.rar')) return Icons.archive;
    if (name.endsWith('.psd') || name.endsWith('.ai')) return Icons.brush;
    if (name.endsWith('.prproj') || name.endsWith('.aep')) return Icons.movie_creation;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(DriveFile file) {
    if (file.isFolder) return Colors.amber;
    if (file.isVideo) return Colors.blue;
    if (file.isImage) return Colors.green;
    if (file.isDocument) return Colors.orange;
    return Colors.grey;
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd/MM/yy HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
