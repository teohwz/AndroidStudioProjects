import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// A full-screen loading overlay that blocks interaction while
/// an async operation is in progress. Wraps any widget as a Stack.
///
/// Usage:
/// ```dart
/// LoadingOverlay(
///   isLoading: _isSubmitting,
///   message: 'Saving quiz...',
///   child: MyContent(),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.color,
    this.barrierColor,
  });

  final bool isLoading;
  final Widget child;

  /// Optional status message shown below the spinner
  final String? message;

  /// Spinner color (defaults to AppColors.primary)
  final Color? color;

  /// Overlay background color (defaults to semi-transparent black)
  final Color? barrierColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          AnimatedOpacity(
            opacity: isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _Barrier(
              barrierColor: barrierColor,
              color: color,
              message: message,
            ),
          ),
      ],
    );
  }
}

class _Barrier extends StatelessWidget {
  const _Barrier({this.barrierColor, this.color, this.message});
  final Color? barrierColor;
  final Color? color;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: barrierColor ?? Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: color ?? AppColors.primary,
                  backgroundColor:
                      (color ?? AppColors.primary).withOpacity(0.15),
                ),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  message!,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact inline spinner — useful inside buttons or list rows
class InlineLoader extends StatelessWidget {
  const InlineLoader({
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 2.0,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? AppColors.primary,
      ),
    );
  }
}

/// A skeleton shimmer placeholder for loading states
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(_anim.value * 0.35),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// A full-page loading skeleton for list screens
class ListScreenSkeleton extends StatelessWidget {
  const ListScreenSkeleton({super.key, this.itemCount = 4});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            ShimmerBox(
                width: 48, height: 48, borderRadius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 4),
                  const SizedBox(height: 8),
                  ShimmerBox(
                      width: 180, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
