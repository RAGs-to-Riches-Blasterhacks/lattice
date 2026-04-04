import 'package:flutter/material.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/branch_junction_widget.dart';
import 'package:lattice/widgets/roadmap_node_card.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/topnav.dart';
import 'package:provider/provider.dart';

// ── Sealed roadmap item types ────────────────────────────────────────────────

sealed class _RoadmapItem {}

final class _NormalItem extends _RoadmapItem {
  final PlanNode node;
  _NormalItem(this.node);
}

final class _BranchJunctionItem extends _RoadmapItem {
  final Branch branch;
  final PlanNode firstNode;
  _BranchJunctionItem(this.branch, this.firstNode);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class RoadmapScreen extends StatefulWidget {
  final String? planId;

  const RoadmapScreen({super.key, this.planId});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  Plan? _plan;
  late String _activeBranchId;
  final _inProgressKey = GlobalKey();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    if (widget.planId == null) {
      setState(() => _error = 'No plan ID provided');
      return;
    }

    try {
      final plan = await context.read<PlansProvider>().getPlan(widget.planId!);
      setState(() {
        _plan = plan;
        _activeBranchId = plan.activeBranchId;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _inProgressKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            alignment: 0.25,
          );
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _switchBranch(String branchId) {
    setState(() => _activeBranchId = branchId);
  }

  List<_RoadmapItem> _buildItems(Plan plan) {
    final activeBranch =
        plan.branches.firstWhere((b) => b.branchId == _activeBranchId);

    final List<PlanNode> activePath;

    if (activeBranch.parentBranchId != null &&
        activeBranch.divergedFromNodeId != null) {
      final parentNodes = plan.nodes
          .where((n) => n.branchId == activeBranch.parentBranchId)
          .toList()
        ..sort((a, b) => a.nodeNumber.compareTo(b.nodeNumber));

      final divIdx = parentNodes
          .indexWhere((n) => n.nodeId == activeBranch.divergedFromNodeId);

      final branchNodes = plan.nodes
          .where((n) => n.branchId == _activeBranchId)
          .toList()
        ..sort((a, b) => a.nodeNumber.compareTo(b.nodeNumber));

      activePath = [
        ...parentNodes.sublist(0, divIdx + 1),
        ...branchNodes,
      ];
    } else {
      activePath = plan.nodes
          .where((n) => n.branchId == _activeBranchId)
          .toList()
        ..sort((a, b) => a.nodeNumber.compareTo(b.nodeNumber));
    }

    final items = <_RoadmapItem>[];

    for (final node in activePath) {
      items.add(_NormalItem(node));

      final siblings = plan.branches
          .where((b) =>
              b.divergedFromNodeId == node.nodeId &&
              b.branchId != _activeBranchId)
          .toList();

      for (final sibling in siblings) {
        final firstNode =
            plan.nodes.firstWhere((n) => n.nodeId == sibling.firstNodeId);
        items.add(_BranchJunctionItem(sibling, firstNode));
      }

      if (activeBranch.divergedFromNodeId == node.nodeId) {
        final parentBranchId = activeBranch.parentBranchId!;
        final parentNodes = plan.nodes
            .where((n) => n.branchId == parentBranchId)
            .toList()
          ..sort((a, b) => a.nodeNumber.compareTo(b.nodeNumber));

        final nextParentNode = parentNodes
            .where((n) => n.nodeNumber > node.nodeNumber)
            .firstOrNull;

        if (nextParentNode != null) {
          final parentBranch =
              plan.branches.firstWhere((b) => b.branchId == parentBranchId);
          items.add(_BranchJunctionItem(parentBranch, nextParentNode));
        }
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopNav(),
      drawer: const AppDrawer(),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadPlan,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _plan == null
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.accent),
                )
              : _buildList(_plan!),
    );
  }

  Widget _buildList(Plan plan) {
    final items = _buildItems(plan);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        for (int i = 0; i < items.length; i++)
          switch (items[i]) {
            _NormalItem(:final node) => RoadmapNodeCard(
                key: node.status == NodeStatus.in_progress &&
                        node.branchId == _activeBranchId
                    ? _inProgressKey
                    : null,
                node: node,
                isLast: i == items.length - 1,
                displayNumber: i + 1,
              ),
            _BranchJunctionItem(:final branch, :final firstNode) =>
              BranchJunctionWidget(
                key: ValueKey('junction_${branch.branchId}'),
                branch: branch,
                branchNode: firstNode,
                allBranches: plan.branches,
                activeBranchId: _activeBranchId,
                onBranchSwitch: _switchBranch,
                isLast: i == items.length - 1,
                displayNumber: i + 1,
              ),
          },
      ],
    );
  }
}
