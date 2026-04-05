import 'package:flutter/material.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/branch_junction_widget.dart';
import 'package:lattice/widgets/chat_overlay.dart';
import 'package:lattice/widgets/plan_card.dart';
import 'package:lattice/widgets/quick_note_dialog.dart';
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
  final List<Branch> relatedBranches;
  _BranchJunctionItem(this.branch, this.firstNode, this.relatedBranches);
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

  // Node detail overlay state
  PlanNode? _selectedNode;
  bool _planCardCollapsed = false;

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

        // Keep selected node in sync with fresh plan data.
        if (_selectedNode != null) {
          final freshNode = plan.nodes.cast<PlanNode?>().firstWhere(
                (n) => n!.nodeId == _selectedNode!.nodeId,
                orElse: () => null,
              );
          if (freshNode != null) {
            _selectedNode = freshNode;
          }
        }
      });

      // Only auto-scroll when no node is selected (chat not open).
      if (_selectedNode == null) {
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
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _switchBranch(String branchId) {
    setState(() => _activeBranchId = branchId);
  }

  void _showNodeDetail(PlanNode node) {
    setState(() {
      _selectedNode = node;
      _planCardCollapsed = false;
    });
  }

  void _dismissNodeOverlay() {
    setState(() {
      _selectedNode = null;
      _planCardCollapsed = false;
    });
  }

  /// Recursively walks up the parent chain to build the full active path.
  /// For Branch B → Branch A → Main, this returns:
  ///   [Main nodes up to A's diverge] + [A nodes up to B's diverge] + [B nodes]
  List<PlanNode> _resolveActivePath(Plan plan, String branchId) {
    final branch = plan.branches.firstWhere((b) => b.branchId == branchId);

    final branchNodes = plan.nodes
        .where((n) => n.branchId == branchId)
        .toList()
      ..sort((a, b) => a.nodeNumber.compareTo(b.nodeNumber));

    if (branch.parentBranchId == null || branch.divergedFromNodeId == null) {
      return branchNodes;
    }

    final ancestorPath = _resolveActivePath(plan, branch.parentBranchId!);
    final divIdx =
        ancestorPath.indexWhere((n) => n.nodeId == branch.divergedFromNodeId);

    if (divIdx == -1) return branchNodes; // data inconsistency fallback

    return [
      ...ancestorPath.sublist(0, divIdx + 1),
      ...branchNodes,
    ];
  }

  /// Returns the ancestry chain root-first, ending with the active branch.
  /// e.g. [Main, BranchA, BranchB] when BranchB is active.
  List<Branch> _getAncestryChain(Plan plan, String branchId) {
    final chain = <Branch>[];
    var current = plan.branches.firstWhere((b) => b.branchId == branchId);
    chain.add(current);
    while (current.parentBranchId != null) {
      current =
          plan.branches.firstWhere((b) => b.branchId == current.parentBranchId);
      chain.add(current);
    }
    return chain.reversed.toList();
  }

  /// The dropdown options for a junction at [divergeNode].
  /// Includes the branch that owns the node ("stay on this path") plus every
  /// branch that forked from it ("take an alternative path").
List<Branch> _branchOptionsAt(Plan plan, PlanNode divergeNode) {
  // 1. Find the "Base" branch (the one the current node belongs to)
  final baseBranch = plan.branches.firstWhere((b) => b.branchId == divergeNode.branchId);

  // 2. Find ALL branches that forked from this specific node
  final forks = plan.branches
      .where((b) => b.divergedFromNodeId == divergeNode.nodeId)
      .toList();

  // 3. If the current node IS a divergence point (e.g., we are already on a branch), 
  // we also need to include the "Parent" path as an option so we can go back.
  // We add the branch that the divergeNode belongs to, plus all other forks.
  
  final Map<String, Branch> distinctOptions = {};
  distinctOptions[baseBranch.branchId] = baseBranch;
  for (var f in forks) {
    distinctOptions[f.branchId] = f;
  }

  return distinctOptions.values.toList();
}

List<_RoadmapItem> _buildItems(Plan plan) {
  final activePath = _resolveActivePath(plan, _activeBranchId);
  final ancestryChain = _getAncestryChain(plan, _activeBranchId);
  final ancestorBranchIds = ancestryChain.map((b) => b.branchId).toSet();

  final items = <_RoadmapItem>[];

  for (final node in activePath) {
    // Determine if this node is a "Junction Point"
    // A junction exists if ANY branch in the entire plan diverged from this nodeId
    final forksAtThisNode = plan.branches.where((b) => b.divergedFromNodeId == node.nodeId).toList();
    
    if (forksAtThisNode.isNotEmpty) {
      // Add the node that leads up to the choice
      items.add(_NormalItem(node));

      // Create the Junction
      // The options are: the current path's continuation OR any of the forks
      final options = _branchOptionsAt(plan, node);
      
      // Determine which branch to "label" the junction with.
      // If our active branch is one of the forks, show that. 
      // Otherwise, show the base branch.
      final activeOption = options.firstWhere(
        (o) => ancestorBranchIds.contains(o.branchId) && o.branchId != node.branchId,
        orElse: () => options.firstWhere((o) => o.branchId == node.branchId)
      );

      // Find the representative node for the junction card
      PlanNode junctionNode;
      if (activeOption.branchId == node.branchId) {
        // Show the next node in the current branch
        final continuation = plan.nodes
            .where((n) => n.branchId == node.branchId && n.nodeNumber > node.nodeNumber)
            .toList()..sort((a, b) => a.nodeNumber.compareTo(b.nodeNumber));
        
        if (continuation.isNotEmpty) {
          junctionNode = continuation.first;
          items.add(_BranchJunctionItem(activeOption, junctionNode, options));
        }
      } else {
        // Show the first node of the selected fork
        junctionNode = plan.nodes.firstWhere((n) => n.nodeId == activeOption.firstNodeId);
        items.add(_BranchJunctionItem(activeOption, junctionNode, options));
      }
    } else {
      // Regular node with no forks - only add if it wasn't just handled by a junction
      if (!items.any((item) => item is _BranchJunctionItem && item.firstNode.nodeId == node.nodeId)) {
        items.add(_NormalItem(node));
      }
    }
  }

  // Final Pass: Remove duplicate nodes that might have been added by _resolveActivePath
  // but are already displayed inside a BranchJunctionWidget.
  final finalItems = <_RoadmapItem>[];
  final Set<String> seenNodeIds = {};

  for (var item in items) {
    String id = (item is _NormalItem) ? item.node.nodeId : (item as _BranchJunctionItem).firstNode.nodeId;
    if (!seenNodeIds.contains(id)) {
      finalItems.add(item);
      seenNodeIds.add(id);
    }
  }

  return finalItems;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopNav(),
      drawer: const AppDrawer(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.gradientBackground),
          ),
          _error != null
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
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : _buildList(_plan!),
          // ── Node detail overlay ──────────────────────────────────────────
          if (_selectedNode != null && _plan != null) ...[
            // Dark barrier — only tappable to dismiss when card is visible
            if (!_planCardCollapsed)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _dismissNodeOverlay,
                  child: Container(color: Colors.black54),
                ),
              ),
            // Full PlanCard (hidden once chat starts)
            if (!_planCardCollapsed)
              Positioned(
                left: 16,
                right: 16,
                top: 24,
                bottom: 88,
                child: SingleChildScrollView(
                  child: PlanCard(
                    planId: widget.planId,
                    title: _selectedNode!.title,
                    description: '',
                    cardColor: Color(_plan!.primaryColorValue),
                    currentTask: _selectedNode!.title,
                    currentStep: _selectedNode!.nodeNumber - 1,
                    totalSteps: _plan!.nodes.length,
                    nodeDescription: _selectedNode!.description.isNotEmpty
                        ? _selectedNode!.description
                        : null,
                    resources: _selectedNode!.resources,
                    notes: _selectedNode!.notes,
                    currentNodeId: _selectedNode!.nodeId,
                    startExpanded: true,
                    onClose: _dismissNodeOverlay,
                    onMarkComplete: () {
                      final planId = widget.planId;
                      final nodeId = _selectedNode!.nodeId;
                      _dismissNodeOverlay();
                      if (planId != null) {
                        context
                            .read<PlansProvider>()
                            .logProgress(planId, nodeId, status: 'completed')
                            .then((_) {
                          if (mounted) _loadPlan();
                        });
                      }
                    },
                    onAddNote: () {
                      final planId = widget.planId;
                      final nodeId = _selectedNode!.nodeId;
                      if (planId == null) return;
                      QuickNoteDialog.show(context).then((content) {
                        if (content == null || content.isEmpty) return;
                        context
                            .read<PlansProvider>()
                            .addNote(planId, nodeId, content)
                            .then((_) {
                          if (mounted) _loadPlan();
                        });
                      });
                    },
                  ),
                ),
              ),
            // Mini strip shown when the card collapses for chat
            if (_planCardCollapsed)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 56,
                child: _buildMiniStrip(),
              ),
            // ChatOverlay — always present when a node is selected
            if (widget.planId != null)
              Positioned.fill(
                key: const ValueKey('roadmap_chat_overlay'),
                child: ChatOverlay(
                  planTitle: _selectedNode!.title,
                  planId: widget.planId,
                  planCardColor: Color(_plan!.primaryColorValue),
                  nodeId: _selectedNode!.nodeId,
                  nodeTitle: _selectedNode!.title,
                  nodeNumber: _selectedNode!.nodeNumber,
                  onPlanChatStarted: () =>
                      setState(() => _planCardCollapsed = true),
                  onPlanChatDismissed: () {
                    setState(() => _planCardCollapsed = false);
                  },
                  onPlanUpdated: () => _loadPlan(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStrip() {
    return Container(
      color: AppColors.background.withValues(alpha: 0.96),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined,
              color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedNode?.title ?? '',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
                onTap: () => _showNodeDetail(node),
              ),
            _BranchJunctionItem(
                  :final branch,
                  :final firstNode,
                  :final relatedBranches) =>
              BranchJunctionWidget(
                key: ValueKey('junction_${branch.branchId}'),
                branch: branch,
                branchNode: firstNode,
                relatedBranches: relatedBranches,
                activeBranchId: _activeBranchId,
                onBranchSwitch: _switchBranch,
                isLast: i == items.length - 1,
                displayNumber: i + 1,
                onNodeTap: () => _showNodeDetail(firstNode),
              ),
          },
      ],
    );
  }
}
