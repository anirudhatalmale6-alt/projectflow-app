import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/delivery_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class DeliveriesListScreen extends StatefulWidget {
  final String? projectId;

  const DeliveriesListScreen({super.key, this.projectId});

  @override
  State<DeliveriesListScreen> createState() => _DeliveriesListScreenState();
}

class _DeliveriesListScreenState extends State<DeliveriesListScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<DeliveryProvider>()
          .loadDeliveries(projectId: widget.projectId);
    });
  }

  void _applyFilter() {
    context.read<DeliveryProvider>().loadDeliveries(
          projectId: widget.projectId,
          status: _statusFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryProvider = context.watch<DeliveryProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: widget.projectId != null
          ? null
          : AppBar(
              title: const Text('Entregas'),
            ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Todos', null),
                _buildFilterChip('Pendente', 'pending'),
                _buildFilterChip('Em Revisão', 'in_review'),
                _buildFilterChip('Aprovado', 'approved'),
                _buildFilterChip('Rejeitado', 'rejected'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: deliveryProvider.isLoading
                ? const LoadingWidget(message: 'Carregando entregas...')
                : deliveryProvider.deliveries.isEmpty
                    ? EmptyState(
                        icon: Icons.video_file_outlined,
                        title: 'Nenhuma entrega',
                        subtitle: 'Entregas de vídeo aparecerão aqui',
                        actionLabel: (auth.isEditor ||
                                auth.isFreelancer ||
                                auth.canManageProjects)
                            ? 'Enviar Entrega'
                            : null,
                        onAction: (auth.isEditor ||
                                auth.isFreelancer ||
                                auth.canManageProjects)
                            ? () => Navigator.pushNamed(
                                context, '/deliveries/upload',
                                arguments: widget.projectId)
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: () => deliveryProvider.loadDeliveries(
                            projectId: widget.projectId),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: deliveryProvider.deliveries.length,
                          itemBuilder: (context, index) {
                            final delivery =
                                deliveryProvider.deliveries[index];
                            return DeliveryCard(
                              delivery: delivery,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/deliveries/detail',
                                arguments: delivery.id,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton:
          (auth.isEditor || auth.isFreelancer || auth.canManageProjects)
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.pushNamed(
                      context, '/deliveries/upload',
                      arguments: widget.projectId),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Nova Entrega'),
                  backgroundColor: AppTheme.secondaryColor,
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
          setState(() => _statusFilter = selected ? status : null);
          _applyFilter();
        },
        selectedColor: AppTheme.secondaryColor.withOpacity(0.15),
        checkmarkColor: AppTheme.secondaryColor,
      ),
    );
  }
}
