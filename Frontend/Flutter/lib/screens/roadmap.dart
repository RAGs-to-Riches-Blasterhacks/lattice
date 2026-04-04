import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/branch_junction_widget.dart';
import 'package:lattice/widgets/roadmap_node_card.dart';
import 'package:lattice/widgets/topnav.dart'; // <-- Added TopNav import

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
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  Plan? _plan;
  late String _activeBranchId;
  final _inProgressKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final raw = await rootBundle.loadString('lib/mock-data/plan.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final plan = Plan.fromJson(json);
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
  }

  void _switchBranch(String branchId) {
    setState(() => _activeBranchId = branchId);
  }

  /// Builds the ordered list of items to render for the currently active branch.
  ///
  /// Active path = ancestor nodes (if a child branch) + nodes on active branch.
  /// After each node that is a divergence point, a [_BranchJunctionItem] is
  /// inserted for every non-active branch that forks from it.
  /// After the last ancestor node (divergence point), an additional junction is
  /// inserted showing the parent branch's continuation (the "other side").
  List<_RoadmapItem> _buildItems(Plan plan) {
    final activeBranch =
        plan.branches.firstWhere((b) => b.branchId == _activeBranchId);

    // ── Build ordered active path ────────────────────────────────────────────
    final List<PlanNode> activePath;

    if (activeBranch.parentBranchId != null &&
        activeBranch.divergedFromNodeId != null) {
      // Child branch: prepend ancestor nodes up to the divergence point.
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

    // ── Insert junction items at divergence points ───────────────────────────
    final items = <_RoadmapItem>[];

    for (final node in activePath) {
      items.add(_NormalItem(node));

      // Case A: other branches diverge FROM this node → show their first node.
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

      // Case B: this is OUR divergence point from the parent branch →
      // show the parent branch's continuation as a junction.
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
      
      // ── Replaced the old AppBar with TopNav here ─────────────────────────
      appBar: const TopNav(), 
      
      body: _plan == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
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