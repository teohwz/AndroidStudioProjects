import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/visitor_register_screen.dart';

/// Shown when an anonymous visitor taps something that now requires a
/// registered account — joining a Lucky Draw, playing Spin Wheel/Scratch
/// Card, or redeeming a Rewards Shop voucher (see the Prize Win
/// Notifications requirement: winners must have somewhere real to be
/// notified). The gated action itself is simply not performed; tapping
/// Register pushes the existing [VisitorRegisterScreen] on top.
Future<void> showRegisterRequiredDialog(
  BuildContext context, {
  String action = 'do this',
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Register to continue',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text(
        "You'll need a registered account to $action — that's how we'll "
        "notify you (and know where to send you) if you win!",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const VisitorRegisterScreen()));
          },
          child: const Text('Register'),
        ),
      ],
    ),
  );
}
