import 'package:flutter/material.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/chat_overlay.dart';
import 'package:lattice/widgets/topnav.dart';
import '../widgets/plan_card.dart';

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
  final GlobalKey<ChatOverlayState> _chatOverlayKey = GlobalKey<ChatOverlayState>();

  late List<int> _cardOrder;

  // Animation for the swipe-down dismiss of the front card.
  // Drives from current drag position to off-screen.
  late AnimationController _swipeController;
  double _swipeStartDy = 0;
  static const double _swipeEndDy = 600;

  // Animate remaining cards shifting forward after a swipe-down.
  late AnimationController _shiftController;

  // Animate the last card sliding in from below on swipe-up (reverse of dismiss).
  late AnimationController _reverseShiftController;

  double _dragDy = 0;
  // Unclamped accumulator used for gesture threshold detection.
  double _rawDragDy = 0;

  // Whether the expanded overlay is showing.
  bool _isFrontCardExpanded = false;
  // True once the overlay should animate to fill the screen.
  bool _overlayExpanded = false;
  // True when plan-context chat is active. hides the full expanded card
  // because ChatOverlay renders its own mini header.
  bool _planChatActive = false;
  // The card's rect (in body Stack coordinates) captured at tap time.
  Rect _cardRect = Rect.zero;
  Size _bodySize = Size.zero;

  @override
  void initState() {
    super.initState();
    _cardOrder = List.generate(_placeholderPlans.length, (i) => i);

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 40),
    );

    _shiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _reverseShiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _shiftController.dispose();
    _reverseShiftController.dispose();
    super.dispose();
  }

  // ── Swipe handling ─────────────────────────────────────────────────────────

  void _onVerticalDragStart(DragStartDetails d) {
    _rawDragDy = 0;
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_isFrontCardExpanded) return;
    _rawDragDy += d.delta.dy;
    setState(() => _dragDy = _rawDragDy.clamp(-20.0, double.infinity));
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_isFrontCardExpanded) return;
    final velocity = d.primaryVelocity ?? 0;
    if (_rawDragDy > 80 || velocity > 800) {
      _dismissFrontCard();
    } else if (_rawDragDy < -80 || velocity < -800) {
      _bringLastCardToFront();
    } else {
      setState(() => _dragDy = 0);
    }
  }

  bool get _isAnimating =>
      _swipeController.isAnimating ||
      _shiftController.isAnimating ||
      _reverseShiftController.isAnimating;

  // Tap a back card at [stackIndex] to bring it to the front by cycling
  // through each intermediate card using the existing dismiss animation.
  Future<void> _bringCardToFront(int stackIndex) async {
    if (_isAnimating || _isFrontCardExpanded) return;
    for (int i = 0; i < stackIndex; i++) {
      await _dismissFrontCard();
    }
  }

  Future<void> _bringLastCardToFront() async {
    setState(() {
      _cardOrder.insert(0, _cardOrder.removeLast());
      _dragDy = 0;
    });
    await _reverseShiftController.forward(from: 0);
    _reverseShiftController.reset();
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
    setState(() {
      _overlayExpanded = false;
      _planChatActive = false;
    });
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
        animation: Listenable.merge([_swipeController, _shiftController, _reverseShiftController]),
        builder: (context, _) {
          final double dy;
          if (_swipeController.isAnimating) {
            dy = _swipeStartDy +
                (_swipeEndDy - _swipeStartDy) *
                    Curves.easeInOutQuart.transform(_swipeController.value);
          } else {
            // Positive = dragged/swiped down; negative = dragged/swiped up.
            // During reverse animation _dragDy is already reset to 0.
            dy = _dragDy;
          }

          // Fade to invisible while the overlay is open so the card stays in
          // place in the layout (no snapping) but isn't drawn twice.
          final swipeOpacity = _swipeController.isAnimating
              ? 1.0 - Curves.easeInOutQuart.transform(_swipeController.value)
              : 1.0;
          final opacity = _isFrontCardExpanded ? 0.0 : swipeOpacity;

          final double top;
          final double scale;
          if (_reverseShiftController.isAnimating) {
            // Incoming card slides up from below the screen into front position.
            final t = Curves.easeInOutQuart.transform(_reverseShiftController.value);
            top = frontTop + _swipeEndDy * (1.0 - t);
            scale = (1.0 - _scaleStep) + _scaleStep * t;
          } else if (_shiftController.isAnimating) {
            // During shift animation, the new front card slides down from
            // its old position (one gap above) into the front position.
            final shiftT = Curves.easeOut.transform(_shiftController.value);
            top = frontTop - _stackGap * (1.0 - shiftT);
            scale = (1.0 - _scaleStep) + _scaleStep * shiftT;
          } else {
            top = frontTop;
            scale = 1.0;
          }

          // Outer GestureDetector handles swipe-down only.
          // PlanCard's onTap handles tap-to-expand via _onFrontCardTap.
          final card = GestureDetector(
            onVerticalDragStart: _onVerticalDragStart,
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

    // Back cards: tapping the peeking portion brings that card to the front.
    return AnimatedBuilder(
      animation: Listenable.merge([_shiftController, _reverseShiftController]),
      builder: (context, _) {
        final newTop = frontTop - stackIndex * _stackGap;
        final newScale = 1.0 - stackIndex * _scaleStep;

        double top;
        double s;
        if (_shiftController.isAnimating) {
          // Forward swipe: cards shift one step closer to front.
          final t = Curves.easeInOutQuart.transform(_shiftController.value);
          final oldTop = frontTop - (stackIndex + 1) * _stackGap;
          top = oldTop + (newTop - oldTop) * t;
          final oldScale = 1.0 - (stackIndex + 1) * _scaleStep;
          s = oldScale + (newScale - oldScale) * t;
        } else if (_reverseShiftController.isAnimating) {
          // Reverse swipe: cards shift one step further back.
          final t = Curves.easeInOutQuart.transform(_reverseShiftController.value);
          final startTop = frontTop - (stackIndex - 1) * _stackGap;
          top = startTop + (newTop - startTop) * t;
          final startScale = 1.0 - (stackIndex - 1) * _scaleStep;
          s = startScale + (newScale - startScale) * t;
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
            child: buildCard(_cardOrder[stackIndex],
                onTap: () => _bringCardToFront(stackIndex)),
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
                            const SizedBox(height: 6),


              AnimatedOpacity(
                opacity: _isFrontCardExpanded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 40.0, top: 6.0, bottom: 6.0),
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '•••',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 16,
                        letterSpacing: 2,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _buildCardStack(),
              const Spacer(),
            ],
          ),

          // Expanding card overlay 
          // Starts at the front card's exact rect and animates to fill the body.
          // When plan-chat is active the card collapses to a mini strip at top
          if (_isFrontCardExpanded)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              top: _overlayExpanded ? 0 : _cardRect.top,
              left: _overlayExpanded ? 0 : _cardRect.left,
              right: _overlayExpanded ? 0 : (_bodySize.width > 0 ? _bodySize.width - _cardRect.right : 0),
              // When plan chat is active, push bottom up so only ~56px is visible.
              bottom: _planChatActive
                  ? (_bodySize.height > 0 ? _bodySize.height - 56 : 0)
                  : (_overlayExpanded ? 0 : overlayBottom),
              child: ClipRect(
                child: Stack(
                  children: [
                    // Background fades in separately from the card content.
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        opacity: _overlayExpanded ? 1.0 : 0.0,
                        child: const ColoredBox(color: AppColors.background),
                      ),
                    ),
                    SingleChildScrollView(
                      // Disable scrolling while the overlay is animating.
                      physics: _overlayExpanded
                          ? null
                          : const NeverScrollableScrollPhysics(),
                      child: PlanCard(
                        title: _placeholderPlans[_cardOrder[0]].title,
                        description: _placeholderPlans[_cardOrder[0]].description,
                        cardColor: _placeholderPlans[_cardOrder[0]].color,
                        startExpanded: true,
                        // Tapping the expanded card shrinks the overlay back.
                        onTap: _planChatActive
                          ? () => _chatOverlayKey.currentState?.dismissChat()
                          : _dismissExpandedCard,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ChatOverlay(
            key: _chatOverlayKey,
            planTitle: _isFrontCardExpanded
                ? _placeholderPlans[_cardOrder[0]].title
                : null,
            planCardColor: _isFrontCardExpanded
                ? _placeholderPlans[_cardOrder[0]].color
                : null,
            onPlanChatStarted: () {
              setState(() => _planChatActive = true);
            },
            onPlanChatDismissed: () {
              setState(() => _planChatActive = false);
            },
          ),
        ],
      ),
    );
  }
}
