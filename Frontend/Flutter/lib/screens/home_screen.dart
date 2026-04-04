import 'package:flutter/material.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/topnav.dart';

// ── Placeholder plan data ────────────────────────────────────────────────────
// Replace with real plan model once available.
class _PlaceholderPlan {
  final String title;
  final Color color;
  const _PlaceholderPlan(this.title, this.color);
}

const _placeholderPlans = [
  _PlaceholderPlan('Learning Blender', Color(0xFF6A9F6B)),
  _PlaceholderPlan('Building Computers', Color(0xFF8FAFD4)),
  _PlaceholderPlan('Meal Planning', Color(0xFFE8A0B4)),
  _PlaceholderPlan('Exercise Routine', Color(0xFFF5F0E1)),
  _PlaceholderPlan('Valorant Training', Color(0xFFBFA2DB)),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  late List<int> _cardOrder;

  // Animation for the swipe-down dismiss of the front card.
  // Drives from current drag position to off-screen.
  late AnimationController _swipeController;
  double _swipeStartDy = 0;
  static const double _swipeEndDy = 600;

  // Animate remaining cards shifting forward after a swipe.
  late AnimationController _shiftController;

  double _dragDy = 0;

  // Whether the front card is expanded (tapped). The actual expand UI will
  // be handled by the PlanCard widget – this flag just disables swiping.
  bool _isFrontCardExpanded = false;

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
    _controller.dispose();
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
    setState(() => _isFrontCardExpanded = !_isFrontCardExpanded);
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

    // ┌──────────────────────────────────────────────────────────────────────┐
    // │  REPLACE the Container below with your PlanCard widget, e.g.:      │
    // │  PlanCard(plan: plans[planIndex])                                   │
    // └──────────────────────────────────────────────────────────────────────┘
    Widget buildCard(int pIndex) {
      final plan = _placeholderPlans[pIndex];
      return Container(
        height: _cardHeight,
        margin: const EdgeInsets.symmetric(horizontal: _cardHPadding),
        decoration: BoxDecoration(
          color: plan.color,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(20),
        child: Text(
          plan.title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
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
          final opacity = _swipeController.isAnimating
              ? 1.0 - Curves.easeIn.transform(_swipeController.value)
              : 1.0;

          // During shift animation, the new front card slides down from
          // its old position (one gap above) into the front position.
          final shiftT = _shiftController.value;
          final top = _shiftController.isAnimating
              ? frontTop - _stackGap * (1.0 - shiftT)
              : frontTop;
          final scale = _shiftController.isAnimating
              ? (1.0 - _scaleStep) + _scaleStep * shiftT
              : 1.0;

          final card = GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onTap: _onFrontCardTap,
            child: buildCard(_cardOrder[0]),
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

    // Back cards: at rest sit at their stackIndex position. Only lerp
    // from old→new while the shift animation is actively running.
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
            child: buildCard(_cardOrder[stackIndex]),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopNav(),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Title + card stack centered vertically
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Align(
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
              // Card stack

              const SizedBox(height: 10),

              _buildCardStack(),

              const Spacer(),
            ],
          ),

          // Bottom input bar (fixed)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.cardBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.add, color: AppColors.textPrimary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      cursorColor: AppColors.textPrimary,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Want to start a plan?',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // TODO: handle submit
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.arrow_upward,
                          color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
