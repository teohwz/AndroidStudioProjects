import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/game_types.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Stats',
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
                          Icon(Icons.bar_chart_rounded,
                              size: 56, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text("You haven't played anything yet.",
                              style: TextStyle(color: palette.textMedium)),
                          const SizedBox(height: 4),
                          Text('Scan a booth and play a game to see your stats!',
                              style: TextStyle(
                                  color: palette.textMedium, fontSize: 12)),
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
                  return Center(
                    child: Text("You haven't played anything yet.",
                        style: TextStyle(color: palette.textMedium)),
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
                              icon: _iconFor(mostPlayed.key),
                              label: 'Most Played',
                              value: _labelFor(mostPlayed.key),
                              sub:
                                  '${mostPlayed.value.count} play${mostPlayed.value.count == 1 ? '' : 's'}',
                              gradient: palette.primaryGradient,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _SummaryCard(
                              icon: Icons.timer_rounded,
                              label: 'Engagement Time',
                              value: _formatDuration(totalDurationMs),
                              sub: 'across ${entries.length} session${entries.length == 1 ? '' : 's'}',
                              gradient: palette.secondaryGradient,
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
                          color: theme.colorScheme.surface,
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
                              icon: g.icon,
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

  static IconData _iconFor(String gameType) {
    for (final g in kGameTypes) {
      if (g.key == gameType) return g.icon;
    }
    return Icons.videogame_asset_rounded;
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

/// Picks a "nice" round step for a chart axis — 5/10/20/25/50/100 — sized
/// to roughly the given value, so `value` rounded up to a multiple of the
/// result always lands on a whole, evenly-spaced tick. Used by
/// [_AvgScoreChart] to avoid fl_chart's default behavior of always
/// labeling the exact (often fractional) `maxY` value even when it falls
/// between two regular ticks.
double _niceAxisInterval(double value) {
  if (value <= 20) return 5;
  if (value <= 50) return 10;
  if (value <= 100) return 20;
  if (value <= 250) return 50;
  return 100;
}

class _AvgScoreChart extends StatelessWidget {
  const _AvgScoreChart({required this.games, required this.byGame});
  final List<GameTypeDef> games;
  final Map<String, _GameAgg> byGame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    if (games.isEmpty) {
      return Center(
          child: Text('No scored games yet',
              style: TextStyle(color: palette.textMedium)));
    }
    final maxAvg = games
        .map((g) => byGame[g.key]!.avgPoints)
        .fold<double>(0, (a, b) => b > a ? b : a);
    // Round the axis top up to a clean multiple of a "nice" interval,
    // instead of leaving it as raw `maxAvg * 1.25` (e.g. 29.1). Without an
    // explicit `interval` below, fl_chart auto-picks its own left-axis
    // interval AND always draws one extra label exactly at `maxY` — when
    // maxY is a fractional, off-grid value like 29.1, that extra label
    // doesn't line up with the regular 0/5/10/.../25 ticks and visually
    // overlaps/wraps with the one just below it (the bug in the
    // screenshot). Rounding maxY up to the same interval used for the
    // ticks means the top label always lands exactly on a normal tick
    // instead of needing an extra one.
    final rawMax = maxAvg <= 0 ? 10.0 : maxAvg * 1.25;
    final interval = _niceAxisInterval(rawMax);
    final maxY = (rawMax / interval).ceil() * interval;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(fontSize: 11, color: palette.textMedium),
              ),
            ),
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
                  child: Icon(games[i].icon,
                      size: 16, color: theme.colorScheme.primary),
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
                color: theme.colorScheme.primary,
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
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.gradient,
  });
  final IconData icon;
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
          Icon(icon, color: Colors.white, size: 24),
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
    required this.icon,
    required this.label,
    required this.count,
    required this.avg,
  });
  final IconData icon;
  final String label;
  final int count;
  final double avg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
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
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text('$count play${count == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: palette.textMedium)),
          const SizedBox(width: 10),
          Text('avg ${avg.toStringAsFixed(0)} pts',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}
