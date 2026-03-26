import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/task_card.dart';
import '../../widgets/delivery_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/role_badge.dart';
import '../../providers/job_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../models/calendar_event.dart';
import '../../models/chat_message.dart';
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
  bool _calendarLoaded = false;
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedCalDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  int _lastTabIndex = 0;

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index != _lastTabIndex) {
      _lastTabIndex = _tabController.index;
      setState(() {}); // Only rebuild when tab actually changes
    }
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
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final project = projectProvider.currentProject;
    final auth = context.watch<AuthProvider>();

    if (projectProvider.loadingProject) {
      return Scaffold(
        appBar: AppBar(),
        body: const LoadingWidget(message: 'Carregando projeto...'),
      );
    }

    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                projectProvider.errorMessage ?? 'Projeto não encontrado',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (_projectId != null) _loadData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: _buildFab(auth),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: MediaQuery.of(context).size.width < 600 ? 160 : 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 48, bottom: 12, right: 16),
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
                                  'Prazo: ${DateFormat('dd/MM/yyyy HH:mm').format(project.deadline!)}',
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
            if (project.description != null &&
                project.description!.isNotEmpty)
              SliverToBoxAdapter(
                child: _ExpandableDescription(description: project.description!),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Tarefas'),
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
      return FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/tasks/create',
            arguments: _projectId).then((_) {
          context.read<TaskProvider>().loadTasks(projectId: _projectId);
        }),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
      );
    }
    if (_tabController.index == 4 && auth.canManageProjects) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Adicionar'),
      );
    }
    return null;
  }

  Widget _buildStatsRow(Project project) {
    final isSmall = MediaQuery.of(context).size.width < 380;
    return Padding(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Row(
        children: [
          _buildStatCard(
            'Tarefas',
            '${project.taskStats.done}/${project.taskStats.total}',
            Icons.task_outlined,
            AppTheme.primaryColor,
          ),
          SizedBox(width: isSmall ? 8 : 12),
          _buildStatCard(
            'Entregas',
            '${project.deliveryCount}',
            Icons.video_file_outlined,
            AppTheme.secondaryColor,
          ),
          SizedBox(width: isSmall ? 8 : 12),
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
    final isSmall = MediaQuery.of(context).size.width < 380;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isSmall ? 10 : 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isSmall ? 18 : 22),
            SizedBox(height: isSmall ? 4 : 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmall ? 14 : 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 10 : 11,
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
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
                arguments: _projectId).then((_) {
                context.read<TaskProvider>().loadTasks(projectId: _projectId);
              })
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
    final auth = context.watch<AuthProvider>();
    final members = projectProvider.currentMembers;

    if (members.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: 'Nenhum membro',
        subtitle: 'Adicione membros a equipe do projeto',
        actionLabel: auth.canManageProjects ? 'Adicionar Membro' : null,
        onAction: auth.canManageProjects ? () => _showAddMemberDialog() : null,
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
            trailing: auth.canManageProjects
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'remove') {
                        _confirmRemoveMember(member);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'role',
                        enabled: false,
                        child: Row(
                          children: [
                            RoleBadge(role: member.role),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remover', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                : RoleBadge(role: member.role),
          ),
        );
      },
    );
  }

  void _confirmRemoveMember(User member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Membro'),
        content: Text('Tem certeza que deseja remover "${member.name}" da equipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ProjectProvider>().removeMember(_projectId!, member.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${member.name} removido da equipe')),
                );
              }
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() async {
    if (_projectId == null) return;
    final api = ApiService();
    List<User> allUsers = [];

    try {
      final data = await api.get(ApiConfig.adminUsers);
      final list = data['users'] ?? data['data'] ?? data;
      allUsers = (list as List).map((json) => User.fromJson(json)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar usuários')),
        );
      }
      return;
    }

    final currentMembers = context.read<ProjectProvider>().currentMembers;
    final memberIds = currentMembers.map((m) => m.id).toSet();
    final available = allUsers.where((u) => !memberIds.contains(u.id)).toList();

    if (!mounted) return;

    String selectedRole = 'editor';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Membro'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Função no Projeto',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'manager', child: Text('Gerente')),
                        DropdownMenuItem(value: 'editor', child: Text('Editor')),
                        DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedRole = v ?? 'editor'),
                    ),
                    const SizedBox(height: 16),
                    Text('Selecione um usuário:', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    if (available.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Todos os usuários já são membros'),
                      )
                    else
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: available.length,
                          itemBuilder: (ctx, i) {
                            final user = available[i];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.getRoleColor(user.role),
                                child: Text(user.initials, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                              title: Text(user.name, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
                              trailing: RoleBadge(role: user.role),
                              onTap: () async {
                                Navigator.pop(ctx);
                                await context.read<ProjectProvider>().addMember(_projectId!, user.id, role: selectedRole);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${user.name} adicionado à equipe como ${AppTheme.getRoleLabel(selectedRole)}')),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
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
    return _InlineChatWidget(projectId: _projectId!);
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

  void _loadCalendarMonth() {
    if (_projectId == null) return;
    final start = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final end = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0, 23, 59);
    context.read<CalendarProvider>().loadEvents(_projectId!, start: start, end: end);
  }

  Widget _buildCalendarTab() {
    final calProvider = context.watch<CalendarProvider>();
    final today = DateTime.now();

    // Auto-load events once
    if (!_calendarLoaded && _projectId != null) {
      _calendarLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCalendarMonth();
        calProvider.checkGoogleStatus();
      });
    }

    final dayEvents = _selectedCalDay != null
        ? calProvider.eventsForDay(_selectedCalDay!)
        : <CalendarEvent>[];

    // Calendar grid
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final startOffset = firstDay.weekday % 7;
    final totalDays = lastDay.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        // Google Calendar sync bar
        if (calProvider.googleLinked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Row(
              children: [
                Icon(Icons.sync, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    calProvider.syncMessage ?? 'Google Calendar conectado',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (calProvider.isSyncing)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  _buildSyncButton(
                    'Importar',
                    Icons.cloud_download_outlined,
                    () => _importFromGoogle(calProvider),
                  ),
                  const SizedBox(width: 4),
                  _buildSyncButton(
                    'Exportar',
                    Icons.cloud_upload_outlined,
                    () => _exportToGoogle(calProvider),
                  ),
                ],
              ],
            ),
          ),
        // Month header with navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                    _selectedCalDay = null;
                  });
                  _loadCalendarMonth();
                },
              ),
              Text(
                DateFormat('MMMM yyyy', 'pt_BR').format(_calendarMonth),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                        _selectedCalDay = null;
                      });
                      _loadCalendarMonth();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.primaryColor),
                    tooltip: 'Novo Evento',
                    onPressed: _showCreateEventDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Week day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: List.generate(rows, (row) {
              return Row(
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col;
                  final dayNum = cellIndex - startOffset + 1;
                  if (dayNum < 1 || dayNum > totalDays) {
                    return const Expanded(child: SizedBox(height: 38));
                  }
                  final date = DateTime(_calendarMonth.year, _calendarMonth.month, dayNum);
                  final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                  final isSelected = _selectedCalDay != null &&
                      date.year == _selectedCalDay!.year &&
                      date.month == _selectedCalDay!.month &&
                      date.day == _selectedCalDay!.day;
                  final hasEvents = calProvider.eventsForDay(date).isNotEmpty;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCalDay = date),
                      child: Container(
                        height: 38,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : isToday
                                  ? AppTheme.primaryColor.withAlpha(25)
                                  : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : isToday ? AppTheme.primaryColor : Colors.black87,
                              ),
                            ),
                            if (hasEvents)
                              Container(
                                width: 4, height: 4,
                                margin: const EdgeInsets.only(top: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
        const Divider(height: 1),
        // Events for selected day
        Expanded(
          child: _selectedCalDay == null
              ? Center(
                  child: Text('Selecione um dia para ver eventos', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                )
              : dayEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Nenhum evento neste dia', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: dayEvents.length,
                      itemBuilder: (context, index) {
                        final event = dayEvents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                event.type == 'deadline' ? Icons.flag : Icons.event,
                                color: AppTheme.primaryColor, size: 18,
                              ),
                            ),
                            title: Text(event.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            dense: true,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSyncButton(String label, IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.blue.shade700),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
          ],
        ),
      ),
    );
  }

  void _showCreateEventDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime startDate = _selectedCalDay ?? DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    String eventType = 'deadline';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo Evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descricao (opcional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: eventType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'deadline', child: Text('Prazo')),
                    DropdownMenuItem(value: 'meeting', child: Text('Reuniao')),
                    DropdownMenuItem(value: 'review', child: Text('Revisao')),
                    DropdownMenuItem(value: 'milestone', child: Text('Marco')),
                  ],
                  onChanged: (v) => setDialogState(() => eventType = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data', style: TextStyle(fontSize: 13)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Inicio', style: TextStyle(fontSize: 13)),
                        subtitle: Text(startTime.format(ctx)),
                        onTap: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: startTime);
                          if (picked != null) setDialogState(() => startTime = picked);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fim', style: TextStyle(fontSize: 13)),
                        subtitle: Text(endTime.format(ctx)),
                        onTap: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: endTime);
                          if (picked != null) setDialogState(() => endTime = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                titleCtrl.dispose();
                descCtrl.dispose();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
                final end = DateTime(startDate.year, startDate.month, startDate.day, endTime.hour, endTime.minute);

                final calProvider = context.read<CalendarProvider>();
                await calProvider.createEvent(_projectId!, {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'start_date': start.toIso8601String(),
                  'end_date': end.toIso8601String(),
                  'event_type': eventType,
                });

                titleCtrl.dispose();
                descCtrl.dispose();
                _loadCalendarMonth();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Evento criado!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  void _importFromGoogle(CalendarProvider calProvider) {
    final start = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final end = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0, 23, 59, 59);
    calProvider.importFromGoogle(_projectId!, start, end);
  }

  void _exportToGoogle(CalendarProvider calProvider) {
    calProvider.exportToGoogle(_projectId!);
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

class _ExpandableDescription extends StatefulWidget {
  final String description;
  const _ExpandableDescription({required this.description});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;
  static const int _maxChars = 200;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.description.length > _maxChars;
    final displayText = (!_expanded && isLong)
        ? '${widget.description.substring(0, _maxChars)}...'
        : widget.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Descrição',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayText,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
            if (isLong)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? 'Ver menos' : 'Ver mais',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
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

// Inline chat widget embedded directly in the Chat tab
class _InlineChatWidget extends StatefulWidget {
  final String projectId;
  const _InlineChatWidget({required this.projectId});

  @override
  State<_InlineChatWidget> createState() => _InlineChatWidgetState();
}

class _InlineChatWidgetState extends State<_InlineChatWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _initializing = true;
  String? _channelId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      final chat = context.read<ChatProvider>();
      chat.joinProject(widget.projectId);

      // Ensure default channel exists
      final channel = await chat.ensureDefaultChannel(widget.projectId);
      if (channel != null && mounted) {
        _channelId = channel.id;
        await chat.loadMessages(channel.id);
      }
    } catch (e) {
      if (mounted) {
        _error = e.toString();
      }
    }

    if (mounted) {
      setState(() => _initializing = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _channelId == null) return;

    _messageController.clear();
    final chat = context.read<ChatProvider>();
    final sent = await chat.sendMessage(_channelId!, text);
    if (sent) _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Erro ao carregar chat', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _initChat,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final chatProvider = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id;
    final messages = chatProvider.messages;

    if (messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Column(
      children: [
        Expanded(
          child: chatProvider.loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('Nenhuma mensagem ainda', style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text('Envie a primeira mensagem!', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.userId == currentUserId;
                        final showName = !isMe &&
                            (index == 0 || messages[index - 1].userId != msg.userId);
                        return _buildMessage(msg, isMe, showName);
                      },
                    ),
        ),
        _buildInput(),
      ],
    );
  }

  Widget _buildMessage(ChatMessage msg, bool isMe, bool showName) {
    final avatar = _buildAvatar(msg, isMe, showName);

    return Container(
      margin: EdgeInsets.only(
        bottom: 4,
        top: showName ? 12 : 2,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            showName
                ? avatar
                : const SizedBox(width: 36),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      msg.userName ?? 'Usuario',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primaryColor : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            showName
                ? avatar
                : const SizedBox(width: 36),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatMessage msg, bool isMe, bool showName) {
    final name = msg.userName ?? '?';
    final initials = name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final avatarUrl = msg.userAvatar;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final fullUrl = avatarUrl.startsWith('http')
          ? avatarUrl
          : '${ApiConfig.baseUrl}/uploads/$avatarUrl';
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(fullUrl),
        backgroundColor: Colors.grey[300],
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? AppTheme.primaryColor.withAlpha(40) : Colors.grey[300],
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isMe ? AppTheme.primaryColor : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Digite uma mensagem...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
