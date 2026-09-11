import 'package:flutter/material.dart';

/// A rounded, color-tinted badge for a Material icon — the redesign's
/// replacement for the emoji-in-a-circle convention used throughout the
/// app's original screens. Two visual variants: [IconBadgeStyle.soft] (a
/// light tint of [color] behind an icon drawn in [color] — used on white
/// cards) and [IconBadgeStyle.solid] (a solid fill of [color] behind a
/// white icon — used inside colored hero headers where a soft tint
/// wouldn't show up).
enum IconBadgeStyle { soft, solid }

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.style = IconBadgeStyle.soft,
    this.size = 44,
    this.iconSize,
    this.shape = BoxShape.rectangle,
  });

  final IconData icon;
  final Color color;
  final IconBadgeStyle style;
  final double size;
  final double? iconSize;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final isSolid = style == IconBadgeStyle.solid;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSolid ? color : color.withOpacity(0.14),
        shape: shape,
        borderRadius:
            shape == BoxShape.rectangle ? BorderRadius.circular(size * 0.32) : null,
      ),
      child: Icon(
        icon,
        color: isSolid ? Colors.white : color,
        size: iconSize ?? size * 0.52,
      ),
    );
  }
}
