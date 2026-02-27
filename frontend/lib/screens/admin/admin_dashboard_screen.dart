import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/loading_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.get(ApiConfig.adminStats);
      setState(() => _stats = data);
    } catch (_) {
      // Use placeholder data for UI display
      setState(() {
        _stats = {
          'total_users': 0,
          'total_projects': 0,
          'total_tasks': 0,
          'total_deliveries': 0,
          'active_projects': 0,
          'completed_tasks': 0,
          'pending_deliveries': 0,
          'users_by_role': {
            'admin': 0,
            'manager': 0,
            'editor': 0,
            'freelancer': 0,
            'client': 0,
          },
          'tasks_by_status': {
            'todo': 0,
            'in_progress': 0,
            'review': 0,
            'done': 0,
          },
        };
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Painel Admin')),
        body: const Center(
          child: Text(
            'Acesso restrito a administradores',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Administrativo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outlined),
            onPressed: () => Navigator.pushNamed(context, '/admin/users'),
            tooltip: 'Gerenciar Usuarios',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Carregando estatisticas...')
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats cards
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _buildStatCard(
                          'Usuarios',
                          '${_stats?['total_users'] ?? 0}',
                          Icons.people,
                          AppTheme.primaryColor,
                        ),
                        _buildStatCard(
                          'Projetos',
                          '${_stats?['total_projects'] ?? 0}',
                          Icons.folder,
                          AppTheme.secondaryColor,
                        ),
                        _buildStatCard(
                          'Tarefas',
                          '${_stats?['total_tasks'] ?? 0}',
                          Icons.task,
                          AppTheme.warningColor,
                        ),
                        _buildStatCard(
                          'Entregas',
                          '${_stats?['total_deliveries'] ?? 0}',
                          Icons.video_file,
                          AppTheme.successColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Summary stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            'Projetos Ativos',
                            '${_stats?['active_projects'] ?? 0}',
                            AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMiniStat(
                            'Tarefas Concluidas',
                            '${_stats?['completed_tasks'] ?? 0}',
                            AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMiniStat(
                            'Entregas Pendentes',
                            '${_stats?['pending_deliveries'] ?? 0}',
                            AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Tasks by status chart
                    const Text(
                      'Tarefas por Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _buildTasksChart(),
                    ),
                    const SizedBox(height: 24),
                    // Users by role
                    const Text(
                      'Usuarios por Cargo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _buildUsersChart(),
                    ),
                    const SizedBox(height: 24),
                    // Quick actions
                    const Text(
                      'Acoes Rapidas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.people_outlined,
                                color: AppTheme.primaryColor),
                            title: const Text('Gerenciar Usuarios'),
                            subtitle:
                                const Text('Adicionar, editar ou remover'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                Navigator.pushNamed(context, '/admin/users'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.folder_outlined,
                                color: AppTheme.secondaryColor),
                            title: const Text('Todos os Projetos'),
                            subtitle: const Text('Visualizar e gerenciar'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.history,
                                color: AppTheme.warningColor),
                            title: const Text('Log de Auditoria'),
                            subtitle: const Text('Historico de acoes'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTasksChart() {
    final tasksByStatus =
        _stats?['tasks_by_status'] as Map<String, dynamic>? ?? {};
    final todo = (tasksByStatus['todo'] ?? 0).toDouble();
    final inProgress = (tasksByStatus['in_progress'] ?? 0).toDouble();
    final review = (tasksByStatus['review'] ?? 0).toDouble();
    final done = (tasksByStatus['done'] ?? 0).toDouble();
    final total = todo + inProgress + review + done;

    if (total == 0) {
      return const Center(
        child: Text(
          'Sem dados disponíveis',
          style: TextStyle(color: AppTheme.textTertiary),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: todo,
            color: AppTheme.statusDraft,
            title: 'A Fazer\n${todo.toInt()}',
            titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white),
            radius: 80,
          ),
          PieChartSectionData(
            value: inProgress,
            color: AppTheme.statusInProgress,
            title: 'Progresso\n${inProgress.toInt()}',
            titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white),
            radius: 80,
          ),
          PieChartSectionData(
            value: review,
            color: AppTheme.statusReview,
            title: 'Revisao\n${review.toInt()}',
            titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white),
            radius: 80,
          ),
          PieChartSectionData(
            value: done,
            color: AppTheme.statusCompleted,
            title: 'Concluido\n${done.toInt()}',
            titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white),
            radius: 80,
          ),
        ],
        sectionsSpace: 3,
        centerSpaceRadius: 0,
      ),
    );
  }

  Widget _buildUsersChart() {
    final byRole =
        _stats?['users_by_role'] as Map<String, dynamic>? ?? {};
    final entries = byRole.entries.toList();

    if (entries.isEmpty || entries.every((e) => (e.value ?? 0) == 0)) {
      return const Center(
        child: Text(
          'Sem dados disponiveis',
          style: TextStyle(color: AppTheme.textTertiary),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: entries.fold<double>(
                0, (max, e) => (e.value ?? 0) > max ? e.value.toDouble() : max) +
            2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppTheme.getRoleLabel(entries[idx].key),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) {
          final color = AppTheme.getRoleColor(entry.value.key);
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: (entry.value.value ?? 0).toDouble(),
                color: color,
                width: 28,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
