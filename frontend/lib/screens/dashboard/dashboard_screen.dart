import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/notification_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshData();
    });
  }

  /// Public method so HomeScreen can trigger a refresh when tab becomes visible.
  Future<void> refreshData() async {
    final auth = context.read<AuthProvider>();
    context.read<ProjectProvider>().loadProjects();
    context.read<TaskProvider>().loadTasks(
          assigneeId:
              (auth.isEditor || auth.isFreelancer) ? auth.user?.id : null,
        );
    context.read<NotificationProvider>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final projects = context.watch<ProjectProvider>();
    final tasks = context.watch<TaskProvider>();
    final notifs = context.watch<NotificationProvider>();
    final user = auth.user;

    final overdueProjects =
        projects.projects.where((p) => p.isOverdue).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  MediaQuery.of(context).size.width < 600 ? 44 : 56,
                  MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  MediaQuery.of(context).size.width < 600 ? 16 : 24,
                ),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          child: Text(
                            user?.initials ?? 'U',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.6),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                user?.name ?? 'Usuário',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spacer for notification bell (now in global overlay)
                        const SizedBox(width: 40),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).size.width < 600 ? 14 : 20),
                    // Quick stats
                    Row(
                      children: [
                        _buildQuickStat(
                          '${projects.projects.length}',
                          'Projetos',
                          Icons.folder_outlined,
                        ),
                        const SizedBox(width: 6),
                        _buildQuickStat(
                          '${tasks.tasks.length}',
                          'Tarefas',
                          Icons.task_outlined,
                        ),
                        const SizedBox(width: 6),
                        _buildQuickStat(
                          '${tasks.inProgressTasks.length}',
                          'Ativas',
                          Icons.play_circle_outline,
                        ),
                        const SizedBox(width: 6),
                        _buildQuickStat(
                          '${notifs.unreadCount}',
                          'Avisos',
                          Icons.notifications_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ============ OVERDUE PROJECTS ALERT ============
            if (overdueProjects.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      // Show overdue projects in a bottom sheet
                      _showOverdueProjects(overdueProjects);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade600,
                            Colors.red.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${overdueProjects.length}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  overdueProjects.length == 1
                                      ? 'Projeto em atraso!'
                                      : 'Projetos em atraso!',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toque para ver detalhes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (overdueProjects.isNotEmpty)
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Stats cards
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Tarefas Pendentes',
                            '${tasks.todoTasks.length}',
                            Icons.pending_actions,
                            AppTheme.statusPending,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Em Revisão',
                            '${tasks.reviewTasks.length}',
                            Icons.rate_review_outlined,
                            AppTheme.statusReview,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Concluídas',
                            '${tasks.doneTasks.length}',
                            Icons.check_circle_outline,
                            AppTheme.statusCompleted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Projetos Ativos',
                            '${projects.projects.where((p) => p.status == 'in_progress').length}',
                            Icons.movie_creation_outlined,
                            AppTheme.infoColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Active tasks - clickable
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tarefas em Andamento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (tasks.inProgressTasks.isNotEmpty)
                      TextButton(
                        onPressed: () {},
                        child: const Text('Ver todas'),
                      ),
                  ],
                ),
              ),
            ),

            if (tasks.inProgressTasks.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: _EmptyTaskCard(),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= 5) return null;
                    final task = tasks.inProgressTasks[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 20, vertical: 4),
                      child: _buildTaskTile(task),
                    );
                  },
                  childCount: tasks.inProgressTasks.length > 5
                      ? 5
                      : tasks.inProgressTasks.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Recent projects - clickable with status bars
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Projetos Recentes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (projects.projects.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          // Switch to Projects tab would need a callback; navigate instead
                        },
                        child: const Text('Ver todos'),
                      ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            if (projects.projects.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyProjectCard(),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final project = projects.projects[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 20, vertical: 5),
                      child: _buildProjectCard(project),
                    );
                  },
                  childCount: projects.projects.length > 6
                      ? 6
                      : projects.projects.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _showOverdueProjects(List<dynamic> overdueProjects) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Projetos em Atraso (${overdueProjects.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...overdueProjects.map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.movie_outlined,
                        color: Colors.red, size: 20),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  subtitle: Text(
                    p.deadline != null
                        ? 'Prazo: ${DateFormat('dd/MM/yyyy').format(p.deadline!)} (${p.daysUntilDeadline.abs()} dias de atraso)'
                        : 'Sem prazo definido',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/projects/detail',
                        arguments: p.id);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia,';
    if (hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  Widget _buildQuickStat(String value, String label, IconData icon) {
    final isSmall = MediaQuery.of(context).size.width < 380;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isSmall ? 8 : 12,
          horizontal: isSmall ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: isSmall ? 16 : 20),
            SizedBox(height: isSmall ? 4 : 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmall ? 16 : 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 9 : 10,
                color: Colors.white.withOpacity(0.75),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final isSmall = MediaQuery.of(context).size.width < 380;
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSmall ? 32 : 40,
            height: isSmall ? 32 : 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isSmall ? 18 : 22),
          ),
          SizedBox(height: isSmall ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 22 : 28,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              color: AppTheme.textSecondary,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(dynamic task) {
    final color = AppTheme.getTaskStatusColor(task.status);
    final priorityColor = AppTheme.getPriorityColor(task.priority);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.pushNamed(context, '/tasks/detail', arguments: task.id);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppTheme.getTaskStatusLabel(task.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppTheme.getPriorityLabel(task.priority),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: priorityColor,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(dynamic project) {
    final color = AppTheme.getProjectStatusColor(project.status);
    final stats = project.taskStats;
    final progress = stats.progress;
    final isOverdue = project.isOverdue;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(context, '/projects/detail',
            arguments: project.id);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue ? Colors.red.withOpacity(0.4) : AppTheme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.movie_outlined, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (project.clientName != null)
                        Text(
                          project.clientName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Status badge - clickable to show project detail
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppTheme.getProjectStatusLabel(project.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Task progress bar
            if (stats.total > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            if (stats.done > 0)
                              Expanded(
                                flex: stats.done,
                                child: Container(
                                    color: AppTheme.statusCompleted),
                              ),
                            if (stats.review > 0)
                              Expanded(
                                flex: stats.review,
                                child: Container(
                                    color: AppTheme.statusReview),
                              ),
                            if (stats.inProgress > 0)
                              Expanded(
                                flex: stats.inProgress,
                                child: Container(
                                    color: AppTheme.statusInProgress),
                              ),
                            if (stats.todo > 0)
                              Expanded(
                                flex: stats.todo,
                                child: Container(
                                    color: Colors.grey.shade200),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Task counts legend
              Row(
                children: [
                  _buildLegendDot(AppTheme.statusCompleted, '${stats.done}'),
                  const SizedBox(width: 10),
                  _buildLegendDot(AppTheme.statusReview, '${stats.review}'),
                  const SizedBox(width: 10),
                  _buildLegendDot(
                      AppTheme.statusInProgress, '${stats.inProgress}'),
                  const SizedBox(width: 10),
                  _buildLegendDot(Colors.grey.shade300, '${stats.todo}'),
                  const Spacer(),
                  if (project.deadline != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: isOverdue ? Colors.red : AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM').format(project.deadline!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color:
                                isOverdue ? Colors.red : AppTheme.textTertiary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ATRASO',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text(
                    'Sem tarefas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Spacer(),
                  if (project.deadline != null)
                    Text(
                      DateFormat('dd/MM/yyyy').format(project.deadline!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue ? Colors.red : AppTheme.textTertiary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          count,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textTertiary,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _EmptyTaskCard extends StatelessWidget {
  const _EmptyTaskCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(Icons.task_outlined, size: 40, color: AppTheme.textTertiary),
          const SizedBox(height: 8),
          const Text(
            'Nenhuma tarefa em andamento',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProjectCard extends StatelessWidget {
  const _EmptyProjectCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_outlined, size: 40, color: AppTheme.textTertiary),
          const SizedBox(height: 8),
          const Text(
            'Nenhum projeto ainda',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
