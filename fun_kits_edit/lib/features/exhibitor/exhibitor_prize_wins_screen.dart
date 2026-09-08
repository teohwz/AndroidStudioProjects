import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';

/// Exhibitor-scoped hand-out checklist for physical prizes won at [boothId]
/// via the Spin Wheel or Scratch Card (points wins are paid out
/// automatically and never appear here — see FirestoreService.playPrizeGame).
/// Tick a win off once the visitor has collected it in person.
class ExhibitorPrizeWinsScreen extends StatelessWidget {
  const ExhibitorPrizeWinsScreen({super.key, required this.boothId});

  final String boothId;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Prize Wins 🎁',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.accent,
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
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎁', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 12),
                  Text('No physical prizes won yet.',
                      style: TextStyle(color: AppColors.textMedium)),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textMedium)),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: win.collected ? 0.5 : 2,
      color: win.collected ? AppColors.cardBg.withOpacity(0.5) : Colors.white,
      child: CheckboxListTile(
        value: win.collected,
        onChanged: (v) => fs.markPrizeCollected(win.id, v ?? false),
        activeColor: AppColors.success,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(win.prizeLabel,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: win.collected ? TextDecoration.lineThrough : null)),
        subtitle: Text(
            '${win.userName} · ${win.gameType == 'spin_wheel' ? '🎡 Spin Wheel' : '🪙 Scratch Card'}'),
      ),
    );
  }
}
