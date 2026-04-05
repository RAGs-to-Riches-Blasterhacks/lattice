import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/navigation/app_navigation.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/action_button.dart';
import 'package:lattice/widgets/nav_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'celebration.dart';

class PlanCard extends StatefulWidget {
  final String? planId;
  final String title;
  final String description;
  final Color cardColor;
  final int streak;
  final String currentTask;
  final int currentStep;
  final int totalSteps;
  final String? nodeDescription;
  final List<Resource> resources;
  final List<NodeNote> notes;

  /// The node ID of the current (active) node for quick actions.
  final String? currentNodeId;
  // Controls the aspect ratio of the card when it is collapsed.
  // 1.0 = Perfect Square, 1.8 = Widescreen Rectangle, 2.0 = Very Wide Rectangle
  final double collapsedAspectRatio;
  // If provided, overrides the internal expand/collapse toggle on tap.
  final VoidCallback? onTap;
  // If true, the card animates open immediately after mounting.
  final bool startExpanded;
  // Called whenever the expanded state changes.
  final ValueChanged<bool>? onExpandChanged;

  /// Called when the user taps "Mark Done" on the expanded card.
  final VoidCallback? onMarkComplete;

  /// When true, hides the "Mark Done" button (node is already completed).
  final bool nodeCompleted;

  /// Called when the user taps "Add Note" on the expanded card.
  final VoidCallback? onAddNote;

  /// When provided, the header shows an X button instead of a collapse arrow,
  /// and tapping the card body does not toggle expand/collapse.
  final VoidCallback? onClose;

  const PlanCard({
    super.key,
    this.planId,
    required this.title,
    required this.description,
    required this.cardColor,
    this.streak = 0,
    this.currentTask = '',
    this.currentStep = 0,
    this.totalSteps = 0,
    this.nodeDescription,
    this.resources = const [],
    this.notes = const [],
    this.currentNodeId,
    this.collapsedAspectRatio = 1.45,
    this.onTap,
    this.startExpanded = false,
    this.onExpandChanged,
    this.onMarkComplete,
    this.nodeCompleted = false,
    this.onAddNote,
    this.onClose,
  });

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  bool _isExpanded = false;
  bool _markedDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (widget.startExpanded || widget.onClose != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isExpanded = true);
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onExpandChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? tapHandler =
        widget.onClose != null ? null : (widget.onTap ?? _toggleExpand);
    final double screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: tapHandler,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        constraints: _isExpanded
            ? BoxConstraints(maxHeight: screenHeight * 0.9)
            : const BoxConstraints(),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double innerCollapsedHeight =
                (constraints.maxWidth / widget.collapsedAspectRatio) - 40;

