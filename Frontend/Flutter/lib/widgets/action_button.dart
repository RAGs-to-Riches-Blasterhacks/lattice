import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading || widget.onTap == null;

    return Listener(
      onPointerDown: disabled ? null : (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 80),
          padding: EdgeInsets.only(
            top: _pressed ? 4 : 0,
            bottom: _pressed ? 0 : 4,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: disabled
                  ? widget.color.withValues(alpha: 0.45)
                  : widget.color,
              borderRadius: BorderRadius.circular(14),
            //   border: Border.all(color: Colors.black, width: 1),
              boxShadow: (_pressed || disabled)
                  ? []
                  : const [
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
