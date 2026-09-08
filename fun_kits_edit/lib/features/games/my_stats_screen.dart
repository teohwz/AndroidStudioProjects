import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_types.dart';
import '../../core/services/firestore_service.dart';

/// A visitor's own play stats — most played game, average score per game,
/// and total engagement time — aggregated client-side from the same
/// `game_sessions` log that powers Points History (FirestoreService.
/// getPointsHistory), so it stays in sync with that screen and with the
/// anonymous→email upgrade (same uid, same history) for free.
///
/// "Engagement time" here is the sum of each session's `durationMs` — the
/// true wall-clock time that play took, tracked at the start/end of every
/// game (see game_common.dart's submitGameScore and quiz_screen.dart).
/// Lucky Draw has no duration (instant, admin-triggered) and is excluded
/// from the average-score chart and duration total, though it still counts
/// toward "most played" via its session count.
class MyStatsScreen extends StatelessWidget {
  const MyStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Stats 📊',
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
                          Text('📊', style: TextStyle(fontSize: 56)),
                          SizedBox(height: 12),
                          Text("You haven't played anything yet.",
                              style: TextStyle(color: AppColors.textMedium)),
                          SizedBox(height: 4),
                          Text('Scan a booth and play a game to see your stats!',
                              style: TextStyle(
                                  color: AppColors.textMedium, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                final byGame = <String, _GameAgg>{};
                var totalDurationMs = 0;
                for (final e in entries) {
                  final gameType = e['gameType'] as String? ?? '';
                  if (gameType.isEmpty) continue;
                  final points = (e['points'] as num?)?.toInt() ?? 0;
                  final durationMs = (e['durationMs'] as num?)?.toInt() ?? 0;
                  totalDurationMs += durationMs;
                  final agg = byGame.putIfAbsent(gameType, () => _GameAgg());
                  agg.count += 1;
                  agg.totalPoints += points;
                }

                if (byGame.isEmpty) {
                  return const Center(
                    child: Text("You haven't played anything yet.",
                        style: TextStyle(color: AppColors.textMedium)),
                  );
                }

                final mostPlayed = byGame.entries
                    .reduce((a, b) => b.value.count > a.value.count ? b : a);

                // Bar chart only covers games with a meaningful score/
                // duration to average — same set kGameTypes already knows.
                final chartGames = kGameTypes
                    .where((g) => byGame.containsKey(g.key))
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              emoji: _emojiFor(mostPlayed.key),
                              label: 'Most Played',
                              value: _labelFor(mostPlayed.key),
                              sub:
                                  '${mostPlayed.value.count} play${mostPlayed.value.count == 1 ? '' : 's'}',
                              gradient: AppColors.primaryGradient,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _SummaryCard(
                              emoji: '⏱️',
                              label: 'Engagement Time',
                              value: _formatDuration(totalDurationMs),
                              sub: 'across ${entries.length} session${entries.length == 1 ? '' : 's'}',
                              gradient: AppColors.secondaryGradient,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Average Score by Game',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 20, 20, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        height: 220,
                        child: _AvgScoreChart(games: chartGames, byGame: byGame),
                      ),
                      const SizedBox(height: 24),
                      const Text('Sessions by Game',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 12),
                      ...chartGames.map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _GameRow(
                              emoji: g.emoji,
                              label: g.label,
                              count: byGame[g.key]!.count,
                              avg: byGame[g.key]!.avgPoints,
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static String _labelFor(String gameType) {
    for (final g in kGameTypes) {
      if (g.key == gameType) return g.label;
    }
    return gameType;
  }

  static String _emojiFor(String gameType) {
    for (final g in kGameTypes) {
      if (g.key == gameType) return g.emoji;
    }
    return '🎮';
  }

  static String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _GameAgg {
  int count = 0;
  int totalPoints = 0;
  double get avgPoints => count == 0 ? 0 : totalPoints / count;
}

class _AvgScoreChart extends StatelessWidget {
  const _AvgScoreChart({required this.games, required this.byGame});
  final List<GameTypeDef> games;
  final Map<String, _GameAgg> byGame;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const Center(
          child: Text('No scored games yet',
              style: TextStyle(color: AppColors.textMedium)));
    }
    final maxAvg = games
        .map((g) => byGame[g.key]!.avgPoints)
        .fold<double>(0, (a, b) => b > a ? b : a);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxAvg <= 0 ? 10 : maxAvg * 1.25,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= games.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(games[i].emoji,
                      style: const TextStyle(fontSize: 16)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < games.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: byGame[games[i].key]!.avgPoints,
                color: AppColors.primary,
                width: 22,
                borderRadius: BorderRadius.circular(6),
              ),
            ]),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.sub,
    required this.gradient,
  });
  final String emoji;
  final String label;
  final String value;
  final String sub;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.avg,
  });
  final String emoji;
  final String label;
  final int count;
  final double avg;

  @override
  Widget build(BuildContext context) {
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
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text('$count play${count == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMedium)),
          const SizedBox(width: 10),
          Text('avg ${avg.toStringAsFixed(0)} pts',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}
