import 'package:flutter/material.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/plan_input_bar.dart';
import 'package:lattice/widgets/topnav.dart';

// ── Placeholder plan data ────────────────────────────────────────────────────
// Replace with real plan model once available.
class _PlaceholderPlan {
  final String title;
  final String description;
  final Color color;
  const _PlaceholderPlan(this.title, this.description, this.color);
}

const _placeholderPlans = [
  _PlaceholderPlan('Learning Blender', 'Master 3D modeling, sculpting, and animation with hands-on projects.', Color(0xFF6A9F6B)),
  _PlaceholderPlan('Building Computers', 'Learn to select components, assemble, and configure a custom PC.', Color(0xFF8FAFD4)),
  _PlaceholderPlan('Meal Planning', 'Build weekly meal habits with balanced nutrition and prep strategies.', Color(0xFFE8A0B4)),
  _PlaceholderPlan('Exercise Routine', 'Develop a consistent strength and cardio regimen tailored to your goals.', Color(0xFFF5F0E1)),
  _PlaceholderPlan('Valorant Training', 'Improve aim, game sense, and agent mechanics through structured drills.', Color(0xFFBFA2DB)),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  // GlobalKeys to measure the body Stack and the front card's render bounds.
  final GlobalKey _bodyStackKey = GlobalKey();
  final GlobalKey _frontCardKey = GlobalKey();

  late List<int> _cardOrder;

  // Animation for the swipe-down dismiss of the front card.
  // Drives from current drag position to off-screen.
  late AnimationController _swipeController;
  double _swipeStartDy = 0;
  static const double _swipeEndDy = 600;

  // Animate remaining cards shifting forward after a swipe.
  late AnimationController _shiftController;

  double _dragDy = 0;

  // Whether the expanded overlay is showing.
  bool _isFrontCardExpanded = false;
  // True once the overlay should animate to fill the screen.
  bool _overlayExpanded = false;
  // The card's rect (in body Stack coordinates) captured at tap time.
  Rect _cardRect = Rect.zero;
  Size _bodySize = Size.zero;

  @override
  void initState() {
    super.initState();
    _cardOrder = List.generate(_placeholderPlans.length, (i) => i);

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _shiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _shiftController.dispose();
    super.dispose();
  }

  // ── Swipe handling ─────────────────────────────────────────────────────────

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_isFrontCardExpanded) return;
    setState(() => _dragDy = (_dragDy + d.delta.dy).clamp(0, double.infinity));
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_isFrontCardExpanded) return;
    final velocity = d.primaryVelocity ?? 0;
    if (_dragDy > 80 || velocity > 800) {
      _dismissFrontCard();
    } else {
      setState(() => _dragDy = 0);
    }
  }

  Future<void> _dismissFrontCard() async {
    // Animate from current drag position to off-screen — no jump.
    _swipeStartDy = _dragDy;
    await _swipeController.forward(from: 0);

    setState(() {
      final front = _cardOrder.removeAt(0);
      _cardOrder.add(front);
      _dragDy = 0;
    });

    _swipeController.reset();
    await _shiftController.forward(from: 0);
  }

  void _onFrontCardTap() {
    if (_isFrontCardExpanded) return;

    // Measure the front card's position within the body Stack.
    final bodyBox =
        _bodyStackKey.currentContext?.findRenderObject() as RenderBox?;
    final cardBox =
        _frontCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (bodyBox == null || cardBox == null) return;

    final cardOffset = bodyBox.globalToLocal(cardBox.localToGlobal(Offset.zero));
    setState(() {
      _cardRect = cardOffset & cardBox.size;
      _bodySize = bodyBox.size;
      _isFrontCardExpanded = true;
      _overlayExpanded = false; // overlay starts at card position…
    });

    // …then on the next frame, animate it to full screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _overlayExpanded = true);
    });
  }

  void _dismissExpandedCard() {
    // Animate the overlay back to the card's original position…
    setState(() => _overlayExpanded = false);
    // …then remove it once the animation finishes.
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _isFrontCardExpanded = false);
    });
  }

  // ── Card stack builder ─────────────────────────────────────────────────────

  static const int _maxVisible = 5;
  static const double _cardHeight = 260;
  static const double _cardHPadding = 28;
  static const double _stackGap = 50;
  static const double _scaleStep = 0.03;

  Widget _buildCardStack() {
    final visible = _cardOrder.take(_maxVisible).toList();
    // Back cards sit above the front card. The topmost back card is at
    // top: 0, and the front card's top edge is at (_maxVisible - 1) * _stackGap.
    const frontTop = _stackGap * (_maxVisible - 1);
    const totalStackHeight = frontTop + _cardHeight;

    return SizedBox(
      height: totalStackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = visible.length - 1; i >= 0; i--)
            _buildPositionedCard(i, visible[i], frontTop),
        ],
      ),
    );
  }

  Widget _buildPositionedCard(int stackIndex, int planIndex, double frontTop) {
    final isFront = stackIndex == 0;

    Widget buildCard(int pIndex, {Key? key, VoidCallback? onTap}) {
      final plan = _placeholderPlans[pIndex];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: PlanCard(
          key: key,
          title: plan.title,
          description: plan.description,
          cardColor: plan.color,
          onTap: onTap,
        ),
      );
    }

    if (isFront) {
      return AnimatedBuilder(
        animation: Listenable.merge([_swipeController, _shiftController]),
        builder: (context, _) {
          final dy = _swipeController.isAnimating
              ? _swipeStartDy +
                  (_swipeEndDy - _swipeStartDy) *
                      Curves.easeIn.transform(_swipeController.value)
              : _dragDy;

          // Fade to invisible while the overlay is open so the card stays in
          // place in the layout (no snapping) but isn't drawn twice.
          final swipeOpacity = _swipeController.isAnimating
              ? 1.0 - Curves.easeIn.transform(_swipeController.value)
              : 1.0;
          final opacity = _isFrontCardExpanded ? 0.0 : swipeOpacity;

          // During shift animation, the new front card slides down from
          // its old position (one gap above) into the front position.
          final shiftT = _shiftController.value;
          final top = _shiftController.isAnimating
              ? frontTop - _stackGap * (1.0 - shiftT)
              : frontTop;
          final scale = _shiftController.isAnimating
              ? (1.0 - _scaleStep) + _scaleStep * shiftT
              : 1.0;

          // Outer GestureDetector handles swipe-down only.
          // PlanCard's onTap handles tap-to-expand via _onFrontCardTap.
          final card = GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: buildCard(_cardOrder[0],
                key: _frontCardKey, onTap: _onFrontCardTap),
          );
          return Positioned(
            top: top,
            left: 0,
            right: 0,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Opacity(opacity: opacity, child: card),
              ),
            ),
          );
        },
      );
    }

    // Back cards: not interactive — IgnorePointer prevents their internal
    // GestureDetectors from consuming touch events.
    return AnimatedBuilder(
      animation: _shiftController,
      builder: (context, _) {
        final newTop = frontTop - stackIndex * _stackGap;
        final newScale = 1.0 - stackIndex * _scaleStep;

        double top;
        double s;
        if (_shiftController.isAnimating) {
          final oldTop = frontTop - (stackIndex + 1) * _stackGap;
          top = oldTop + (newTop - oldTop) * _shiftController.value;
          final oldScale = 1.0 - (stackIndex + 1) * _scaleStep;
          s = oldScale + (newScale - oldScale) * _shiftController.value;
        } else {
          top = newTop;
          s = newScale;
        }

        return Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Transform.scale(
            scale: s,
            alignment: Alignment.topCenter,
            child: IgnorePointer(child: buildCard(_cardOrder[stackIndex])),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Precompute overlay bottom margin for the dismissed (card-position) state.
    // Horizontal dimensions are never animated — only top/bottom expand.
    final overlayBottom =
        _bodySize.height > 0 ? _bodySize.height - _cardRect.bottom : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopNav(),
      drawer: const AppDrawer(),
      body: Stack(
        key: _bodyStackKey,
        children: [
          // ── Title + card stack ──────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title fades out while the overlay is open.
              AnimatedOpacity(
                opacity: _isFrontCardExpanded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 28.0, top: 25.0),
                    child: Text(
                      'Explore\nYour\nPlans',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              _buildCardStack(),
              const Spacer(),
            ],
          ),

          const PlanInputBar(),
        ],
      ),
    );
  }
}
