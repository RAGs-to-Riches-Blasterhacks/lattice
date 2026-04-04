import 'package:flutter/material.dart';
import 'package:lattice/models/chat_message.dart';
import 'package:lattice/themes/app_colors.dart';

/// A full-screen chat overlay + input bar meant to sit inside a Stack.
///
/// Drop this into any screen's body Stack in place of PlanInputBar.
/// The input bar is always visible at the bottom. Once the user sends the
/// first message the chat bubble list fades in over the screen content with
/// a gradient ombre at the top.
///
/// **Plan-context mode**: When [planTitle] and [planCardColor] are provided,
/// sending a message collapses the parent's PlanCard to a mini strip at the
/// top (via [onPlanChatStarted]). A draggable handle sits below the collapsed
/// card. Dragging the handle down or tapping the card's dropdown arrow
/// dismisses the chat and re-opens the card (via [onPlanChatDismissed]).
class ChatOverlay extends StatefulWidget {
  final String? planTitle;
  final Color? planCardColor;

  /// Called when the user dismisses the plan-context chat (handle drag or
  /// arrow tap). The parent should re-expand the PlanCard.
  final VoidCallback? onPlanChatDismissed;

  /// Called when the first message is sent while in plan-context mode.
  /// The parent should collapse the expanded PlanCard overlay to a mini strip.
  final VoidCallback? onPlanChatStarted;

  const ChatOverlay({
    super.key,
    this.planTitle,
    this.planCardColor,
    this.onPlanChatDismissed,
    this.onPlanChatStarted,
  });

  @override
  ChatOverlayState createState() => ChatOverlayState();
}

class ChatOverlayState extends State<ChatOverlay>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];

  // Fade for the normal (non-plan) chat overlay.
  late AnimationController _overlayAnim;
  late Animation<double> _overlayOpacity;

  // Slide-up for the plan-context chat area.
  late AnimationController _planChatAnim;
  late Animation<Offset> _planChatSlide;
  late Animation<double> _planChatFade;

  bool get _chatActive => _messages.isNotEmpty;
  bool get _inPlanContext =>
      widget.planTitle != null && widget.planCardColor != null;

  // Handle drag state
  double _handleDragDy = 0;
  static const double _handleDismissThreshold = 120;

  @override
  void initState() {
    super.initState();
    _overlayAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _overlayOpacity =
        CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOut);

    _planChatAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _planChatSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _planChatAnim, curve: Curves.easeOut));
    _planChatFade =
        CurvedAnimation(parent: _planChatAnim, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(ChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If we left plan context (card collapsed externally), reset chat.
    if (oldWidget.planTitle != null && widget.planTitle == null && _chatActive) {
      _planChatAnim.reverse();
      _overlayAnim.reverse().then((_) {
        if (mounted) setState(() => _messages.clear());
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _overlayAnim.dispose();
    _planChatAnim.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isFirstMessage = _messages.isEmpty;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _controller.clear();

    if (isFirstMessage) {
      if (_inPlanContext) {
        widget.onPlanChatStarted?.call();
        _planChatAnim.forward();
      } else {
        _overlayAnim.forward();
      }
    }

    _scrollToBottom();

    // Placeholder: simulate an agent response after a short delay.
    // Your backend teammate will replace this with the real agent call.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: 'Got it! Let me think about that...',
          isUser: false,
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void dismissChat() {
    if (_inPlanContext) {
      _planChatAnim.reverse().then((_) {
        if (mounted) {
          setState(() {
            _messages.clear();
            _handleDragDy = 0;
          });
        }
      });
      widget.onPlanChatDismissed?.call();
    } else {
      _overlayAnim.reverse().then((_) {
        if (mounted) {
          setState(() {
            _messages.clear();
            _handleDragDy = 0;
          });
        }
      });
    }
  }

  // Handle drag 

  void _onHandleDragUpdate(DragUpdateDetails d) {
    setState(() {
      _handleDragDy = (_handleDragDy + d.delta.dy).clamp(0, double.infinity);
    });
  }

  void _onHandleDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_handleDragDy > _handleDismissThreshold || velocity > 600) {
      dismissChat();
    } else {
      setState(() => _handleDragDy = 0);
    }
  }

  // Bubble builders 

  Widget _buildBubble(ChatMessage msg) {
    final h = msg.timestamp.hour > 12
        ? msg.timestamp.hour - 12
        : (msg.timestamp.hour == 0 ? 12 : msg.timestamp.hour);
    final m = msg.timestamp.minute.toString().padLeft(2, '0');
    final ampm = msg.timestamp.hour >= 12 ? 'PM' : 'AM';
    final time = '$h:$m $ampm';
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isUser)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                'Me',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/CircleLogo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.accent : AppColors.cardBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(30),
                      topRight: Radius.circular(isUser ? 0 : 30),
                      bottomRight: const Radius.circular(30),
                      bottomLeft: Radius.circular(isUser ? 30 : 0),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 44,
            ),
            child: Text(
              time,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Drag handle 

  Widget _buildDragHandle() {
    return GestureDetector(
      onVerticalDragUpdate: _onHandleDragUpdate,
      onVerticalDragEnd: _onHandleDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final planChatActive = _chatActive && _inPlanContext;

    // Height of the collapsed PlanCard strip in HomeScreen (matches the
    // AnimatedPositioned bottom calculation there).
    const double miniCardHeight = 56;

    return Stack(
      children: [
        // Plan-context chat (slide up from below collapsed card) 
        if (planChatActive)
          Positioned.fill(
            top: miniCardHeight,
            bottom: 72 + bottomPadding,
            child: SlideTransition(
              position: _planChatSlide,
              child: FadeTransition(
                opacity: _planChatFade,
                child: Transform.translate(
                  offset: Offset(0, _handleDragDy),
                  child: Stack(
                    children: [
                      Container(
                          color: AppColors.background
                              .withValues(alpha: 0.96)),
                      // Handle pinned to top
                      Positioned(
                        top: 0,
                        left: 16,
                        right: 16,
                        child: _buildDragHandle(),
                      ),
                      // Messages below handle
                      Positioned.fill(
                        top: 30, // handle height
                        child: ListView.builder(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.only(top: 8, bottom: 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) =>
                              _buildBubble(_messages[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Normal chat (non-plan context) 
        if (_chatActive && !_inPlanContext)
          Positioned.fill(
            bottom: 72 + bottomPadding,
            child: FadeTransition(
              opacity: _overlayOpacity,
              child: Stack(
                children: [
                  Container(
                      color:
                          AppColors.background.withValues(alpha: 0.96)),
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 60, bottom: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
                  // Gradient ombre at top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.background,
                              AppColors.background
                                  .withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 8,
                    right: 12,
                    child: GestureDetector(
                      onTap: dismissChat,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Icon(Icons.close,
                            color: AppColors.textPrimary, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Input bar ───────────────────────────────────────────────────
        Positioned(
          left: 16,
          right: 16,
          bottom: 24 + bottomPadding,
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
                    focusNode: _focusNode,
                    cursorColor: AppColors.textPrimary,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _chatActive
                          ? 'Type a message...'
                          : 'Want to start a plan?',
                      hintStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
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
    );
  }
}
