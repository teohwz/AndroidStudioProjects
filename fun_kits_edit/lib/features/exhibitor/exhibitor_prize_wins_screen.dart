import 'package:flutter/material.dart';

import '../../core/constants/game_types.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// Exhibitor-scoped hand-out checklist for physical prizes won at [boothId]
/// via the Spin Wheel, Scratch Card, or Lucky Draw (points wins are paid
/// out automatically and never appear here — see
/// FirestoreService.playPrizeGame/recordLuckyDrawPrizeWin). Tick a win off
/// once the visitor has collected it in person.
class ExhibitorPrizeWinsScreen extends StatelessWidget {
  const ExhibitorPrizeWinsScreen({super.key, required this.boothId});

  final String boothId;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Prize Wins',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.gold,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PrizeWinModel>>(
        stream: fs.getPrizeWins(boothId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final wins = snap.data ?? [];
          if (wins.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard_rounded,
                      size: 64, color: palette.textMedium),
                  const SizedBox(height: 12),
                  Text('No physical prizes won yet.',
                      style: TextStyle(color: palette.textMedium)),
                ],
              ),
            );
          }
          final pending = wins.where((w) => !w.collected).toList();
          final collected = wins.where((w) => w.collected).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (pending.isNotEmpty) ...[
                Text('To Hand Out (${pending.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                for (final w in pending) _PrizeWinTile(win: w, fs: fs),
                const SizedBox(height: 16),
              ],
              if (collected.isNotEmpty) ...[
                Text('Collected (${collected.length})',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: palette.textMedium)),
                const SizedBox(height: 8),
                for (final w in collected) _PrizeWinTile(win: w, fs: fs),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PrizeWinTile extends StatelessWidget {
  const _PrizeWinTile({required this.win, required this.fs});
  final PrizeWinModel win;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final game = _gameOf(win.gameType);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: win.collected ? 0.5 : 2,
      color: win.collected
          ? palette.cardBg.withOpacity(0.5)
          : theme.colorScheme.surface,
      child: CheckboxListTile(
        value: win.collected,
        onChanged: (v) => fs.markPrizeCollected(win.id, v ?? false),
        activeColor: palette.success,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(win.prizeLabel,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: win.collected ? TextDecoration.lineThrough : null)),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${win.userName} · '),
            Icon(game?.icon ?? Icons.card_giftcard_rounded,
                size: 14, color: palette.textMedium),
            const SizedBox(width: 4),
            Text(game?.label ?? win.gameType),
          ],
        ),
      ),
    );
  }

  GameTypeDef? _gameOf(String gameType) {
    for (final g in kGameTypes) {
      if (g.key == gameType) return g;
    }
    return null;
  }
}
