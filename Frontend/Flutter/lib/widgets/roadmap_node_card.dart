import 'package:flutter/material.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/themes/app_colors.dart';

class RoadmapNodeCard extends StatelessWidget {
  final PlanNode node;
  final bool isLast;
  final int displayNumber;
  final VoidCallback? onTap;

  const RoadmapNodeCard({
    super.key,
    required this.node,
    required this.isLast,
    required this.displayNumber,
    this.onTap,
  });

  Color get _statusColor {
    switch (node.status) {
      case NodeStatus.completed:
        return AppColors.nodeCompleted;
      case NodeStatus.in_progress:
        return AppColors.nodeInProgress;
      case NodeStatus.skipped:
        return AppColors.nodeSkipped;
      case NodeStatus.not_started:
        return AppColors.nodeNotStarted;
    }
  }

  List<ResourceType> get _uniqueResourceTypes {
    final seen = <ResourceType>{};
    return node.resources.map((r) => r.type).where(seen.add).toList();
  }

  Widget _resourceIcon(ResourceType type, double size) {
    final (IconData icon, Color color) = switch (type) {
      ResourceType.youtube => (
          Icons.smart_display_rounded,
          AppColors.iconYoutube
        ),
      ResourceType.book => (Icons.menu_book_rounded, AppColors.iconBook),
      ResourceType.article => (Icons.article_rounded, AppColors.iconArticle),
      ResourceType.exercise => (
          Icons.fitness_center_rounded,
          AppColors.iconExercise
        ),
      ResourceType.event => (Icons.event_rounded, AppColors.iconEvent),
    };

    return Padding(
      padding: EdgeInsets.only(left: size * 0.375),
      child: Icon(icon, size: size, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (node.isCheckpoint) {
      return _CheckpointBanner(node: node, isLast: isLast, onTap: onTap);
    }

    final w = MediaQuery.of(context).size.width;

    final circleSize = w * 0.112; // ≈44 @ 393px
    final leftColWidth = w * 0.143; // ≈56 @ 393px
    final hGap = w * 0.031; // ≈12 @ 393px
    final cardPadding = w * 0.036; // ≈14 @ 393px
    final nodeSpacing = w * 0.061; // ≈24 @ 393px
    final numberSize = w * 0.043; // ≈17 @ 393px
    final titleSize = w * 0.038; // ≈15 @ 393px
    final descSize = w * 0.033; // ≈13 @ 393px
    final iconSize = w * 0.041; // ≈16 @ 393px

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: numbered circle + connector line
          SizedBox(
            width: leftColWidth,
            child: Column(
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: node.status == NodeStatus.completed
                        ? _statusColor
                        : Colors.transparent,
                    border: Border.all(color: _statusColor, width: w * 0.006),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$displayNumber',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: numberSize,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: w * 0.005,
                        color: AppColors.connectorLine,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: hGap),
          // Right: node info card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : nodeSpacing),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(w * 0.031),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row + resource type icons
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              node.title,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: titleSize,
                              ),
                            ),
                          ),
                          ..._uniqueResourceTypes
                              .map((t) => _resourceIcon(t, iconSize)),
                        ],
                      ),
                      if (node.description.isNotEmpty) ...[
                        SizedBox(height: w * 0.015),
                        Text(
                          node.description,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: descSize,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckpointBanner extends StatelessWidget {
  final PlanNode node;
  final bool isLast;
  final VoidCallback? onTap;

  const _CheckpointBanner({
    required this.node,
    required this.isLast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final nodeSpacing = w * 0.061;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : nodeSpacing),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    node.title,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
