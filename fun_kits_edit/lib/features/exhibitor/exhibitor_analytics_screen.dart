import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/game_types.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// An exhibitor's booth analytics — total participants, game popularity,
/// and a day-by-day participation/points trend — aggregated client-side
/// from this booth's own `game_sessions` log (FirestoreService.
/// getBoothSessions), the same raw source the per-booth leaderboard already
/// aggregates from. Scoped entirely to [boothId]; there is no way to view
/// another exhibitor's booth from here (see ExhibitorGuard in routes.dart).
class ExhibitorAnalyticsScreen extends StatelessWidget {
  const ExhibitorAnalyticsScreen({super.key, required this.boothId});
  final String boothId;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.exhibitorColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.getBoothSessions(boothId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snap.data ?? [];
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 56, color: palette.textMedium),
                    const SizedBox(height: 12),
                    Text('No plays at this booth yet.',
                        style: TextStyle(color: palette.textMedium)),
                    const SizedBox(height: 4),
                    Text(
                        'Once visitors scan in and play, stats will show up here.',
                        style:
                            TextStyle(color: palette.textMedium, fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          final uniqueParticipants = <String>{};
          final byGame = <String, int>{};
          final byDay = <String, _DayAgg>{};

          for (final e in sessions) {
            final uid = e['uid'] as String?;
            if (uid != null && uid.isNotEmpty) uniqueParticipants.add(uid);

            final gameType = e['gameType'] as String? ?? '';
            if (gameType.isNotEmpty) {
              byGame[gameType] = (byGame[gameType] ?? 0) + 1;
            }

            final playedAt = e['playedAt'];
            if (playedAt is Timestamp) {
              final d = playedAt.toDate();
              final key = '${d.year.toString().padLeft(4, '0')}-'
                  '${d.month.toString().padLeft(2, '0')}-'
                  '${d.day.toString().padLeft(2, '0')}';
              final agg = byDay.putIfAbsent(key, () => _DayAgg(d.month, d.day));
              agg.plays += 1;
              agg.points += (e['points'] as num?)?.toInt() ?? 0;
            }
          }

          final sortedDayKeys = byDay.keys.toList()..sort();
          // Cap to the most recent 14 days so the chart stays readable for
          // a long-running booth — fine at prototype/single-exhibition
          // scale, same trade-off already made elsewhere in this file.
          final dayKeys = sortedDayKeys.length > 14
              ? sortedDayKeys.sublist(sortedDayKeys.length - 14)
              : sortedDayKeys;

          final popularGames = kGameTypes
              .where((g) => byGame.containsKey(g.key))
              .toList()
            ..sort((a, b) => byGame[b.key]!.compareTo(byGame[a.key]!));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.groups_rounded,
                        label: 'Total Participants',
                        value: '${uniqueParticipants.length}',
                        color: palette.exhibitorColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.sports_esports_rounded,
                        label: 'Total Plays',
                        value: '${sessions.length}',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Game Popularity',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 20, 8),
                  decoration: _cardDecoration(theme),
                  height: 220,
                  child: _PopularityChart(
                    games: popularGames,
                    byGame: byGame,
                    color: palette.exhibitorColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Daily Participation',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 20, 8),
                  decoration: _cardDecoration(theme),
                  height: 200,
                  child: _DailyBarChart(
                    dayKeys: dayKeys,
                    byDay: byDay,
                    color: palette.exhibitorColor,
                    valueOf: (agg) => agg.plays.toDouble(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Daily Points Distributed',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 20, 8),
                  decoration: _cardDecoration(theme),
                  height: 200,
                  child: _DailyBarChart(
                    dayKeys: dayKeys,
                    byDay: byDay,
                    color: palette.gold,
                    valueOf: (agg) => agg.points.toDouble(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme) => BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      );
}

class _DayAgg {
  _DayAgg(this.month, this.day);
  final int month;
  final int day;
  int plays = 0;
  int points = 0;
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PopularityChart extends StatelessWidget {
  const _PopularityChart(
      {required this.games, required this.byGame, required this.color});
  final List<GameTypeDef> games;
  final Map<String, int> byGame;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return Center(
          child: Text('No plays yet',
              style: TextStyle(
                  color: Theme.of(context).extension<AppPalette>()!.textMedium)));
    }
    final maxCount =
        games.map((g) => byGame[g.key]!).fold<int>(0, (a, b) => b > a ? b : a);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount <= 0 ? 5 : maxCount * 1.25,
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
                  child: Icon(games[i].icon, size: 16, color: color),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < games.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: byGame[games[i].key]!.toDouble(),
                color: color,
                width: 22,
                borderRadius: BorderRadius.circular(6),
              ),
            ]),
        ],
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({
    required this.dayKeys,
    required this.byDay,
    required this.color,
    required this.valueOf,
  });
  final List<String> dayKeys;
  final Map<String, _DayAgg> byDay;
  final Color color;
  final double Function(_DayAgg) valueOf;

  @override
  Widget build(BuildContext context) {
    if (dayKeys.isEmpty) {
      return Center(
          child: Text('No data yet',
              style: TextStyle(
                  color: Theme.of(context).extension<AppPalette>()!.textMedium)));
    }
    final values = dayKeys.map((k) => valueOf(byDay[k]!)).toList();
    final maxVal = values.fold<double>(0, (a, b) => b > a ? b : a);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal <= 0 ? 5 : maxVal * 1.25,
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
                if (i < 0 || i >= dayKeys.length) {
                  return const SizedBox.shrink();
                }
                final agg = byDay[dayKeys[i]]!;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${agg.day}/${agg.month}',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .extension<AppPalette>()!
                              .textMedium)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < dayKeys.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                color: color,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }
}
