import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../widgets/project_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  String? _statusFilter;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().loadProjects();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    context.read<ProjectProvider>().loadProjects(
          status: _statusFilter,
          search: _searchController.text.trim().isNotEmpty
              ? _searchController.text.trim()
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final projectProvider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar projetos...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (_) => _applyFilter(),
              )
            : const Text('Projetos'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _applyFilter();
                }
              });
            },
          ),
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              tooltip: 'Painel Admin',
            ),
          if (auth.canManageProjects)
            IconButton(
              icon: const Icon(Icons.people_outlined),
              onPressed: () => Navigator.pushNamed(context, '/clients'),
              tooltip: 'Clientes',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Todos', null),
                _buildFilterChip('Rascunho', 'draft'),
                _buildFilterChip('Em Progresso', 'in_progress'),
                _buildFilterChip('Em Revisão', 'review'),
                _buildFilterChip('Entregue', 'delivered'),
                _buildFilterChip('Concluído', 'completed'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: projectProvider.isLoading
                ? const LoadingWidget(message: 'Carregando projetos...')
                : projectProvider.projects.isEmpty
                    ? EmptyState(
                        icon: Icons.folder_off_outlined,
                        title: 'Nenhum projeto encontrado',
                        subtitle: auth.canManageProjects
                            ? 'Crie seu primeiro projeto de vídeo'
                            : 'Você ainda não foi adicionado a nenhum projeto',
                        actionLabel:
                            auth.canManageProjects ? 'Criar Projeto' : null,
                        onAction: auth.canManageProjects
                            ? () => Navigator.pushNamed(
                                context, '/projects/create')
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: () => projectProvider.loadProjects(
                          status: _statusFilter,
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: projectProvider.projects.length,
                          itemBuilder: (context, index) {
                            final project = projectProvider.projects[index];
                            return ProjectCard(
                              project: project,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/projects/detail',
                                  arguments: project.id,
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: auth.canManageProjects
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/projects/create'),
              icon: const Icon(Icons.add),
              label: const Text('Novo Projeto'),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _statusFilter = selected ? status : null;
          });
          _applyFilter();
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }
}
