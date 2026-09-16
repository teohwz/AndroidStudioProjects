import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/exhibitor_model.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// A visitor's own physical prize wins, across every booth — lets them find
/// a redemption QR/code again after the original win pop-up (which only
/// ever showed once) has been dismissed. Reached from Profile > My Prizes.
/// See FirestoreService.redeemPrizeCode for how an exhibitor verifies one
/// of these codes at their booth — the only way it can be marked collected;
/// there is no manual fallback exhibitors can use without a code.
class MyPrizesScreen extends StatelessWidget {
  const MyPrizesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Prizes',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.gold,
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<PrizeWinModel>>(
              stream: fs.getMyPrizeWins(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 64, color: palette.textMedium),
                        const SizedBox(height: 12),
                        Text(
                          'Something went wrong loading your prizes.\nPlease try again shortly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textMedium),
                        ),
                      ],
                    ),
                  );
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
                      Text('To Redeem (${pending.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Tap a prize to show its code at the booth.',
                          style: TextStyle(
                              fontSize: 12, color: palette.textMedium)),
                      const SizedBox(height: 8),
                      for (final w in pending) _MyPrizeTile(win: w, fs: fs),
                      const SizedBox(height: 16),
                    ],
                    if (collected.isNotEmpty) ...[
                      Text('Collected (${collected.length})',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: palette.textMedium)),
                      const SizedBox(height: 8),
                      for (final w in collected) _MyPrizeTile(win: w, fs: fs),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _MyPrizeTile extends StatelessWidget {
  const _MyPrizeTile({required this.win, required this.fs});
  final PrizeWinModel win;
  final FirestoreService fs;

  void _showCode(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _RedeemCodeSheet(win: win),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: win.collected ? 0.5 : 2,
      color: win.collected
          ? palette.cardBg.withOpacity(0.5)
          : theme.colorScheme.surface,
      child: ListTile(
        leading: Icon(
          win.collected ? Icons.check_circle_rounded : Icons.qr_code_2_rounded,
          color: win.collected ? palette.success : palette.gold,
        ),
        title: Text(win.prizeLabel,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: win.collected ? TextDecoration.lineThrough : null)),
        subtitle: FutureBuilder<ExhibitorModel?>(
          future: fs.getExhibitorById(win.boothId),
          builder: (context, snap) {
            final name = snap.data?.name;
            return Text(win.collected
                ? 'Collected · ${(name?.isNotEmpty ?? false) ? name : 'a booth'}'
                : 'From ${(name?.isNotEmpty ?? false) ? name : 'a booth'} — tap to show code');
          },
        ),
        trailing:
            win.collected ? null : const Icon(Icons.chevron_right_rounded),
        onTap: win.collected ? null : () => _showCode(context),
      ),
    );
  }
}

/// Full-size QR + plain-digits fallback for one pending prize — big enough
/// to actually scan (a tiny inline QR in a list tile wouldn't be reliably
/// readable by a booth's camera). Uses the same `qr_flutter` package/plain
/// styling as the exhibitor's own booth QR (see ExhibitorQrScreen), just
/// without the preset customization since this is a one-time, functional
/// code rather than something printed and reused.
class _RedeemCodeSheet extends StatelessWidget {
  const _RedeemCodeSheet({required this.win});
  final PrizeWinModel win;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    // Matches the `funkits:prize:<winId>:<code>` payload the exhibitor's
    // Scan to Redeem screen parses — see FirestoreService.redeemPrizeCode.
    final payload = 'funkits:prize:${win.id}:${win.redemptionCode}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: palette.cardBg, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(win.prizeLabel,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Show this to the booth staff to redeem',
                style: TextStyle(color: palette.textMedium, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: QrImageView(
                data: payload,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              win.redemptionCode.isEmpty ? '——' : win.redemptionCode,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: 6),
            ),
            const SizedBox(height: 4),
            Text("Can't scan? Read this code out loud instead.",
                style: TextStyle(color: palette.textMedium, fontSize: 12)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
