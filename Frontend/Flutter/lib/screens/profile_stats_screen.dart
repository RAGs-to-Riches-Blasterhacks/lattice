import 'package:flutter/material.dart';
import 'package:lattice/models/streak.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/services/api_service.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ProfileStatsScreen extends StatefulWidget {
  const ProfileStatsScreen({super.key});

  @override
  State<ProfileStatsScreen> createState() => _ProfileStatsScreenState();
}

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  Streak? _streak;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await context.read<ApiService>().getMyStreak();
      if (mounted) setState(() => _streak = streak);
    } catch (_) {
      // Streak may not exist yet — that's fine
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlansProvider>().plans;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak row
          Row(
            children: [
              _StatTile(
                label: 'Current Streak',
                value: '${_streak?.currentStreak ?? 0}',
                icon: Icons.local_fire_department,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: 'Longest Streak',
                value: '${_streak?.longestStreak ?? 0}',
                icon: Icons.emoji_events,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(
                label: 'Days Active',
                value: '${_streak?.totalDaysActive ?? 0}',
                icon: Icons.calendar_today,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: 'Total Plans',
                value: '${plans.length}',
                icon: Icons.map_outlined,
              ),
            ],
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
