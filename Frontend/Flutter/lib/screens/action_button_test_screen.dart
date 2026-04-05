import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lattice/themes/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test screen — pick a style, then we'll move it to action_button.dart
// ─────────────────────────────────────────────────────────────────────────────

class ActionButtonTestScreen extends StatelessWidget {
  const ActionButtonTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Action Button Options',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.gradientBackground),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: const [
              _OptionSection(
                label: 'Option A — Neubrutalist',
                description:
                    'Hard black shadow, solid fill, press-down animation. Punchy, matches the existing PlanCard quick actions.',
                demo: _OptionADemo(),
              ),
              SizedBox(height: 28),
              _OptionSection(
                label: 'Option B — Dark Glass',
                description:
                    'cardBackground fill with a colored accent border + icon. Matches the roadmap node card surface language.',
                demo: _OptionBDemo(),
              ),
              SizedBox(height: 28),
              _OptionSection(
                label: 'Option C — Gradient Pill',
                description:
                    'Teal→green gradient, glow shadow, icon left of label. Consistent with NavButton and the input bar aesthetic.',
                demo: _OptionCDemo(),
              ),
              SizedBox(height: 28),
              _OptionSection(
                label: 'Option D — Minimal Outlined',
                description:
                    'Transparent fill, thin colored border, colored text. Clean and lightweight — pairs well with dense UIs.',
                demo: _OptionDDemo(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _OptionSection extends StatelessWidget {
  final String label;
  final String description;
  final Widget demo;

  const _OptionSection({
    required this.label,
    required this.description,
    required this.demo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.activeTab,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: demo,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option A — Neubrutalist
// ─────────────────────────────────────────────────────────────────────────────

class _OptionADemo extends StatelessWidget {
  const _OptionADemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NeubrutalistButton(
                icon: Icons.check_circle_outline_rounded,
                label: 'Mark Done',
                color: const Color(0xFF4CAF50),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NeubrutalistButton(
                icon: Icons.note_add_outlined,
                label: 'Add Note',
                color: AppColors.accent,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NeubrutalistButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start',
                color: AppColors.nodeInProgress,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NeubrutalistButton(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                color: const Color(0xFF9E9E9E),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeubrutalistButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NeubrutalistButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NeubrutalistButton> createState() => _NeubrutalistButtonState();
}

class _NeubrutalistButtonState extends State<_NeubrutalistButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 80),
          padding: EdgeInsets.only(
            top: _pressed ? 4 : 0,
            bottom: _pressed ? 0 : 4,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black, width: 2.5),
              boxShadow: _pressed
                  ? []
                  : const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option B — Dark Glass
// ─────────────────────────────────────────────────────────────────────────────

class _OptionBDemo extends StatelessWidget {
  const _OptionBDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DarkGlassButton(
                icon: Icons.check_circle_outline_rounded,
                label: 'Mark Done',
                color: const Color(0xFF4CAF50),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DarkGlassButton(
                icon: Icons.note_add_outlined,
                label: 'Add Note',
                color: AppColors.activeTab,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DarkGlassButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start',
                color: AppColors.accent,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DarkGlassButton(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                color: const Color(0xFF9E9E9E),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DarkGlassButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DarkGlassButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_DarkGlassButton> createState() => _DarkGlassButtonState();
}

class _DarkGlassButtonState extends State<_DarkGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: 0.18)
              : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.color.withValues(alpha: _pressed ? 0.9 : 0.55),
            width: 1.5,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.color, size: 18),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                color: widget.color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option C — Gradient Pill
// ─────────────────────────────────────────────────────────────────────────────

class _OptionCDemo extends StatelessWidget {
  const _OptionCDemo();

  static const _tealGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF00C9C8), Color(0xFF2EE6B0), Color(0xFF8FF5A8)],
    stops: [0.0, 0.55, 1.0],
  );

  static const _blueGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF33658A), Color(0xFF89BBFE)],
  );

  static const _grayGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF3A3A3A), Color(0xFF616161)],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _GradientPillActionButton(
                icon: Icons.check_circle_outline_rounded,
                label: 'Mark Done',
                gradient: _tealGradient,
                glowColor: const Color(0xFF00C9C8),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GradientPillActionButton(
                icon: Icons.note_add_outlined,
                label: 'Add Note',
                gradient: _blueGradient,
                glowColor: const Color(0xFF33658A),
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GradientPillActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start',
                gradient: _blueGradient,
                glowColor: AppColors.accent,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GradientPillActionButton(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                gradient: _grayGradient,
                glowColor: const Color(0xFF616161),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GradientPillActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final Color glowColor;
  final VoidCallback onTap;

  const _GradientPillActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_GradientPillActionButton> createState() =>
      _GradientPillActionButtonState();
}

class _GradientPillActionButtonState extends State<_GradientPillActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 46,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option D — Minimal Outlined
// ─────────────────────────────────────────────────────────────────────────────

class _OptionDDemo extends StatelessWidget {
  const _OptionDDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MinimalOutlinedButton(
                icon: Icons.check_circle_outline_rounded,
                label: 'Mark Done',
                color: const Color(0xFF4CAF50),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MinimalOutlinedButton(
                icon: Icons.note_add_outlined,
                label: 'Add Note',
                color: AppColors.activeTab,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MinimalOutlinedButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start',
                color: AppColors.accent,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MinimalOutlinedButton(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                color: const Color(0xFF9E9E9E),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MinimalOutlinedButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MinimalOutlinedButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MinimalOutlinedButton> createState() => _MinimalOutlinedButtonState();
}

class _MinimalOutlinedButtonState extends State<_MinimalOutlinedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: widget.color, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.color, size: 17),
            const SizedBox(width: 5),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                color: widget.color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
