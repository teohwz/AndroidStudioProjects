import 'package:flutter/material.dart';

import '../../core/constants/game_types.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';
import 'scan_redeem_screen.dart';

/// Exhibitor-scoped hand-out checklist for physical prizes won at [boothId]
/// via the Spin Wheel, Scratch Card, or Lucky Draw (points wins are paid
/// out automatically and never appear here — see
/// FirestoreService.playPrizeGame/recordLuckyDrawPrizeWin).
///
/// Marking a prize collected is ONLY possible by verifying the visitor's
/// redemption code (confirmed requirement — the checkbox no longer works
/// as an unverified manual override): tapping a pending ("To Hand Out")
/// tile opens Scan to Redeem locked to that specific prize (see
/// ScanRedeemScreen/FirestoreService.redeemPrizeCode), and the app bar's
/// scan icon opens the same screen unscoped for any prize at this booth.
/// A prize that's already collected keeps a checkbox, but only to un-tick
/// it (undo a mis-scan) — see FirestoreService.unmarkPrizeCollected.
///
/// Grouped by game first (so the exhibitor can tell at a glance which part
/// of their booth a win came from), then by To Hand Out / Collected within
/// each game — no new data needed, [PrizeWinModel.gameType] already tags
/// every win.
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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan to Redeem',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ScanRedeemScreen(boothId: boothId))),
          ),
        ],
      ),
      body: StreamBuilder<List<PrizeWinModel>>(
        stream: fs.getPrizeWins(boothId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Points-type Lucky Draw wins are logged to `prize_wins` too now
          // (see PrizeWinModel's doc comment) purely so the claim step is
          // idempotent and the exhibitor's admin card can show who won —
          // there's nothing to hand out for those, so this checklist stays
          // physical-only, exactly as it always was for Spin Wheel/Scratch
          // Card.
          final wins = (snap.data ?? []).where((w) => !w.isPointsPrize).toList();
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
          // Group by game first, in a stable, predictable order (rather
          // than whichever order they happened to load in) — only games
          // that actually have a win here get a section.
          final byGame = <String, List<PrizeWinModel>>{};
          for (final w in wins) {
            byGame.putIfAbsent(w.gameType, () => []).add(w);
          }
          const gameOrder = ['spin_wheel', 'scratch_card', 'lucky_draw'];
          final orderedGameTypes = [
            ...gameOrder.where(byGame.containsKey),
            ...byGame.keys.where((g) => !gameOrder.contains(g)),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (final gameType in orderedGameTypes)
                _GameSection(
                  gameType: gameType,
                  wins: byGame[gameType]!,
                  fs: fs,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GameSection extends StatelessWidget {
  const _GameSection({required this.gameType, required this.wins, required this.fs});
  final String gameType;
  final List<PrizeWinModel> wins;
  final FirestoreService fs;

  GameTypeDef? _gameOf(String gameType) {
    for (final g in kGameTypes) {
      if (g.key == gameType) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final game = _gameOf(gameType);
    final pending = wins.where((w) => !w.collected).toList();
    final collected = wins.where((w) => w.collected).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(game?.icon ?? Icons.card_giftcard_rounded,
                  size: 18, color: palette.textDark),
              const SizedBox(width: 6),
              Text(game?.label ?? gameType,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 6),
              Text('(${wins.length})',
                  style: TextStyle(color: palette.textMedium, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          if (pending.isNotEmpty) ...[
            Text('To Hand Out (${pending.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            for (final w in pending) _PrizeWinTile(win: w, fs: fs),
            const SizedBox(height: 10),
          ],
          if (collected.isNotEmpty) ...[
            Text('Collected (${collected.length})',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: palette.textMedium)),
            const SizedBox(height: 6),
            for (final w in collected) _PrizeWinTile(win: w, fs: fs),
          ],
        ],
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

    if (!win.collected) {
      // Pending — no more unverified "tick to collect" affordance (see
      // this screen's doc comment). Tapping the tile opens Scan to Redeem
      // locked to THIS prize, so a different visitor's still-valid code
      // gets rejected instead of silently collecting the wrong win.
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        color: theme.colorScheme.surface,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ScanRedeemScreen(
              boothId: win.boothId,
              lockedWinId: win.id,
              lockedPrizeLabel: win.prizeLabel,
              lockedUserName: win.userName,
            ),
          )),
          leading: Icon(Icons.qr_code_scanner_rounded, color: palette.textMedium),
          title: Text(win.prizeLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          // Which game this came from is shown once, in the section header
          // above, rather than repeated on every tile.
          subtitle: Text('${win.userName} — tap to scan & verify',
              style: TextStyle(color: palette.textMedium)),
          trailing: Icon(Icons.chevron_right_rounded,
              color: palette.textMedium.withOpacity(0.7)),
        ),
      );
    }

    // Collected — the checkbox now only ever un-ticks (undoes a mis-scan);
    // there's no path back to `true` from here, that's redeemPrizeCode's
    // job alone. Always rendered checked, so onChanged only ever fires
    // with `false`.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0.5,
      color: palette.cardBg.withOpacity(0.5),
      child: CheckboxListTile(
        value: true,
        onChanged: (v) {
          if (v == false) fs.unmarkPrizeCollected(win.id);
        },
        activeColor: palette.success,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(win.prizeLabel,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.lineThrough)),
        subtitle: Text(win.userName),
      ),
    );
  }
}
