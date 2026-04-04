import 'package:flutter/material.dart';
import 'package:lattice/themes/app_colors.dart'; // Adjust path if needed

class PlanCard extends StatefulWidget {
  final String title;
  final String description;
  final Color cardColor;
  final int streak;
  final String currentTask;
  final int currentStep;
  final int totalSteps;
  // Controls the aspect ratio of the card when it is collapsed.
  // 1.0 = Perfect Square, 1.8 = Widescreen Rectangle, 2.0 = Very Wide Rectangle
  final double collapsedAspectRatio;
  // If provided, overrides the internal expand/collapse toggle on tap.
  final VoidCallback? onTap;
  // If true, the card animates open immediately after mounting.
  final bool startExpanded;
  // Called whenever the expanded state changes.
  final ValueChanged<bool>? onExpandChanged;

  const PlanCard({
    super.key,
    required this.title,
    required this.description,
    required this.cardColor,
    this.streak = 0,
    this.currentTask = '',
    this.currentStep = 0,
    this.totalSteps = 0,
    this.collapsedAspectRatio = 1.45,
    this.onTap,
    this.startExpanded = false,
    this.onExpandChanged,
  });

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> {
  late bool _isExpanded;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
    if (widget.startExpanded) {
      // Defer so the widget is laid out first, letting AnimatedCrossFade
      // animate from collapsed → expanded rather than starting expanded.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isExpanded = true);
      });
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpandChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? _toggleExpand,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use actual available width instead of MediaQuery so the card
            // measures correctly regardless of what container it lives in.
            final double innerCollapsedHeight =
                (constraints.maxWidth / widget.collapsedAspectRatio) - 40;
            return ClipRect(
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.topCenter,
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                sizeCurve: Curves.easeInOut,
                firstChild: SizedBox(
                  height: innerCollapsedHeight,
                  width: double.infinity,
                  child: _buildCollapsedContent(),
                ),
                secondChild: _buildExpandedContent(),
              ),
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
                const Text('TODO:', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${widget.currentStep}/${widget.totalSteps}', style: const TextStyle(color: AppColors.secondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.currentTask,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.background),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Text('🔥 ${widget.streak}', style: const TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required List<String> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── COLLAPSED STATE (List View) ──────────────────────────────────────────

  Widget _buildCollapsedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        // Expanded forces the description to take up any empty vertical space,
        // which pins the TODO pill cleanly to the bottom of the container.
        Text(
            widget.description,
            overflow: TextOverflow.fade, // Gracefully fades out text if it's too long for the ratio
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              height: 1.3,
            ),
          
        ),
        const SizedBox(height: 8),
        _buildTodoPill(),
      ],
    );
  }

  // ─── EXPANDED STATE (Detail View) ─────────────────────────────────────────

  Widget _buildExpandedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min, 
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.black87),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.description,
          style: const TextStyle(color: Colors.black87, fontSize: 18, height: 1.3),
        ),
        const SizedBox(height: 20),

        _buildTodoPill(),
        
        const SizedBox(height: 16),

        _buildInfoCard(
          title: 'What To Do:',
          items: [
            'Focus on cross-hair placement',
            'Attempt counter strafing techniques learned from task 7/30',
          ],
        ),
        const SizedBox(height: 16),

        _buildInfoCard(
          title: 'Resources:',
          items: [
            'YouTube: Counter Strafing',
            'Event: School of Mines Esports Valorant Championship',
          ],
        ),
        const SizedBox(height: 24),

        Center(
          child: Listener(
            onPointerDown: (_) => setState(() => _isButtonPressed = true),
            onPointerUp: (_) => setState(() => _isButtonPressed = false),
            onPointerCancel: (_) => setState(() => _isButtonPressed = false),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(
                top: _isButtonPressed ? 6 : 0,
                bottom: _isButtonPressed ? 0 : 6,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _isButtonPressed
                      ? []
                      : const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(0, 6),
                            blurRadius: 0,
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // Navigation logic here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5B73),
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                  child: const Text(
                    'View Roadmap',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}