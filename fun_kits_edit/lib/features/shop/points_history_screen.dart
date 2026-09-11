import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/game_types.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// A visitor's own points-earning history — every game/quiz/lucky-draw
/// session that credited them points, newest first. Reachable from the
/// Home screen, and doubles as the trail an anonymous visitor can point to
/// after registering with email (requirement #6: the same uid keeps its
/// full history across the anonymous→email upgrade, so nothing here
/// changes when they register).
class PointsHistoryScreen extends StatelessWidget {
  const PointsHistoryScreen({super.key});

  String _labelFor(String gameType) {
    for (final g in kGameTypes) {
      if (g.key == gameType) return g.label;
    }
    return gameType;
  }

  IconData _iconFor(String gameType) {
    for (final g in kGameTypes) {
      if (g.key == gameType) return g.icon;
    }
    return Icons.videogame_asset_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

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
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: fs.getPointsHistory(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 56, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text("You haven't earned any points yet.",
                              style: TextStyle(color: palette.textMedium)),
                          const SizedBox(height: 4),
                          Text('Scan a booth and play a game to get started!',
                              style: TextStyle(
                                  color: palette.textMedium, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                final total =
                    entries.fold<int>(0, (sum, e) => sum + ((e['points'] as num?)?.toInt() ?? 0));
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: palette.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('Total Points Earned',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$total',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _HistoryTile(
                          entry: entries[i],
                          label: _labelFor(entries[i]['gameType'] ?? ''),
                          icon: _iconFor(entries[i]['gameType'] ?? ''),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(
      {required this.entry, required this.label, required this.icon});
  final Map<String, dynamic> entry;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final points = (entry['points'] as num?)?.toInt() ?? 0;
    final playedAt = entry['playedAt'];
    String when = '';
    if (playedAt is Timestamp) {
      final d = playedAt.toDate();
      when = '${d.day}/${d.month}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (when.isNotEmpty)
                  Text(when,
                      style:
                          TextStyle(fontSize: 11, color: palette.textMedium)),
              ],
            ),
          ),
          Text(points > 0 ? '+$points' : '$points',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: points > 0 ? palette.success : palette.textMedium)),
        ],
      ),
    );
  }
}
