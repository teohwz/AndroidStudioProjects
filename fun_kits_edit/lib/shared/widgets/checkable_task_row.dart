import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// A row for an earnable booth task ("Checked in", "Follow booth") — shows
/// a plain icon + label normally, and flips to a success-tinted checkmark
/// row with a "+1" once [earned] is true. Used by the Booth screen's
/// "Earn attempts" section.
class CheckableTaskRow extends StatelessWidget {
  const CheckableTaskRow({
    super.key,
    required this.icon,
    required this.label,
    required this.earned,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool earned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = theme.extension<AppPalette>()?.success ?? Colors.green;
    return Material(
      color: earned ? success.withOpacity(0.10) : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: earned ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: earned
                  ? success.withOpacity(0.4)
                  : theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(earned ? Icons.check_circle_rounded : icon,
                  color: earned ? success : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              if (earned)
                Text('+1',
                    style: TextStyle(color: success, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
