import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _api = ApiService();
  List<User> _users = [];
  bool _isLoading = true;
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final params = <String, String>{};
      if (_roleFilter != null) params['role'] = _roleFilter!;
      final data = await _api.get(ApiConfig.adminUsers, queryParams: params);
      final list = data['users'] ?? data['data'] ?? data;
      _users = (list as List).map((json) => User.fromJson(json)).toList();
    } catch (_) {
      _users = [];
    }
    setState(() => _isLoading = false);
  }

  void _showRoleDialog(User user) {
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Alterar Cargo de ${user.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRoleOption(
                    'admin', 'Administrador', selectedRole, setDialogState,
                    (v) => selectedRole = v),
                _buildRoleOption(
                    'manager', 'Gerente', selectedRole, setDialogState,
                    (v) => selectedRole = v),
                _buildRoleOption(
                    'editor', 'Editor', selectedRole, setDialogState,
                    (v) => selectedRole = v),
                _buildRoleOption(
                    'freelancer', 'Freelancer', selectedRole, setDialogState,
                    (v) => selectedRole = v),
                _buildRoleOption(
                    'client', 'Cliente', selectedRole, setDialogState,
                    (v) => selectedRole = v),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _updateUserRole(user.id, selectedRole);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleOption(
    String value,
    String label,
    String groupValue,
    StateSetter setDialogState,
    Function(String) onChanged,
  ) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        setDialogState(() => onChanged(v!));
      },
      title: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.getRoleColor(value),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _updateUserRole(String userId, String role) async {
    try {
      await _api.put(ApiConfig.adminUserById(userId), body: {'role': role});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cargo atualizado com sucesso'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar cargo'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _confirmDelete(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Usuario'),
        content: Text(
          'Tem certeza que deseja excluir "${user.name}"? Esta acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.delete(ApiConfig.adminUserById(user.id));
                _loadUsers();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuarios'),
      ),
      body: Column(
        children: [
          // Role filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Todos', null),
                _buildFilterChip('Admin', 'admin'),
                _buildFilterChip('Gerente', 'manager'),
                _buildFilterChip('Editor', 'editor'),
                _buildFilterChip('Freelancer', 'freelancer'),
                _buildFilterChip('Cliente', 'client'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Carregando usuarios...')
                : _users.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Nenhum usuario encontrado',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.getRoleColor(user.role),
                                  child: Text(
                                    user.initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.email,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    RoleBadge(role: user.role),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'role') {
                                      _showRoleDialog(user);
                                    } else if (value == 'delete') {
                                      _confirmDelete(user);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'role',
                                      child: Row(
                                        children: [
                                          Icon(Icons.badge_outlined,
                                              size: 20),
                                          SizedBox(width: 8),
                                          Text('Alterar Cargo'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outlined,
                                              size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Excluir',
                                              style: TextStyle(
                                                  color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? role) {
    final isSelected = _roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _roleFilter = selected ? role : null);
          _loadUsers();
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }
}
