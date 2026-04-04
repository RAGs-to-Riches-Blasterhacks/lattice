import 'package:flutter/material.dart';
import 'package:lattice/models/user_stats.dart';
import 'package:lattice/services/api_service.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ProfileStatsScreen extends StatefulWidget {
  const ProfileStatsScreen({super.key});

  @override
  State<ProfileStatsScreen> createState() => _ProfileStatsScreenState();
}

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  UserStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await context.read<ApiService>().getMyStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Stats may not exist yet — that's fine
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatTile(
                label: 'Current Streak',
                value: '${_stats?.currentStreak ?? 0}',
                icon: Icons.local_fire_department,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: 'Longest Streak',
                value: '${_stats?.longestStreak ?? 0}',
                icon: Icons.emoji_events,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(
                label: 'Days Active',
                value: '${_stats?.totalDaysActive ?? 0}',
                icon: Icons.calendar_today,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: 'Tasks Done',
                value: '${_stats?.totalTasksCompleted ?? 0}',
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(
                label: 'Plans Completed',
                value: '${_stats?.totalPlansCompleted ?? 0}',
                icon: Icons.map_outlined,
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 20),
          _ActivityChart(days: _stats?.tasksCompletedByDay ?? []),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final List<DailyTaskCount> days;

  const _ActivityChart({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final maxCount = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final barMax = maxCount > 0 ? maxCount : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tasks Completed (30 days)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final fraction = day.count / barMax;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: FractionallySizedBox(
                      heightFactor: day.count > 0 ? 0.1 + (0.9 * fraction) : 0.05,
                      child: Container(
                        decoration: BoxDecoration(
                          color: day.count > 0
                              ? AppColors.accent.withValues(alpha: 0.4 + 0.6 * fraction)
                              : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
