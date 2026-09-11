import 'package:flutter/material.dart';

/// The flat-color header block with rounded bottom corners used at the top
/// of Home (brand purple), Booth (the exhibitor's own accent color — see
/// `booth_screen.dart`, unchanged per the confirmed requirement that
/// per-booth theming stays exactly as-is), and Exhibitor Dashboard ("Ink").
/// Content is white by default via [DefaultTextStyle]/[IconTheme].
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  final Color color;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}
