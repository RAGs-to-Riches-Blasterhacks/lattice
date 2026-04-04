import 'package:flutter/material.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/providers/auth_provider.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:lattice/widgets/app_drawer.dart';
import 'package:lattice/widgets/plan_card.dart';
import 'package:lattice/widgets/plan_input_bar.dart';
import 'package:lattice/widgets/topnav.dart';
import 'package:provider/provider.dart';

// Default colors when plans don't have a palette
const _defaultColors = [
  Color(0xFF6A9F6B),
  Color(0xFF8FAFD4),
  Color(0xFFE8A0B4),
  Color(0xFFF5F0E1),
  Color(0xFFBFA2DB),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late List<int> _cardOrder;

  late AnimationController _swipeController;
  double _swipeStartDy = 0;
  static const double _swipeEndDy = 600;

  late AnimationController _shiftController;

  double _dragDy = 0;
  bool _isFrontCardExpanded = false;

  @override
  void initState() {
    super.initState();
    _cardOrder = [];

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _shiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Fetch plans when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlansProvider>().fetchPlans();
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _shiftController.dispose();
    super.dispose();
  }

  void _syncCardOrder(int planCount) {
    if (_cardOrder.length != planCount) {
      _cardOrder = List.generate(planCount, (i) => i);
    }
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

  Widget _buildCardStack(List<PlanSummary> plans) {
    _syncCardOrder(plans.length);
    if (plans.isEmpty) return const SizedBox.shrink();

    final visible = _cardOrder.take(_maxVisible).toList();
    const frontTop = _stackGap * (_maxVisible - 1);
    const totalStackHeight = frontTop + _cardHeight;

    return SizedBox(
      height: totalStackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = visible.length - 1; i >= 0; i--)
            _buildPositionedCard(i, visible[i], frontTop, plans),
        ],
      ),
    );
  }

  Widget _buildPositionedCard(
      int stackIndex, int planIndex, double frontTop, List<PlanSummary> plans) {
    final isFront = stackIndex == 0;
    final plan = plans[planIndex];
    final color = _defaultColors[planIndex % _defaultColors.length];

    Widget buildCard() {
      return Container(
        height: _cardHeight,
        margin: const EdgeInsets.symmetric(horizontal: _cardHPadding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.skillName,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (plan.description != null) ...[
              const SizedBox(height: 8),
              Text(
                plan.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                ),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                _statusChip(plan.status),
                const Spacer(),
                Text(
                  '${plan.nodeCount} steps',
                  style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
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
            onTap: () {
              Navigator.pushNamed(context, '/roadmap', arguments: plan.id);
            },
            child: buildCard(),
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
            child: buildCard(),
          ),
        );
      },
    );
  }

  Widget _statusChip(PlanStatus status) {
    final label = status.name[0].toUpperCase() + status.name.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final plansProvider = context.watch<PlansProvider>();
    final plans = plansProvider.plans;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopNav(),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 10),
              if (plansProvider.loading)
                const Expanded(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (plansProvider.error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          plansProvider.error!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => plansProvider.fetchPlans(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (plans.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No plans yet.\nUse the bar below to start one!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                )
              else ...[
                _buildCardStack(plans),
                const Spacer(),
              ],
            ],
          ),
          const PlanInputBar(),
        ],
      ),
    );
  }
}
