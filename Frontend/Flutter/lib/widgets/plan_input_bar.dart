import 'package:flutter/material.dart';
import 'package:lattice/providers/plans_provider.dart';
import 'package:lattice/services/api_service.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:provider/provider.dart';

class PlanInputBar extends StatefulWidget {
  const PlanInputBar({super.key});

  @override
  State<PlanInputBar> createState() => _PlanInputBarState();
}

class _PlanInputBarState extends State<PlanInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final api = context.read<ApiService>();

      // Create a new conversation (no plan_id — triggers the plan creator agent)
      final conversation = await api.createConversation();

      // Send the user's message — the backend agent will create the plan
      final updated = await api.sendMessage(
        conversation.id,
        content: text,
      );

      // Check if the agent created a plan (plan_id in the last assistant message metadata)
      final lastAssistant = updated.messages
          .where((m) => m.role == 'assistant')
          .lastOrNull;
      final planId = lastAssistant?.metadata?['plan_id'] as String?;

      if (mounted) {
        _controller.clear();

        // Refresh the plans list
        context.read<PlansProvider>().fetchPlans();

        // If a plan was created, navigate to it
        if (planId != null) {
          Navigator.pushNamed(context, '/roadmap', arguments: planId);
        }

        // Show the agent's response
        if (lastAssistant != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lastAssistant.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: AppColors.cardBackground,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
                enabled: !_sending,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Want to start a plan?',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _submit,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : const Icon(Icons.arrow_upward,
                        color: AppColors.textPrimary, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
