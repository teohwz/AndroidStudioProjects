import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/mask_name.dart';

/// A small "Recent Winners" panel for a single game (Spin Wheel or Scratch
/// Card) at a booth — pulls from the shared `prize_wins` collection (every
/// physical prize win, across Lucky Draw/Spin Wheel/Scratch Card, is logged
/// there — see FirestoreService.playPrizeGame/recordLuckyDrawPrizeWin), but
/// filtered to [gameType] so this game's panel never shows another game's
/// winners at the same booth. Masks each winner's name (see maskWinnerName).
/// Renders nothing while there are no wins yet for this game, so it never
/// shows an empty/awkward box.
class RecentWinnersList extends StatelessWidget {
  const RecentWinnersList({
    super.key,
    required this.boothId,
    required this.gameType,
    this.color = AppColors.accent,
  });

  final String boothId;
  final String gameType;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<PrizeWinModel>>(
      stream: fs.getRecentPrizeWins(boothId, gameType: gameType),
      builder: (context, snap) {
        final wins = snap.data ?? [];
        if (wins.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🏆 Recent Winners',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: color)),
              const SizedBox(height: 8),
              for (final w in wins)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${maskWinnerName(w.userName)} won ${w.prizeLabel}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMedium),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
