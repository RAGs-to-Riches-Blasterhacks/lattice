import 'package:flutter/material.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ProfileHistoryScreen extends StatelessWidget {
  const ProfileHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = context
        .watch<PlansProvider>()
        .plans
        .where((p) =>
            p.status == PlanStatus.completed ||
            p.status == PlanStatus.abandoned)
        .toList();

    if (plans.isEmpty) {
      return const Center(
        child: Text(
          'No plans yet',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _PlanHistoryTile(plan: plan);
      },
    );
  }
}

class _PlanHistoryTile extends StatelessWidget {
  final PlanSummary plan;
  const _PlanHistoryTile({required this.plan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/roadmap', arguments: plan.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00C9C8).withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.skillName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.nodeCount} steps  |  ${plan.status.name}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
