import 'package:flutter/material.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/themes/app_colors.dart';

class BranchJunctionWidget extends StatelessWidget {
  final Branch branch;
  final PlanNode branchNode;
  final List<Branch> relatedBranches;
  final String activeBranchId;
  final ValueChanged<String> onBranchSwitch;
  final bool isLast;
  final int displayNumber;

  const BranchJunctionWidget({
    super.key,
    required this.branch,
    required this.branchNode,
    required this.relatedBranches,
    required this.activeBranchId,
    required this.onBranchSwitch,
    required this.isLast,
    required this.displayNumber,
  });

  Color get _statusColor {
    switch (branchNode.status) {
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

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    final circleSize  = w * 0.112;
    final leftColW    = w * 0.143;
    final hGap        = w * 0.031;
    final cardPadding = w * 0.036;
    final nodeSpacing = w * 0.061;
    final titleSize   = w * 0.038;
    final descSize    = w * 0.033;
    final lineW       = w * 0.005;
    final openingH    = w * 0.115;
    final closingH    = w * 0.08;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Opening elbow ─────────────────────────────────────────────────────
        // Left vertical stub (0 → mid) connects the preceding node's line to
        // the horizontal. The horizontal goes right. A right vertical (mid →
        // bottom) descends to the very top of the branch circle in the row
        // below, so there is no gap between the elbow and the circle.
        SizedBox(
          height: openingH,
          child: Stack(
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: _OpeningElbowPainter(
                    leftColWidth: leftColW,
                    color: AppColors.connectorLine,
                    strokeWidth: lineW,
                  ),
                ),
              ),
              Center(child: _branchesDropdown(w)),
            ],
          ),
        ),

        // ── Branch node row ───────────────────────────────────────────────────
        // Left column is intentionally empty — the path goes predecessor →
        // (right via elbow) → branch circle → (left via closing elbow) → next
        // node, so there must be no direct left-column line bypassing the circle.
        //
        // Right column mirrors a normal node's left column: circle at the top,
        // then a vertical line below it (if not last) that feeds into the
        // closing elbow.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: empty — no bypass line
              SizedBox(width: leftColW),
              SizedBox(width: hGap),

              // Branch node card
              Expanded(
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
                      Text(
                        branchNode.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: titleSize,
                        ),
                      ),
                      if (branchNode.description.isNotEmpty) ...[
                        SizedBox(height: w * 0.015),
                        Text(
                          branchNode.description,
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
              SizedBox(width: hGap),

              // Right column: circle + line below (mirrors normal node's left col)
              SizedBox(
                width: leftColW,
                child: Column(
                  children: [
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: branchNode.status == NodeStatus.completed
                            ? _statusColor
                            : Colors.transparent,
                        border: Border.all(
                          color: _statusColor,
                          width: w * 0.006,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$displayNumber',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.043,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Center(
                          child: Container(
                            width: lineW,
                            color: AppColors.connectorLine,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Closing elbow ─────────────────────────────────────────────────────
        // The right vertical (top → connectorY) connects directly to the line
        // coming out of the bottom of the branch circle above. The horizontal
        // closes the bracket back to the left column. The left vertical
        // (connectorY → bottom) starts the main-path line for the next node;
        // the extra nodeSpacing height keeps that line unbroken into the gap
        // before the next item.
        if (!isLast)
          SizedBox(
            height: closingH + nodeSpacing,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _ClosingElbowPainter(
                  leftColWidth: leftColW,
                  color: AppColors.connectorLine,
                  strokeWidth: lineW,
                  connectorY: closingH / 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _branchesDropdown(double w) {
    return PopupMenuButton<String>(
      onSelected: onBranchSwitch,
      color: AppColors.cardBackground,
      itemBuilder: (context) => relatedBranches
          .map(
            (b) => PopupMenuItem<String>(
              value: b.branchId,
              child: Row(
                children: [
                  if (b.branchId == activeBranchId)
                    Padding(
                      padding: EdgeInsets.only(right: w * 0.02),
                      child: Icon(
                        Icons.check_rounded,
                        size: w * 0.04,
                        color: AppColors.accent,
                      ),
                    ),
                  Text(
                    b.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: w * 0.035,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.025,
          vertical: w * 0.015,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(w * 0.02),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_rounded,
              size: w * 0.038,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: w * 0.015),
            Text(
              'Branches',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: w * 0.033,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: w * 0.008),
            Icon(
              Icons.expand_more_rounded,
              size: w * 0.045,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

/// Opening (top) elbow — ├──────┐
///
///   │   ← left stub  (lx, 0) → (lx, mid)        connects to preceding node
///   ├── ← horizontal (lx, mid) → (rx, mid)       branch forks right
///       → right drop (rx, mid) → (rx, height)    descends to branch circle top
class _OpeningElbowPainter extends CustomPainter {
  final double leftColWidth;
  final Color color;
  final double strokeWidth;

  const _OpeningElbowPainter({
    required this.leftColWidth,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lx = leftColWidth / 2;
    final rx = size.width - leftColWidth / 2;
    final my = size.height / 2;
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(lx, 0), Offset(lx, my), p);         // left stub down to horizontal
    canvas.drawLine(Offset(lx, my), Offset(rx, my), p);         // horizontal right
    canvas.drawLine(Offset(rx, my), Offset(rx, size.height), p); // right drop to circle top
  }

  @override
  bool shouldRepaint(_OpeningElbowPainter old) =>
      old.leftColWidth != leftColWidth ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Closing (bottom) elbow — └──────┤
///
///       → right stub (rx, 0) → (rx, connectorY)  connects from circle's line
///   └── ← horizontal (lx, connectorY) → (rx, connectorY)
///   │   ← left drop  (lx, connectorY) → (lx, height)   continues to next node
///                     (height includes nodeSpacing so the line stays unbroken)
class _ClosingElbowPainter extends CustomPainter {
  final double leftColWidth;
  final Color color;
  final double strokeWidth;
  final double connectorY;

  const _ClosingElbowPainter({
    required this.leftColWidth,
    required this.color,
    required this.strokeWidth,
    required this.connectorY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lx = leftColWidth / 2;
    final rx = size.width - leftColWidth / 2;
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(rx, 0), Offset(rx, connectorY), p);           // right stub down to horizontal
    canvas.drawLine(Offset(lx, connectorY), Offset(rx, connectorY), p);  // horizontal left
    canvas.drawLine(Offset(lx, connectorY), Offset(lx, size.height), p); // left drop to next node
  }

  @override
  bool shouldRepaint(_ClosingElbowPainter old) =>
      old.leftColWidth != leftColWidth ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.connectorY != connectorY;
}
