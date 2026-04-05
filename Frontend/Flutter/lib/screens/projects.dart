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
  bool _deleteMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlansProvider>().fetchPlans();
    });
  }

  void _enterDeleteMode() {
    setState(() {
      _deleteMode = true;
      _selected.clear();
    });
  }

  void _exitDeleteMode() {
    setState(() {
      _deleteMode = false;
      _selected.clear();
    });
  }

  void _toggleSelection(String planId) {
    setState(() {
      if (_selected.contains(planId)) {
        _selected.remove(planId);
      } else {
        _selected.add(planId);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Plans',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete $count ${count == 1 ? 'plan' : 'plans'}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<PlansProvider>().deletePlans(_selected.toList());
      _exitDeleteMode();
    }
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
              Padding(
                padding: const EdgeInsets.only(right: 28.0, top: 25.0, left: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_deleteMode)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _exitDeleteMode,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Align(
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
                  ],
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
                                  final isSelected =
                                      _selected.contains(plan.id);
                                  return _ProjectTile(
                                    title: plan.skillName,
                                    deleteMode: _deleteMode,
                                    selected: isSelected,
                                    onTap: _deleteMode
                                        ? () => _toggleSelection(plan.id)
                                        : () => AppNavigation.goToRoadmap(
                                            context,
                                            planId: plan.id),
                                  );
                                },
                              ),
              ),
            ],
          ),
          // Delete FAB / confirm button
          Positioned(
            bottom: 100,
            right: 20,
            child: _deleteMode
                ? FloatingActionButton.extended(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _confirmDelete(context),
                    backgroundColor: _selected.isEmpty
                        ? AppColors.cardBackground
                        : Colors.redAccent,
                    icon: const Icon(Icons.delete_outline, color: AppColors.textPrimary),
                    label: Text(
                      _selected.isEmpty
                          ? 'Select plans'
                          : 'Delete (${_selected.length})',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  )
                : FloatingActionButton(
                    onPressed: _enterDeleteMode,
                    backgroundColor: AppColors.cardBackground,
                    elevation: 4,
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.textSecondary),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool deleteMode;
  final bool selected;

  const _ProjectTile({
    required this.title,
    required this.onTap,
    this.deleteMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.15) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.cardBorder,
          ),
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
            if (deleteMode)
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                size: 22,
              )
            else
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
