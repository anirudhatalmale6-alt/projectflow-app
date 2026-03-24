import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_widget.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;
  int _total = 0;
  int _offset = 0;
  static const int _limit = 30;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _offset = 0;
      });
    }

    try {
      final data = await _api.get(
        '${ApiConfig.adminAuditLog}?limit=$_limit&offset=$_offset',
      );
      setState(() {
        if (loadMore) {
          _logs.addAll(data['audit_log'] ?? []);
        } else {
          _logs = data['audit_log'] ?? [];
        }
        _total = data['total'] ?? 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar log: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'login':
        return 'Login';
      case 'create':
        return 'Criou';
      case 'update':
        return 'Atualizou';
      case 'delete':
        return 'Excluiu';
      case 'soft_delete':
        return 'Moveu p/ lixeira';
      case 'restore':
        return 'Restaurou';
      case 'permanent_delete':
        return 'Excluiu permanente';
      case 'approve':
        return 'Aprovou';
      case 'reject':
        return 'Rejeitou';
      case 'upload':
        return 'Enviou';
      default:
        return action;
    }
  }

  String _getEntityLabel(String entityType) {
    switch (entityType) {
      case 'user':
        return 'Usuario';
      case 'project':
        return 'Projeto';
      case 'task':
        return 'Tarefa';
      case 'delivery':
        return 'Entrega';
      case 'client':
        return 'Cliente';
      case 'comment':
        return 'Comentario';
      default:
        return entityType;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'login':
        return Icons.login;
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
      case 'soft_delete':
      case 'permanent_delete':
        return Icons.delete_outline;
      case 'restore':
        return Icons.restore;
      case 'approve':
        return Icons.check_circle_outline;
      case 'reject':
        return Icons.cancel_outlined;
      case 'upload':
        return Icons.upload_outlined;
      default:
        return Icons.history;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'login':
        return AppTheme.primaryColor;
      case 'create':
        return AppTheme.successColor;
      case 'update':
        return AppTheme.secondaryColor;
      case 'delete':
      case 'soft_delete':
      case 'permanent_delete':
        return AppTheme.errorColor;
      case 'restore':
        return AppTheme.warningColor;
      case 'approve':
        return AppTheme.successColor;
      case 'reject':
        return AppTheme.errorColor;
      case 'upload':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log de Auditoria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Carregando log...')
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum registro encontrado',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length + (_logs.length < _total ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _logs.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                _offset += _limit;
                                _loadLogs(loadMore: true);
                              },
                              child: const Text('Carregar mais'),
                            ),
                          ),
                        );
                      }

                      final log = _logs[index];
                      final action = log['action'] ?? '';
                      final entityType = log['entity_type'] ?? '';
                      final userName = log['user_name'] ?? 'Sistema';
                      final createdAt = log['created_at'] != null
                          ? DateTime.tryParse(log['created_at'])
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getActionColor(action).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getActionIcon(action),
                              color: _getActionColor(action),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '$userName - ${_getActionLabel(action)} ${_getEntityLabel(entityType)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            createdAt != null
                                ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                                : '',
                            style: const TextStyle(fontSize: 11),
                          ),
                          dense: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
