import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/task_card.dart';
import '../../widgets/delivery_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/role_badge.dart';
import '../../providers/job_provider.dart';
import '../../models/job.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to update FAB
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id != _projectId) {
      _projectId = id;
      _loadData();
    }
  }

  void _loadData() {
    context.read<ProjectProvider>().loadProject(_projectId!);
    context.read<TaskProvider>().loadTasks(projectId: _projectId);
    context.read<DeliveryProvider>().loadDeliveries(projectId: _projectId);
    context.read<JobProvider>().loadJobs(_projectId!);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final project = projectProvider.currentProject;
    final auth = context.watch<AuthProvider>();

    if (projectProvider.isLoading || project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const LoadingWidget(message: 'Carregando projeto...'),
      );
    }

    return Scaffold(
      floatingActionButton: _buildFab(auth),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  project.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        project.color != null
                            ? Color(int.parse(
                                '0xFF${project.color!.replaceAll('#', '')}'))
                            : AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),
                          Row(
                            children: [
                              StatusBadge(
                                status: project.status,
                                label:
                                    AppTheme.getProjectStatusLabel(project.status),
                                color: Colors.white,
                              ),
                              const Spacer(),
                              if (project.budget != null)
                                Text(
                                  '${project.currency ?? "R\$"} ${project.budget!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          if (project.clientName != null)
                            Row(
                              children: [
                                Icon(Icons.business,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.8)),
                                const SizedBox(width: 6),
                                Text(
                                  project.clientName!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          if (project.deadline != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.8)),
                                const SizedBox(width: 6),
                                Text(
                                  'Prazo: ${DateFormat('dd/MM/yyyy').format(project.deadline!)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                                if (project.isOverdue) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ATRASADO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                if (auth.canManageProjects)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          Navigator.pushNamed(context, '/projects/create',
                              arguments: project);
                          break;
                        case 'delete':
                          _confirmDelete(project);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          )),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outlined,
                                  size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Excluir',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          )),
                    ],
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: _buildStatsRow(project),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Tarefas'),
                    Tab(text: 'Jobs'),
                    Tab(text: 'Entregas'),
                    Tab(text: 'Chat'),
                    Tab(text: 'Drive'),
                    Tab(text: 'Equipe'),
                    Tab(text: 'Calendário'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTasksTab(auth),
            _buildJobsTab(auth),
            _buildDeliveriesTab(auth),
            _buildChatTab(),
            _buildDriveTab(),
            _buildTeamTab(),
            _buildCalendarTab(),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab(AuthProvider auth) {
    // Show FAB based on active tab
    if (_tabController.index == 0 && auth.canAssignTasks) {
      // Tarefas tab
      return FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/tasks/create',
            arguments: _projectId),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
      );
    } else if (_tabController.index == 1 && auth.canManageProjects) {
      // Jobs tab
      return FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/jobs',
            arguments: _projectId),
        icon: const Icon(Icons.work_outline),
        label: const Text('Ver Jobs'),
      );
    }
    return null;
  }

  Widget _buildStatsRow(Project project) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            'Tarefas',
            '${project.taskStats.done}/${project.taskStats.total}',
            Icons.task_outlined,
            AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Entregas',
            '${project.deliveryCount}',
            Icons.video_file_outlined,
            AppTheme.secondaryColor,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Equipe',
            '${project.members.length}',
            Icons.group_outlined,
            AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab(AuthProvider auth) {
    final taskProvider = context.watch<TaskProvider>();

    if (taskProvider.isLoading) {
      return const LoadingWidget();
    }

    if (taskProvider.tasks.isEmpty) {
      return EmptyState(
        icon: Icons.task_outlined,
        title: 'Nenhuma tarefa',
        subtitle: 'Adicione tarefas para organizar o trabalho',
        actionLabel: auth.canAssignTasks ? 'Criar Tarefa' : null,
        onAction: auth.canAssignTasks
            ? () => Navigator.pushNamed(context, '/tasks/create',
                arguments: _projectId)
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: taskProvider.tasks.length,
      itemBuilder: (context, index) {
        final task = taskProvider.tasks[index];
        return TaskCard(
          task: task,
          onTap: () => Navigator.pushNamed(context, '/tasks/detail',
              arguments: task.id),
        );
      },
    );
  }

  Widget _buildDeliveriesTab(AuthProvider auth) {
    final deliveryProvider = context.watch<DeliveryProvider>();

    if (deliveryProvider.isLoading) {
      return const LoadingWidget();
    }

    if (deliveryProvider.deliveries.isEmpty) {
      return EmptyState(
        icon: Icons.video_file_outlined,
        title: 'Nenhuma entrega',
        subtitle: 'Entregas de arquivos aparecerao aqui',
        actionLabel: (auth.isEditor || auth.isFreelancer || auth.canManageProjects)
            ? 'Enviar Entrega'
            : null,
        onAction: (auth.isEditor || auth.isFreelancer || auth.canManageProjects)
            ? () => Navigator.pushNamed(context, '/deliveries/upload',
                arguments: _projectId)
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: deliveryProvider.deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveryProvider.deliveries[index];
        return DeliveryCard(
          delivery: delivery,
          onTap: () => Navigator.pushNamed(context, '/deliveries/detail',
              arguments: delivery.id),
        );
      },
    );
  }

  Widget _buildTeamTab() {
    final projectProvider = context.watch<ProjectProvider>();
    final members = projectProvider.currentMembers;

    if (members.isEmpty) {
      return const EmptyState(
        icon: Icons.group_outlined,
        title: 'Nenhum membro',
        subtitle: 'Adicione membros a equipe do projeto',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.getRoleColor(member.role),
              child: Text(
                member.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(member.email),
            trailing: RoleBadge(role: member.role),
          ),
        );
      },
    );
  }

  Widget _buildJobsTab(AuthProvider auth) {
    final jobProvider = context.watch<JobProvider>();

    if (jobProvider.isLoading) {
      return const LoadingWidget();
    }

    if (jobProvider.jobs.isEmpty) {
      return EmptyState(
        icon: Icons.work_outline,
        title: 'Nenhum job',
        subtitle: 'Adicione jobs de edição ao projeto',
        actionLabel: auth.canManageProjects ? 'Ver Jobs' : null,
        onAction: auth.canManageProjects
            ? () => Navigator.pushNamed(context, '/jobs', arguments: _projectId)
            : null,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/jobs', arguments: _projectId),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver Todos'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: jobProvider.jobs.length,
            itemBuilder: (context, index) {
              final job = jobProvider.jobs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getJobTypeColor(job.type).withAlpha(25),
                    child: Text(
                      Job.typeLabel(job.type).substring(0, 1),
                      style: TextStyle(
                        color: _getJobTypeColor(job.type),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(Job.statusLabel(job.status)),
                  trailing: job.assigneeName != null
                      ? Chip(label: Text(job.assigneeName!, style: const TextStyle(fontSize: 11)))
                      : null,
                  onTap: () => Navigator.pushNamed(context, '/jobs/detail', arguments: job.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Chat do Projeto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Converse com a equipe em tempo real',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/chat', arguments: _projectId),
            icon: const Icon(Icons.chat),
            label: const Text('Abrir Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_to_drive, size: 64, color: Colors.green[400]),
          const SizedBox(height: 16),
          const Text(
            'Google Drive',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Organize arquivos do projeto com pastas automáticas',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/drive', arguments: {
              'projectId': _projectId,
              'projectName': context.read<ProjectProvider>().currentProject?.name ?? 'Drive',
            }),
            icon: const Icon(Icons.folder_open),
            label: const Text('Abrir Drive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Calendário do Projeto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Prazos, reuniões e marcos',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/calendar', arguments: _projectId),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Abrir Calendário'),
          ),
        ],
      ),
    );
  }

  Color _getJobTypeColor(String type) {
    switch (type) {
      case 'edit': return const Color(0xFF2563EB);
      case 'color_grade': return const Color(0xFF7C3AED);
      case 'motion_graphics': return const Color(0xFFEC4899);
      case 'audio_mix': return const Color(0xFF14B8A6);
      case 'subtitles': return const Color(0xFFF59E0B);
      case 'vfx': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  void _confirmDelete(Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Projeto'),
        content: Text(
          'Tem certeza que deseja excluir "${project.name}"? Esta acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<ProjectProvider>()
                  .deleteProject(project.id);
              if (success && mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
