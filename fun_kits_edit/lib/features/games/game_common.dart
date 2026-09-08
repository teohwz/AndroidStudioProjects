import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firestore_service.dart';

final _fsCommon = FirestoreService();

/// Records one play of [gameType] at booth [exhibitorId] (via
/// FirestoreService.recordGamePlay's transaction — the actual security
/// boundary, not this function) and, if allowed, submits the score to the
/// shared points/leaderboard system and best-effort logs a lightweight
/// session record (uid, gameType, exhibitorId, points, timestamp) for
/// future per-booth analytics.
///
/// Returns true if the play was recorded and points awarded, false if the
/// visitor has exhausted their shared attempt pool at this booth (see
/// BoothAttemptPool) — the caller should show [showPlayLimitDialog] instead
/// of the normal result dialog in that case. A null/empty [exhibitorId] (a
/// game reached outside any booth context) skips the per-booth limiter
/// entirely and always succeeds.
Future<bool> submitGameScore(
  String gameType,
  int points, {
  String? exhibitorId,
  int? durationMs,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  if (exhibitorId != null && exhibitorId.isNotEmpty) {
    final allowed =
        await _fsCommon.recordGamePlay(user.uid, exhibitorId, gameType);
    if (!allowed) return false;
  }
  if (points > 0) {
    await _fsCommon.addPoints(
      user.uid,
      user.displayName ?? 'Player',
      points,
      gameType: gameType,
    );
  }
  await _fsCommon.logGameSession(user.uid, gameType, points,
      exhibitorId: exhibitorId, durationMs: durationMs);
  return true;
}

/// Themed "results" dialog shown at the end of every mini-game. [context]
/// must be the game screen's own BuildContext (used to pop back to the
/// booth once the dialog closes).
Future<void> showGameResultDialog(
  BuildContext context, {
  required String emoji,
  required String title,
  required String message,
  required Color color,
  required VoidCallback onPlayAgain,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
          },
          child: const Text('Back to Booth'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onPlayAgain();
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white),
          child: const Text('Play Again'),
        ),
      ],
    ),
  );
}

/// Shown instead of [showGameResultDialog] when [submitGameScore] returns
/// false — the visitor has exhausted their shared attempt pool for this
/// booth (see BoothAttemptPool). No "Play Again" here: another attempt
/// would just be rejected the same way, so the only way forward is
/// completing a booth task for more attempts, or a different booth.
Future<void> showPlayLimitDialog(BuildContext context, {required Color color}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔒', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text("You're out of attempts at this booth",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            "Complete this booth's tasks (follow the exhibitor, play a "
            'featured mini-game) to earn more attempts, or try a different '
            'booth.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMedium),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white),
          child: const Text('Back to Booth'),
        ),
      ],
    ),
  );
}

/// A small reusable AppBar for every mini-game, themed with the booth's
/// accent color (falls back to AppColors.primary when played outside a
/// booth context).
PreferredSizeWidget gameAppBar(String title, Color color, {List<Widget>? actions}) {
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    backgroundColor: color,
    foregroundColor: Colors.white,
    actions: actions,
  );
}
