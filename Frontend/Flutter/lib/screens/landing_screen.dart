import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lattice/navigation/app_navigation.dart';
import 'package:lattice/themes/app_colors.dart';

/// CTA button gradient, matching Figma.
class _LandingGradients {
  static const LinearGradient cta = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF00C9C8),
      Color(0xFF2EE6B0),
      Color(0xFF8FF5A8),
    ],
    stops: [0.0, 0.55, 1.0],
  );
}

class _MockLandingCard {
  const _MockLandingCard({
    required this.title,
    required this.description,
    required this.taskTitle,
    required this.todoDone,
    required this.todoTotal,
    required this.cardColor,
    this.streak,
  });

  final String title;
  final String description;
  final String taskTitle;
  final int todoDone;
  final int todoTotal;
  final Color cardColor;
  final int? streak;
}

const _mockCards = [
  _MockLandingCard(
    title: 'Meal Planning',
    description:
        'Build sustainable eating habits with weekly plans, macro tracking, and smart grocery lists.',
    taskTitle: 'Prep Chicken and Broccoli',
    todoDone: 1,
    todoTotal: 15,
    cardColor: Color(0xFFF28B95),
  ),
  _MockLandingCard(
    title: 'Valorant Training',
    description:
        'Level up movement, crosshair placement, and game sense with structured aim and deathmatch drills.',
    taskTitle: 'Play a round of deathmatch',
    todoDone: 8,
    todoTotal: 30,
    cardColor: Color(0xFFC3A6D4),
    streak: 8,
  ),
  _MockLandingCard(
    title: 'Learning Blender',
    description:
        'Master modeling, materials, and animation through project-based lessons from first mesh to final render.',
    taskTitle: 'Block out a simple scene',
    todoDone: 3,
    todoTotal: 20,
    cardColor: Color(0xFF8FAFD4),
  ),
  _MockLandingCard(
    title: 'Exercise Routine',
    description:
        'Design a balanced strength and cardio program you can stick to, with progressive overload built in.',
    taskTitle: 'Complete leg day checklist',
    todoDone: 5,
    todoTotal: 12,
    cardColor: Color(0xFFF5F0E1),
  ),
  _MockLandingCard(
    title: 'Building Computers',
    description:
        'Pick compatible parts, assemble confidently, and troubleshoot POST—your custom PC from cart to boot.',
    taskTitle: 'Research motherboard chipsets',
    todoDone: 2,
    todoTotal: 18,
    cardColor: Color(0xFF6A9F6B),
  ),
];

