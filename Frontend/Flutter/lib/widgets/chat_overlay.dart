import 'package:flutter/material.dart';
import 'package:lattice/models/chat_message.dart';
import 'package:lattice/themes/app_colors.dart';

/// A full-screen chat overlay + input bar meant to sit inside a Stack.
///
/// Drop this into any screen's body Stack in place of PlanInputBar.
/// The input bar is always visible at the bottom. Once the user sends the
/// first message the chat bubble list fades in over the screen content with
/// a gradient ombre at the top.
class ChatOverlay extends StatefulWidget {
  /// Optional context hint shown above the chat (e.g. plan title).
  /// Your backend teammate can use this to scope the conversation.
  final String? contextHint;

  const ChatOverlay({super.key, this.contextHint});

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];

  late AnimationController _overlayAnim;
  late Animation<double> _overlayOpacity;

  bool get _chatActive => _messages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _overlayAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _overlayOpacity =
        CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _overlayAnim.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _controller.clear();

    if (_messages.length == 1) {
      _overlayAnim.forward();
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

  void _dismissChat() {
    _overlayAnim.reverse().then((_) {
      if (mounted) {
        setState(() {
          _messages.clear();
        });
      }
    });
  }

  // ── Bubble builders ──────────────────────────────────────────────────────

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
              right: isUser ? 0 : 0,
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        // Chat bubble list w/ gradient ombre @ top
        if (_chatActive)
          Positioned.fill(
            bottom: 72 + bottomPadding,
            child: FadeTransition(
              opacity: _overlayOpacity,
              child: Stack(
                children: [
                  // Dark scrim behind messages
                  Container(color: AppColors.background.withValues(alpha: 0.96)),
                  // Message list
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 60, bottom: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
                  // Gradient ombre at top. fades from background to transparent
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
                              AppColors.background.withValues(alpha: 0.0),
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
                      onTap: _dismissChat,
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
