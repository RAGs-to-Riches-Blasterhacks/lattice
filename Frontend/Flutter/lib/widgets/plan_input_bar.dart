import 'package:flutter/material.dart';
import 'package:lattice/themes/app_colors.dart';

class PlanInputBar extends StatefulWidget {
  const PlanInputBar({super.key});

  @override
  State<PlanInputBar> createState() => _PlanInputBarState();
}

class _PlanInputBarState extends State<PlanInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    );
  }
}