/// Lattice-style constellation: faint grid of nodes and edges.
class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({required this.animationValue});

  /// 0–1 subtle twinkle phase.
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 11;
    const rows = 20;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final rnd = math.Random(7);

    final points = <Offset>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = (c + 0.5) * cellW;
        final cy = (r + 0.5) * cellH;
        final jx = (rnd.nextDouble() - 0.5) * cellW * 0.55;
        final jy = (rnd.nextDouble() - 0.5) * cellH * 0.55;
        points.add(Offset(cx + jx, cy + jy));
      }
    }

    final linePaint = Paint()
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    void line(Offset a, Offset b, double opacity) {
      linePaint.color = Color.fromRGBO(120, 180, 255, opacity);
      canvas.drawLine(a, b, linePaint);
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final p = points[i];
        if (c < cols - 1) line(p, points[i + 1], 0.12);
        if (r < rows - 1) line(p, points[i + cols], 0.1);
        if (c < cols - 1 && r < rows - 1) {
          if ((c + r + i) % 5 == 0) line(p, points[i + cols + 1], 0.06);
        }
      }
    }

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final twinkle =
          0.5 + 0.5 * math.sin(animationValue * math.pi * 2 + i * 0.31);
      final isBright = i % 11 == 3 || i % 17 == 5;
      final base = isBright ? 0.55 : 0.18;
      final opacity = (base + twinkle * 0.25).clamp(0.08, 0.95);
      final radius = isBright ? 2.2 : 1.35;
      final dotPaint = Paint()
        ..color = isBright
            ? Color.fromRGBO(255, 255, 255, opacity)
            : Color.fromRGBO(100, 160, 255, opacity * 0.85);
      canvas.drawCircle(p, radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _twinkleController;

  /// 0→1 while snapping or auto-advancing [_pageSnapFrom] → [_pageSnapTo].
  late final AnimationController _pageSnapController;
  Timer? _autoAdvanceTimer;

  static const _autoAdvanceDuration = Duration(seconds: 4);

  /// Horizontal drag sensitivity (higher = less movement per px).
  static const _dragPixelsPerPage = 220.0;

  /// Large virtual range so the carousel loops; recenters when near edges.
  static const _carouselCenterNominal = 100000;
  static const _carouselHighWater = 180000;
  static const _carouselLowWater = 20000;
  static const _carouselRecenterBlock = 100000;

  double _page = 0;
  double _pageSnapFrom = 0;
  double _pageSnapTo = 0;

  /// When non-null, only that snap's [AnimationController] completion may settle the page.
  Object? _pageSnapSession;

  int get _n => _mockCards.length;

  int _dataIndexForVirtualPage(int virtualPage) => (virtualPage % _n + _n) % _n;

  @override
  void initState() {
    super.initState();
    _page = ((_carouselCenterNominal ~/ _n) * _n).toDouble();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pageSnapController = AnimationController(vsync: this)
      ..addListener(_onPageSnapTick);
    _scheduleAutoAdvance();
  }

  void _onPageSnapTick() {
    if (!mounted) return;
    final t = Curves.easeOutCubic.transform(_pageSnapController.value);
    setState(() {
      _page = _pageSnapFrom + (_pageSnapTo - _pageSnapFrom) * t;
    });
  }

  void _normalizeVirtualPageAfterSettle() {
    final settled = _page.round();
    final step = (_carouselRecenterBlock ~/ _n) * _n;
    if (step == 0) return;
    if (settled > _carouselHighWater) {
      setState(() => _page -= step);
    } else if (settled < _carouselLowWater) {
      setState(() => _page += step);
    }
  }

  void _animatePageTo(double target, {Duration? duration}) {
    _pageSnapController.stop();
    final session = Object();
    _pageSnapSession = session;
    _pageSnapFrom = _page;
    _pageSnapTo = target;
    _pageSnapController.duration =
        duration ?? const Duration(milliseconds: 420);
    _pageSnapController.forward(from: 0).whenComplete(() {
      if (!mounted || _pageSnapSession != session) return;
      _pageSnapSession = null;
      setState(() => _page = _pageSnapTo);
      _normalizeVirtualPageAfterSettle();
      _scheduleAutoAdvance();
    });
  }

  void _advanceCarousel() {
    if (!mounted) return;
    _animatePageTo(_page.round() + 1.0,
        duration: const Duration(milliseconds: 480));
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(_autoAdvanceDuration, () {
      if (!mounted) return;
      _advanceCarousel();
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageSnapController.removeListener(_onPageSnapTick);
    _pageSnapController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    AppNavigation.goToLogin(context);
  }

  void _goToSignUp() {
    AppNavigation.goToSignup(context);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 4,
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
              decoration:
                  BoxDecoration(gradient: AppColors.gradientBackground)),
          AnimatedBuilder(
            animation: _twinkleController,
            builder: (context, _) {
              return CustomPaint(
                painter: _ConstellationPainter(
                  animationValue: _twinkleController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text('Lattice', style: titleStyle),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      final cardW = maxW * 0.82;
                      const minScale = 0.3;
                      const maxExtraScale = 0.4;
                      const minOpacity = 0.35;
                      const maxExtraOpacity = 0.58;
                      final radius = cardW * 0.75;
                      final twoPiOnN = 2 * math.pi / _n;
                      final base = _page.floor();
                      final frac = _page - base;

                      final entries =
                          <({int dataIdx, double angle, double depth})>[];
                      for (var k = 0; k < _n; k++) {
                        final angle = twoPiOnN * (k - frac);
                        final depth = math.cos(angle);
                        final dataIdx = _dataIndexForVirtualPage(base + k);
                        entries.add(
                            (dataIdx: dataIdx, angle: angle, depth: depth));
                      }
                      entries.sort((a, b) => a.depth.compareTo(b.depth));

                      Widget cardAtAngle(
                          int dataIdx, double angle, double depth) {
                        final t = ((depth + 1) * 0.5).clamp(0.0, 1.0);
                        final scale = minScale + maxExtraScale * t;
                        final opacity = minOpacity + maxExtraOpacity * t;
                        final x = radius * math.sin(angle);
                        final y = radius * (math.cos(angle) - 1);
                        final tilt = math.sin(angle) * 0.11;

                        return Transform.translate(
                          offset: Offset(x, y),
                          child: Transform.rotate(
                            angle: tilt,
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.center,
                              child: Opacity(
                                opacity: opacity,
                                child: SizedBox(
                                  width: cardW,
                                  child: _LandingPlanCard(
                                    data: _mockCards[dataIdx],
                                    compact: false,
                                    showDescription: true,
                                    landingShort: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) {
                          _pageSnapController.stop();
                          _pageSnapSession = null;
                        },
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _page -= details.delta.dx / _dragPixelsPerPage;
                          });
                          _scheduleAutoAdvance();
                        },
                        onHorizontalDragEnd: (details) {
                          final vx = details.velocity.pixelsPerSecond.dx;
                          var target = _page.roundToDouble();
                          if (vx < -280) {
                            target = _page.floor() + 1.0;
                          } else if (vx > 280) {
                            target = _page.ceil() - 1.0;
                          }
                          _animatePageTo(target);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          alignment: const Alignment(0, 0.42),
                          children: [
                            for (final e in entries)
                              cardAtAngle(e.dataIdx, e.angle, e.depth),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Column(
                    children: [
                      _GradientPillButton(
                        label: 'Log In',
                        onPressed: _goToLogin,
                      ),
                      const SizedBox(height: 14),
                      _GradientPillButton(
                        label: 'Sign Up',
                        onPressed: _goToSignUp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingPlanCard extends StatelessWidget {
  const _LandingPlanCard({
    required this.data,
    this.compact = false,
    this.showDescription = true,
    this.landingShort = false,
  });

  final _MockLandingCard data;
  final bool compact;
  final bool showDescription;

  /// Compact landing layout (single-line TODO chip, tight padding; description optional via [showDescription]).
  final bool landingShort;

  static const _pillBlue = Color(0xFF2A4A6A);

  /// Landing carousel: width comes from parent; these constants only shave vertical space.
  static const _landingShortHeightFactor = 0.88;
  static const _landingPadY = 1.875 * _landingShortHeightFactor;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 16.0 : 20.0;
    final pad = landingShort
        ? const EdgeInsets.fromLTRB(6, _landingPadY, 6, _landingPadY)
        : compact
            ? const EdgeInsets.fromLTRB(14, 12, 14, 10)
            : const EdgeInsets.fromLTRB(20, 22, 20, 18);
    final titleSize = landingShort
        ? 13.25 * _landingShortHeightFactor
        : (compact ? 16.0 : 22.0);
    final descSize = landingShort
        ? 8.35 * _landingShortHeightFactor
        : (compact ? 10.5 : 13.0);
    final descMaxLines = landingShort ? 3 : (compact ? 2 : 4);
    final descLineHeight = landingShort ? 1.12 : 1.3;
    final gapTitleDesc = landingShort ? 2.0 : (compact ? 4.0 : 10.0);
    final gapBeforePill = landingShort
        ? 2.75 * _landingShortHeightFactor
        : (compact ? 8.0 : 18.0);
    final pillRadius = landingShort ? 12.0 : (compact ? 18.0 : 22.0);
    final badgeHPad = landingShort ? 7.0 : (compact ? 10.0 : 14.0);
    final badgeVPad =
        landingShort ? 2.5 * _landingShortHeightFactor : (compact ? 6.0 : 10.0);
    final todoLabelSize = compact ? 9.0 : 11.0;
    final todoFracSize = compact ? 10.0 : 12.0;
    final taskSize = landingShort
        ? 10.0 * _landingShortHeightFactor
        : (compact ? 12.0 : 14.0);
    final streakEmoji = landingShort
        ? 12.0 * _landingShortHeightFactor
        : (compact ? 15.0 : 18.0);
    final streakNum = landingShort
        ? 11.0 * _landingShortHeightFactor
        : (compact ? 13.0 : 16.0);
    final showDesc = showDescription;

    return Container(
      decoration: BoxDecoration(
        color: data.cardColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: compact ? 0.28 : 0.35),
            blurRadius: landingShort ? 8 : (compact ? 14 : 24),
            offset: Offset(0, landingShort ? 4 : (compact ? 8 : 14)),
          ),
        ],
      ),
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.title,
            maxLines: landingShort ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: landingShort ? 1.06 : 1.1,
            ),
          ),
          if (showDesc) ...[
            SizedBox(height: gapTitleDesc),
            Text(
              data.description,
              maxLines: descMaxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: descSize,
                height: descLineHeight,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.78),
              ),
            ),
          ],
          SizedBox(height: gapBeforePill),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(pillRadius),
            ),
            padding: EdgeInsets.symmetric(
              vertical: landingShort
                  ? 1.0 * _landingShortHeightFactor
                  : (compact ? 3 : 4),
              horizontal: landingShort ? 2 : (compact ? 3 : 4),
            ),
            child: landingShort
                ? Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: badgeHPad,
                          vertical: badgeVPad,
                        ),
                        decoration: BoxDecoration(
                          color: _pillBlue,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'TODO ${data.todoDone}/${data.todoTotal}',
                          style: GoogleFonts.inter(
                            fontSize: landingShort
                                ? 8.75 * _landingShortHeightFactor
                                : 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 10),
                      Expanded(
                        child: Text(
                          data.taskTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: taskSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF070405),
                          ),
                        ),
                      ),
                      if (data.streak != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥',
                                  style: TextStyle(fontSize: streakEmoji)),
                              Text(
                                '${data.streak}',
                                style: GoogleFonts.inter(
                                  fontSize: streakNum,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: badgeHPad,
                          vertical: badgeVPad,
                        ),
                        decoration: BoxDecoration(
                          color: _pillBlue,
                          borderRadius:
                              BorderRadius.circular(compact ? 14 : 18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TODO:',
                              style: GoogleFonts.inter(
                                fontSize: todoLabelSize,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${data.todoDone}/${data.todoTotal}',
                              style: GoogleFonts.inter(
                                fontSize: todoFracSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 12),
                      Expanded(
                        child: Text(
                          data.taskTitle,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: taskSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF070405),
                          ),
                        ),
                      ),
                      if (data.streak != null) ...[
                        Padding(
                          padding: EdgeInsets.only(right: compact ? 6 : 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥',
                                  style: TextStyle(fontSize: streakEmoji)),
                              const SizedBox(width: 2),
                              Text(
                                '${data.streak}',
                                style: GoogleFonts.inter(
                                  fontSize: streakNum,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GradientPillButton extends StatelessWidget {
  const _GradientPillButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: _LandingGradients.cta,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C9C8).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
