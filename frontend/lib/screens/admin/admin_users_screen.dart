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
  bool _showPendingOnly = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      if (_showPendingOnly) {
        final data = await _api.get(ApiConfig.adminPendingUsers);
        final list = data['users'] ?? data['data'] ?? data;
        _users = (list as List).map((json) => User.fromJson(json)).toList();
      } else {
        final params = <String, String>{};
        if (_roleFilter != null) params['role'] = _roleFilter!;
        final data = await _api.get(ApiConfig.adminUsers, queryParams: params);
        final list = data['users'] ?? data['data'] ?? data;
        _users = (list as List).map((json) => User.fromJson(json)).toList();
      }
    } catch (_) {
      _users = [];
    }
    setState(() => _isLoading = false);
  }

  Future<void> _approveUser(User user) async {
    try {
      await _api.put(ApiConfig.adminApproveUser(user.id));
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} aprovado com sucesso'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao aprovar usuário'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar Usuário'),
        content: Text(
          'Tem certeza que deseja rejeitar "${user.name}"? O cadastro será removido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.put(ApiConfig.adminRejectUser(user.id));
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} rejeitado e removido'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao rejeitar usuário'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
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
      await _api.put('${ApiConfig.adminUserById(userId)}/role', body: {'role': role});
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo Usuário'),
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
                _buildPendingFilterChip(),
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
                                    Row(
                                      children: [
                                        RoleBadge(role: user.role),
                                        if (!user.isApproved) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.orange.shade300),
                                            ),
                                            child: const Text(
                                              'Pendente',
                                              style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: !user.isApproved
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                            tooltip: 'Aprovar',
                                            onPressed: () => _approveUser(user),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                                            tooltip: 'Rejeitar',
                                            onPressed: () => _rejectUser(user),
                                          ),
                                        ],
                                      )
                                    : PopupMenuButton<String>(
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

  void _showCreateUser() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'editor';

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
                'Novo Usuário',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outlined),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Cargo',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  DropdownMenuItem(value: 'manager', child: Text('Gerente')),
                  DropdownMenuItem(value: 'editor', child: Text('Editor')),
                  DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
                  DropdownMenuItem(value: 'client', child: Text('Cliente')),
                ],
                onChanged: (v) => setSheetState(() => selectedRole = v!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final password = passwordController.text;
                    if (name.isEmpty || email.isEmpty || password.length < 6) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Preencha todos os campos (senha mín. 6 caracteres)')),
                      );
                      return;
                    }
                    try {
                      await _api.post(ApiConfig.adminUsers, body: {
                        'name': name,
                        'email': email,
                        'password': password,
                        'role': selectedRole,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadUsers();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Usuário criado com sucesso'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Erro: $e'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Criar Usuário'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingFilterChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: const Text('Pendentes'),
        selected: _showPendingOnly,
        onSelected: (selected) {
          setState(() {
            _showPendingOnly = selected;
            if (selected) _roleFilter = null;
          });
          _loadUsers();
        },
        selectedColor: Colors.orange.withOpacity(0.2),
        checkmarkColor: Colors.deepOrange,
        avatar: _showPendingOnly ? null : const Icon(Icons.hourglass_top, size: 16, color: Colors.orange),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? role) {
    final isSelected = !_showPendingOnly && _roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _showPendingOnly = false;
            _roleFilter = selected ? role : null;
          });
          _loadUsers();
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }
}
