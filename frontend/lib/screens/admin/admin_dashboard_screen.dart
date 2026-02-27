import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.get(ApiConfig.adminStats);
      _stats = response['stats'] ?? response['data'] ?? response;
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading dashboard...')
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadStats)
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome header
                        const Text(
                          'Overview',
                          style: AppTheme.headingMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Platform statistics and management',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stats grid
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.4,
                          children: [
                            _buildStatCard(
                              'Total Users',
                              '${_stats?['totalUsers'] ?? 0}',
                              Icons.people_rounded,
                              AppTheme.primaryColor,
                              '+${_stats?['newUsersThisWeek'] ?? 0} this week',
                            ),
                            _buildStatCard(
                              'Total Projects',
                              '${_stats?['totalProjects'] ?? 0}',
                              Icons.folder_rounded,
                              AppTheme.secondaryColor,
                              '${_stats?['activeProjects'] ?? 0} active',
                            ),
                            _buildStatCard(
                              'Total Tasks',
                              '${_stats?['totalTasks'] ?? 0}',
                              Icons.task_alt_rounded,
                              AppTheme.warningColor,
                              '${_stats?['completedTasks'] ?? 0} completed',
                            ),
                            _buildStatCard(
                              'Active Today',
                              '${_stats?['activeToday'] ?? 0}',
                              Icons.trending_up_rounded,
                              AppTheme.successColor,
                              'users online',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Task status breakdown
                        _buildTaskBreakdownCard(),
                        const SizedBox(height: 24),

                        // Quick actions
                        Text('Quick Actions', style: AppTheme.headingSmall),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          Icons.people_rounded,
                          'Manage Users',
                          'View and manage all users',
                          AppTheme.primaryColor,
                          () => Navigator.of(context).pushNamed('/admin-users'),
                        ),
                        const SizedBox(height: 8),
                        _buildActionCard(
                          Icons.analytics_rounded,
                          'View Reports',
                          'Detailed analytics and reports',
                          AppTheme.secondaryColor,
                          () {},
                        ),
                        const SizedBox(height: 8),
                        _buildActionCard(
                          Icons.settings_rounded,
                          'System Settings',
                          'Configure platform settings',
                          AppTheme.warningColor,
                          () {},
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                title,
                style: AppTheme.caption.copyWith(fontSize: 12),
              ),
              Text(
                subtitle,
                style: AppTheme.caption.copyWith(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBreakdownCard() {
    final todo = _stats?['tasksByStatus']?['todo'] ?? 0;
    final inProgress = _stats?['tasksByStatus']?['in_progress'] ?? 0;
    final review = _stats?['tasksByStatus']?['review'] ?? 0;
    final done = _stats?['tasksByStatus']?['done'] ?? 0;
    final total = todo + inProgress + review + done;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Task Status Breakdown', style: AppTheme.headingSmall),
          const SizedBox(height: 16),

          // Progress bars
          if (total > 0) ...[
            // Combined progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (todo > 0)
                      Flexible(
                        flex: todo,
                        child: Container(color: AppTheme.statusTodo),
                      ),
                    if (inProgress > 0)
                      Flexible(
                        flex: inProgress,
                        child: Container(color: AppTheme.statusInProgress),
                      ),
                    if (review > 0)
                      Flexible(
                        flex: review,
                        child: Container(color: AppTheme.statusReview),
                      ),
                    if (done > 0)
                      Flexible(
                        flex: done,
                        child: Container(color: AppTheme.statusDone),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Legend
          Row(
            children: [
              _buildLegendItem('To Do', todo, AppTheme.statusTodo),
              _buildLegendItem('In Progress', inProgress, AppTheme.statusInProgress),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem('Review', review, AppTheme.statusReview),
              _buildLegendItem('Done', done, AppTheme.statusDone),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: AppTheme.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.labelMedium),
                  Text(subtitle, style: AppTheme.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
