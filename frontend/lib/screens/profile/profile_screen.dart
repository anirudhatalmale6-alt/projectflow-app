import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/role_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingName = false;
  bool _isEditingPhone = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              tooltip: 'Painel Admin',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            RoleBadge(role: user.role, fontSize: 13),
            const SizedBox(height: 32),
            // Info cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildInfoCard(
                    icon: Icons.person_outlined,
                    label: 'Nome',
                    value: user.name,
                    isEditing: _isEditingName,
                    controller: _nameController,
                    onEdit: () {
                      _nameController.text = user.name;
                      setState(() => _isEditingName = true);
                    },
                    onSave: () async {
                      if (_nameController.text.trim().isNotEmpty) {
                        await auth.updateProfile(
                            {'name': _nameController.text.trim()});
                      }
                      setState(() => _isEditingName = false);
                    },
                    onCancel: () =>
                        setState(() => _isEditingName = false),
                  ),
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    label: 'E-mail',
                    value: user.email,
                  ),
                  _buildInfoCard(
                    icon: Icons.phone_outlined,
                    label: 'Telefone',
                    value: user.phone ?? 'Não informado',
                    isEditing: _isEditingPhone,
                    controller: _phoneController,
                    onEdit: () {
                      _phoneController.text = user.phone ?? '';
                      setState(() => _isEditingPhone = true);
                    },
                    onSave: () async {
                      await auth.updateProfile(
                          {'phone': _phoneController.text.trim()});
                      setState(() => _isEditingPhone = false);
                    },
                    onCancel: () =>
                        setState(() => _isEditingPhone = false),
                  ),
                  _buildInfoCard(
                    icon: Icons.badge_outlined,
                    label: 'Cargo',
                    value: AppTheme.getRoleLabel(user.role),
                  ),
                  const SizedBox(height: 20),
                  // Settings section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Configurações',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notificações',
                    subtitle: 'Gerenciar preferências de notificação',
                    onTap: () {},
                  ),
                  _buildSettingTile(
                    icon: Icons.language,
                    title: 'Idioma',
                    subtitle: 'Português (Brasil)',
                    onTap: () {},
                  ),
                  _buildSettingTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Aparência',
                    subtitle: 'Tema claro',
                    onTap: () {},
                  ),
                  _buildSettingTile(
                    icon: Icons.info_outlined,
                    title: 'Sobre',
                    subtitle: 'Duozz Flow v1.0.0',
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),
                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(),
                      icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                      label: const Text(
                        'Sair da Conta',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.errorColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    bool isEditing = false,
    TextEditingController? controller,
    VoidCallback? onEdit,
    VoidCallback? onSave,
    VoidCallback? onCancel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                isEditing && controller != null
                    ? TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
          if (isEditing) ...[
            IconButton(
              icon: const Icon(Icons.check, color: AppTheme.successColor),
              onPressed: onSave,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textTertiary),
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
            ),
          ] else if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.textTertiary),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.textSecondary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
        onTap: onTap,
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da Conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