            return AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                // The extra content is animated via Align(heightFactor) + FadeTransition.
                // Persistent content (title, description, pill) is always present so it
                // never snaps or jumps — only the extra content slides/fades in and out.
                return ClipRect(
                  child: ConstrainedBox(
                    // Enforce the collapsed aspect-ratio height when collapsed,
                    // and smoothly relax it as the card expands.
                    constraints: BoxConstraints(
                      minHeight: innerCollapsedHeight * (1.0 - _anim.value),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title row ───────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                            // Collapse/close icon fades in with the expanded content.
                            FadeTransition(
                              opacity: _anim,
                              child: widget.onClose != null
                                  ? GestureDetector(
                                      onTap: widget.onClose,
                                      child: const Icon(Icons.close,
                                          size: 32, color: Colors.black87),
                                    )
                                  :const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 32,
                                          color: Colors.black87),
                                    
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ── Description ─────────────────────────────────────
                        if (widget.description.isNotEmpty) ...[
                          Text(
                            widget.description,
                            maxLines: _isExpanded ? null : 2,
                            overflow: _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // ── TODO pill ────────────────────────────────────────
                        _buildTodoPill(),
                        // ── Extra expanded content (animated) ────────────────
                        ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: _anim.value,
                            child: FadeTransition(
                              opacity: _anim,
                              child: _buildExtraContent(screenHeight),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────────

  Widget _buildTodoPill() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A7C94),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('TODO:',
                    style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                Text('${widget.currentStep < widget.totalSteps ? widget.currentStep + 1 : widget.totalSteps}/${widget.totalSteps}',
                    style: const TextStyle(
                        color: AppColors.secondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.currentTask,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.background),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: Text('🔥 ${widget.streak}',
                style: TextStyle(fontSize: 20, color: AppColors.background),
          ),
          ),
        ],
      ),
    );
  }

  // ─── EXTRA EXPANDED CONTENT ───────────────────────────────────────────────
  // Everything below the persistent header (title, description, pill).

  Widget _buildExtraContent(double screenHeight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Quick actions (static, not scrolled) ────────────────────────────
        if (widget.currentNodeId != null &&
            (_showMarkDone || widget.onAddNote != null)) ...[
          const SizedBox(height: 12),
          _buildQuickActions(),
        ],
        const SizedBox(height: 16),
        // ── Scrollable sections (What To Do / Resources / Notes) ────────────
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.4),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.nodeDescription != null &&
                    widget.nodeDescription!.isNotEmpty) ...[
                  _CollapsibleSection(
                    title: 'What To Do',
                    expandedContent: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(
                          child: Text(
                            widget.nodeDescription!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (widget.resources.isNotEmpty) ...[
                  _CollapsibleSection(
                    title: 'Resources',
                    expandedContent: Column(
                      children: widget.resources
                          .map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: GestureDetector(
                                  onTap: () => launchUrl(Uri.parse(r.url),
                                      mode: LaunchMode.externalApplication),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${_resourceIcon(r.type)} ',
                                          style: const TextStyle(fontSize: 16)),
                                      Expanded(
                                        child: Text(
                                          r.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                _CollapsibleSection(
                  title: 'Notes',
                  expandedContent: widget.notes.isEmpty
                      ? const Text(
                          'No notes yet.',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black54),
                        )
                      : Column(
                          children: widget.notes
                              .map((n) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.content,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('MMM d, h:mm a')
                                              .format(n.createdAt.toLocal()),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
        // ── View Roadmap button (static, not scrolled) ───────────────────────
        if (widget.onClose == null) ...[
          const SizedBox(height: 8),
          NavButton(
            label: 'View Roadmap',
            onPressed: () {
              AppNavigation.goToRoadmap(context, planId: widget.planId);
            },
          ),
        ],
      ],
    );
  }

  // ─── QUICK ACTION BUTTONS ─────────────────────────────────────────────────

  bool get _showMarkDone =>
      widget.onMarkComplete != null && !widget.nodeCompleted && !_markedDone;

  Widget _buildQuickActions() {
    return Row(
      children: [
        if (_showMarkDone)
          Expanded(
            child: ActionButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Mark Done',
              color: const Color(0xFF4CAF50),
              onTap: () {
                setState(() => _markedDone = true);
                widget.onMarkComplete!();
                CelebrationOverlay.show(context);
              },
            ),
          ),
        if (_showMarkDone && widget.onAddNote != null)
          const SizedBox(width: 10),
        if (widget.onAddNote != null)
          Expanded(
            child: ActionButton(
              icon: Icons.note_add_outlined,
              label: 'Add Note',
              color: const Color(0xFF4A7C94),
              onTap: widget.onAddNote!,
            ),
          ),
      ],
    );
  }

  String _resourceIcon(ResourceType type) {
    switch (type) {
      case ResourceType.youtube:
        return '▶';
      case ResourceType.article:
        return '📄';
      case ResourceType.book:
        return '📖';
      case ResourceType.exercise:
        return '💪';
      case ResourceType.event:
        return '📅';
    }
  }
}

/// A collapsible section card used in the expanded PlanCard detail view.
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget expandedContent;

  const _CollapsibleSection({
    required this.title,
    required this.expandedContent,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.title}: . . .',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_up, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              widget.expandedContent,
            ],
          ),
        ),
      ),
    );
  }
}

