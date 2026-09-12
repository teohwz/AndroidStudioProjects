import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// A visitor's full points ledger — every game/quiz session that earned
/// them points, every reward redemption that spent points, AND every
/// redemption that was later refunded, merged into one chronological trail
/// (newest first). A refunded redemption shows both its original spend
/// line and a separate refund-credit line, so nothing is silently rewritten
/// out of the history. Reachable from the Home screen, and doubles as the
/// trail an anonymous visitor can point to after registering with email
/// (requirement #6: the same uid keeps its full history across the
/// anonymous→email upgrade, so nothing here changes when they register).
class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  final _fs = FirestoreService();
  late Future<List<PointsLedgerEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PointsLedgerEntry>> _load() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value(const []);
    return _fs.getPointsLedger(uid);
  }

  Future<void> _refresh() async {
    final next = _load();
    // Wait for it before swapping in, so the RefreshIndicator spinner stays
    // up until fresh data (or a fresh error) actually arrives.
    await next.catchError((_) => <PointsLedgerEntry>[]);
    if (!mounted) return;
    setState(() => _future = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Points History',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<PointsLedgerEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 56, color: palette.textMedium),
                              const SizedBox(height: 12),
                              Text(
                                "Couldn't load your points history.",
                                style: TextStyle(color: palette.textMedium),
                              ),
                              const SizedBox(height: 4),
                              Text('Pull down to try again.',
                                  style: TextStyle(
                                      color: palette.textMedium,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 56, color: theme.colorScheme.primary),
                              const SizedBox(height: 12),
                              Text(
                                "You haven't earned or spent any points yet.",
                                style: TextStyle(color: palette.textMedium),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Scan a booth and play a game to get started!',
                                style: TextStyle(
                                    color: palette.textMedium, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final totalEarned = entries
                    .where((e) => e.type == PointsLedgerEntryType.earned)
                    .fold<int>(0, (sum, e) => sum + e.points);
                final totalSpent = entries
                    .where((e) => e.type == PointsLedgerEntryType.spent)
                    .fold<int>(0, (sum, e) => sum + e.points);
                final totalRefunded = entries
                    .where((e) => e.type == PointsLedgerEntryType.refunded)
                    .fold<int>(0, (sum, e) => sum + e.points);

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                label: 'Total Points Earned',
                                value: totalEarned,
                                gradient: palette.primaryGradient,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryCard(
                                label: 'Total Points Spent',
                                value: totalSpent,
                                color: palette.textMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryCard(
                                label: 'Total Points Refunded',
                                value: totalRefunded,
                                color: palette.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _LedgerTile(entry: entries[i]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    this.gradient,
    this.color,
  });

  final String label;
  final int value;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (color ?? Colors.grey) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2),
          const SizedBox(height: 4),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});
  final PointsLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final isPositive = entry.type == PointsLedgerEntryType.earned ||
        entry.type == PointsLedgerEntryType.refunded;
    final IconData icon;
    final Color color;
    switch (entry.type) {
      case PointsLedgerEntryType.earned:
        icon = Icons.videogame_asset_rounded;
        color = palette.success;
        break;
      case PointsLedgerEntryType.spent:
        icon = Icons.redeem_rounded;
        color = theme.colorScheme.error;
        break;
      case PointsLedgerEntryType.refunded:
        icon = Icons.replay_rounded;
        color = palette.warning;
        break;
    }

    String when = '';
    final t = entry.time;
    if (t != null) {
      when = '${t.day}/${t.month}/${t.year} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (when.isNotEmpty)
                  Text(when,
                      style:
                          TextStyle(fontSize: 11, color: palette.textMedium)),
              ],
            ),
          ),
          Text(isPositive ? '+${entry.points}' : '-${entry.points}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        ],
      ),
    );
  }
}
