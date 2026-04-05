import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/action_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet that shows full details for a plan node and exposes
/// action callbacks for status changes and note creation.
class NodeDetailSheet extends StatefulWidget {
  final PlanNode node;
  final Future<void> Function(String status) onStatusChange;
  final Future<void> Function(String content) onAddNote;

  const NodeDetailSheet({
    super.key,
    required this.node,
    required this.onStatusChange,
    required this.onAddNote,
  });

  /// Show this sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required PlanNode node,
    required Future<void> Function(String status) onStatusChange,
    required Future<void> Function(String content) onAddNote,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NodeDetailSheet(
        node: node,
        onStatusChange: onStatusChange,
        onAddNote: onAddNote,
      ),
    );
  }

  @override
  State<NodeDetailSheet> createState() => _NodeDetailSheetState();
}

class _NodeDetailSheetState extends State<NodeDetailSheet> {
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleStatusChange(String status) async {
    setState(() => _submitting = true);
    try {
      await widget.onStatusChange(status);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleAddNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.onAddNote(text);
      _noteController.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _DragHandle(),
              const SizedBox(height: 12),
              _HeaderRow(node: widget.node),
              const SizedBox(height: 16),
              if (widget.node.description.isNotEmpty) ...[
                _DescriptionSection(
                  description: widget.node.description,
                ),
                const SizedBox(height: 16),
              ],
              if (widget.node.resources.isNotEmpty) ...[
                _ResourcesSection(
                  resources: widget.node.resources,
                ),
                const SizedBox(height: 16),
              ],
              _NotesSection(
                notes: widget.node.notes,
                controller: _noteController,
                submitting: _submitting,
                onSubmit: _handleAddNote,
              ),
              if (widget.node.activityLog.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ActivityLogSection(
                  entries: widget.node.activityLog,
                ),
              ],
              const SizedBox(height: 24),
              _ActionButtons(
                status: widget.node.status,
                submitting: _submitting,
                onStatusChange: _handleStatusChange,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Private widgets ─────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final PlanNode node;
  const _HeaderRow({required this.node});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            node.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StatusBadge(status: node.status),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final NodeStatus status;
  const _StatusBadge({required this.status});

  (String label, Color color) get _config => switch (status) {
        NodeStatus.not_started => ('Not Started', AppColors.nodeNotStarted),
        NodeStatus.in_progress => ('In Progress', AppColors.nodeInProgress),
        NodeStatus.completed => ('Completed', AppColors.nodeCompleted),
        NodeStatus.skipped => ('Skipped', AppColors.nodeSkipped),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String description;
  const _DescriptionSection({required this.description});

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

class _ResourcesSection extends StatelessWidget {
  final List<Resource> resources;
  const _ResourcesSection({required this.resources});

  IconData _icon(ResourceType type) => switch (type) {
        ResourceType.youtube => Icons.smart_display_rounded,
        ResourceType.article => Icons.article_rounded,
        ResourceType.book => Icons.menu_book_rounded,
        ResourceType.exercise => Icons.fitness_center_rounded,
        ResourceType.event => Icons.event_rounded,
      };

  Color _iconColor(ResourceType type) => switch (type) {
        ResourceType.youtube => AppColors.iconYoutube,
        ResourceType.article => AppColors.iconArticle,
        ResourceType.book => AppColors.iconBook,
        ResourceType.exercise => AppColors.iconExercise,
        ResourceType.event => AppColors.iconEvent,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resources',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...resources.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                final uri = Uri.tryParse(r.url);
                if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      _icon(r.type),
                      color: _iconColor(r.type),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.title,
                        style: const TextStyle(
                          color: AppColors.activeTab,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  final List<NodeNote> notes;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _NotesSection({
    required this.notes,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (notes.isNotEmpty)
          ...notes.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.content,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(n.createdAt.toLocal()),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.cardBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.cardBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: AppColors.accent,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityLogSection extends StatelessWidget {
  final List<ActivityEntry> entries;
  const _ActivityLogSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.circle,
                  size: 6,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.note ?? dateFormat.format(e.date.toLocal()),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  dateFormat.format(e.date.toLocal()),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final NodeStatus status;
  final bool submitting;
  final Future<void> Function(String status) onStatusChange;

  const _ActionButtons({
    required this.status,
    required this.submitting,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      NodeStatus.not_started => ActionButton(
          icon: Icons.play_arrow_rounded,
          label: 'Start Task',
          color: AppColors.accent,
          onTap: submitting ? null : () => onStatusChange('in_progress'),
          isLoading: submitting,
        ),
      NodeStatus.in_progress => Column(
          children: [
            ActionButton(
              icon: Icons.trending_up_rounded,
              label: 'Log Progress',
              color: AppColors.accent,
              onTap: submitting ? null : () => onStatusChange('in_progress'),
              isLoading: submitting,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Mark Complete',
                    color: AppColors.nodeCompleted,
                    onTap: submitting ? null : () => onStatusChange('completed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActionButton(
                    icon: Icons.skip_next_rounded,
                    label: 'Skip',
                    color: AppColors.nodeSkipped,
                    onTap: submitting ? null : () => onStatusChange('skipped'),
                  ),
                ),
              ],
            ),
          ],
        ),
      NodeStatus.completed => const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.nodeCompleted,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Completed',
                style: TextStyle(
                  color: AppColors.nodeCompleted,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      NodeStatus.skipped => const Center(
          child: Text(
            'Skipped',
            style: TextStyle(
              color: AppColors.nodeSkipped,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
    };
  }
}
