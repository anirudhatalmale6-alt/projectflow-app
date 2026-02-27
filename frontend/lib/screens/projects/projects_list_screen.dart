import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // Could open a search delegate
            },
          ),
        ],
      ),
      body: Consumer<ProjectProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.projects.isEmpty) {
            return const LoadingWidget(message: 'Loading projects...');
          }

          if (provider.errorMessage != null && provider.projects.isEmpty) {
            return ErrorState(
              message: provider.errorMessage!,
              onRetry: () => provider.loadProjects(),
            );
          }

          if (provider.projects.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'No projects yet',
              subtitle: 'Create your first project to get started',
              actionLabel: 'Create Project',
              onAction: () => Navigator.of(context).pushNamed('/create-project'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadProjects(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.projects.length,
              itemBuilder: (context, index) {
                final project = provider.projects[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ProjectCard(
                    project: project,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/project-detail',
                        arguments: project.id,
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed('/create-project'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
