import 'package:flutter/material.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/navigation/app_navigation.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/plan_input_bar.dart';
import 'package:lattice/widgets/topnav.dart';
import 'package:provider/provider.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlansProvider>().fetchPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final plansProvider = context.watch<PlansProvider>();
    final plans = plansProvider.plans
        .where((p) =>
            p.status == PlanStatus.active || p.status == PlanStatus.paused)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopNav(),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 28.0, top: 25.0, left: 24.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    'Your\nProjects',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: plansProvider.loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent),
                      )
                    : plansProvider.error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  plansProvider.error!,
                                  style: const TextStyle(
                                      color: Colors.redAccent),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () =>
                                      plansProvider.fetchPlans(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : plans.isEmpty
                            ? const Center(
                                child: Text(
                                  'No plans yet.\nUse the bar below to start one!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 18,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 120),
                                itemCount: plans.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final plan = plans[index];
                                  return _ProjectTile(
                                    title: plan.skillName,
                                    onTap: () =>
                                        AppNavigation.goToRoadmap(context,
                                            planId: plan.id),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ProjectTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
