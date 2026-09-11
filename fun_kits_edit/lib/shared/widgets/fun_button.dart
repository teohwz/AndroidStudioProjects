import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ─── FUN BUTTON ──────────────────────────────────────────────────────────────
// Shared primary-action button used across ~13 screens (auth, admin content
// editors). Restyled as part of the app-wide UI redesign foundation: a
// slightly larger radius and a quick press-scale animation for a more
// "playful/tappable" feel — every screen that already uses FunButton picks
// this up automatically, no per-screen changes needed.
class FunButton extends StatefulWidget {
  const FunButton({
    super.key,
    required this.label,
    required this.onPressed,
    // Defaults to the coral "action" gradient, not the purple brand
    // gradient — matches the reference design's CTA color (purple is
    // reserved for headers/nav, per AppTheme's button theming).
    this.gradient = AppColors.secondaryGradient,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final LinearGradient gradient;
  final bool isLoading;
  final IconData? icon;

  @override
  State<FunButton> createState() => _FunButtonState();
}

class _FunButtonState extends State<FunButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.isLoading) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: widget.isLoading
                  ? const LinearGradient(
                      colors: [Color(0xFFCCCCCC), Color(0xFFBBBBBB)])
                  : widget.gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: widget.gradient.colors.first.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                borderRadius: BorderRadius.circular(18),
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
