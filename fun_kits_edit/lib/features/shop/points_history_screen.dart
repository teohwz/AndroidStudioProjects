import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_types.dart';
import '../../core/services/firestore_service.dart';

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
      if (g.key == gameType) return '${g.emoji} ${g.label}';
    }
    return gameType;
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Points History 📜',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primary,
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('📜', style: TextStyle(fontSize: 56)),
                          SizedBox(height: 12),
                          Text("You haven't earned any points yet.",
                              style: TextStyle(color: AppColors.textMedium)),
                          SizedBox(height: 4),
                          Text('Scan a booth and play a game to get started!',
                              style: TextStyle(
                                  color: AppColors.textMedium, fontSize: 12)),
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
                        gradient: AppColors.primaryGradient,
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
  const _HistoryTile({required this.entry, required this.label});
  final Map<String, dynamic> entry;
  final String label;

  @override
  Widget build(BuildContext context) {
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
        color: Colors.white,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (when.isNotEmpty)
                  Text(when,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMedium)),
              ],
            ),
          ),
          Text(points > 0 ? '+$points' : '$points',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: points > 0 ? AppColors.success : AppColors.textMedium)),
        ],
      ),
    );
  }
}
