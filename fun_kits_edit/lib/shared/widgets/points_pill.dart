import 'package:flutter/material.dart';

/// The small pill badge used to show a point/attempt/count value inside a
/// colored hero header (e.g. Home's "1,240" points, Booth's "3 attempts
/// left"). Defaults to a translucent-white pill for use on a colored
/// background; pass [background]/[foreground] to use it elsewhere.
class PointsPill extends StatelessWidget {
  const PointsPill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Colors.white.withOpacity(0.22);
    final fg = foreground ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
