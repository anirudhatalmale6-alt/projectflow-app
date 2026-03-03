import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get(ApiConfig.trash);
      setState(() => _items = List<dynamic>.from(data['items'] ?? []));
    } catch (_) {
      setState(() => _items = []);
    }
    setState(() => _loading = false);
  }

  String _itemType(dynamic item) {
    return item['_type']?.toString() ?? 'delivery';
  }

  Future<void> _restoreItem(String id, String type) async {
    try {
      await _api.post('${ApiConfig.trashRestore(id)}?type=$type', body: {});
      await _loadTrash();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item restaurado com sucesso!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _permanentDelete(String id, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir permanentemente'),
        content: const Text(
            'Esta ação não pode ser desfeita. O item será excluído permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete('${ApiConfig.trashDelete(id)}?type=$type');
      await _loadTrash();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item excluído permanentemente'),
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
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esvaziar lixeira'),
        content: Text(
            'Excluir permanentemente ${_items.length} item(ns)? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Esvaziar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete(ApiConfig.trash);
      await _loadTrash();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lixeira esvaziada'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (_) {}
  }

  String _daysLeft(String? deletedAt) {
    if (deletedAt == null) return '';
    final deleted = DateTime.tryParse(deletedAt);
    if (deleted == null) return '';
    final expiry = deleted.add(const Duration(days: 10));
    final remaining = expiry.difference(DateTime.now()).inDays;
    if (remaining <= 0) return 'Expira hoje';
    return '$remaining dia(s) restante(s)';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'project':
        return Icons.folder_outlined;
      case 'task':
        return Icons.task_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'project':
        return 'Projeto';
      case 'task':
        return 'Tarefa';
      default:
        return 'Arquivo';
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'project':
        return Colors.blue;
      case 'task':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lixeira'),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _emptyTrash,
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Esvaziar',
                  style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Lixeira vazia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Itens excluídos serão removidos após 10 dias',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTrash,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final type = _itemType(item);
                      final title = item['title'] ?? item['name'] ?? 'Sem título';
                      final subtitle = type == 'project'
                          ? item['created_by_name'] ?? ''
                          : item['project_name'] ?? '';
                      final deletedAt = item['deleted_at'];
                      final id = item['id']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _typeColor(type).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_typeIcon(type),
                                    color: _typeColor(type), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _typeColor(type)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _typeLabel(type),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _typeColor(type),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$subtitle • ${_daysLeft(deletedAt)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restore,
                                    color: AppTheme.successColor),
                                tooltip: 'Restaurar',
                                onPressed: () => _restoreItem(id, type),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_forever, color: Colors.red),
                                tooltip: 'Excluir permanentemente',
                                onPressed: () => _permanentDelete(id, type),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
