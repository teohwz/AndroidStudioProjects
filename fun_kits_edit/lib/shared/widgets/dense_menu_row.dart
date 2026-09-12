import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A compact, "quiet-style" list row — a small tinted icon badge, a title +
/// subtitle, an optional extra trailing widget (e.g. a quick-add "+"
/// button), and a chevron. Denser than [ActionListRow] (smaller badge,
/// tighter padding, smaller text) — used for the Exhibitor Dashboard's
/// "Manage" tab and the Super Admin Dashboard's "Commerce" tab, where many
/// rows need to read as one quiet, scannable list rather than a grid of
/// bold cards.
class DenseMenuRow extends StatelessWidget {
  const DenseMenuRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: palette.textDark)),
                      const SizedBox(height: 1),
                      Text(subtitle,
                          style:
                              TextStyle(fontSize: 10.5, color: palette.textMedium)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  trailing!,
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: palette.textMedium.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
