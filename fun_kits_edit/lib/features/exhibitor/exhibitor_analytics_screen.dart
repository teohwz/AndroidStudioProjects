import 'dart:math' as math;

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

/// Picks a "nice" axis-label interval — 1, 2, or 5 × a power of ten —
/// sized so the axis draws roughly [targetTicks] labels no matter how
/// large or small `maxValue` is. This is the standard "nice numbers for
/// graph labels" approach: rather than a hand-maintained list of
/// thresholds (this used to be a flat 5/10/20/50 ladder that topped out at
/// 50 for anything above 100 — fine for play counts, but "Daily Points
/// Distributed" can reach hundreds of points on an active day, and a max
/// around 1000 with a fixed interval of 50 drew ~20 labels squeezed into
/// this screen's ~200px-tall chart — the cluttered, overlapping y-axis
/// that was reported), it derives the interval directly from `maxValue`'s
/// own magnitude, so it keeps adapting automatically as the numbers grow
/// (or shrink) without ever needing another tier added by hand.
///
/// `maxValue` rounded up to a multiple of the result always lands on a
/// whole, evenly-spaced tick — see the call sites' comments for why that
/// matters (fl_chart's own extra always-drawn label at `maxY` otherwise
/// falls off-grid and overlaps the tick below it). Same fix already
/// applied to `my_stats_screen.dart`'s Average-Score-by-Game chart earlier
/// this project — duplicated here rather than shared, matching this
/// codebase's existing per-file convention for small chart helpers.
double _niceAxisInterval(double maxValue, {int targetTicks = 5}) {
  if (maxValue <= 0) return 1;
  final rawStep = maxValue / targetTicks;
  // Round rawStep down to its order of magnitude (1, 10, 100, ...), then
  // pick whichever of ×1/×2/×5/×10 of that magnitude rawStep is closest to
  // without going under it — the classic 1-2-5 "nice number" sequence.
  final magnitude =
      math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final residual = rawStep / magnitude;
  final double niceResidual;
  if (residual > 5) {
    niceResidual = 10;
  } else if (residual > 2) {
    niceResidual = 5;
  } else if (residual > 1) {
    niceResidual = 2;
  } else {
    niceResidual = 1;
  }
  return niceResidual * magnitude;
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
    // See _niceAxisInterval's doc comment — rounds the axis top up to a
    // clean multiple of a "nice" interval instead of leaving it as a raw,
    // often-fractional `count * 1.25`, so the top label always lands
    // exactly on a normal tick instead of overlapping the one below it.
    final rawMax = maxCount <= 0 ? 5.0 : maxCount * 1.25;
    final interval = _niceAxisInterval(rawMax);
    final maxY = (rawMax / interval).ceil() * interval;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        // Always-on value labels above each bar, rendered as a "forced"
        // tooltip (showingTooltipIndicators below) rather than a real
        // touch interaction — enabled:false keeps taps/highlighting off,
        // exactly as before. fitInsideVertically/Horizontally keep the
        // label from ever drawing outside this chart's own box, so it
        // can't visually spill over into the title/card above or get
        // clipped — the bars/axes/layout are otherwise unchanged.
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 6,
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              rod.toY.round().toString(),
              TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
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
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).extension<AppPalette>()!.textMedium),
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
                  child: Icon(games[i].icon, size: 16, color: color),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < games.length; i++)
            BarChartGroupData(x: i, showingTooltipIndicators: const [0], barRods: [
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
    // See _niceAxisInterval's doc comment — rounds the axis top up to a
    // clean multiple of a "nice" interval instead of leaving it as a raw,
    // often-fractional `maxVal * 1.25`, so the top label always lands
    // exactly on a normal tick instead of overlapping the one below it.
    final rawMax = maxVal <= 0 ? 5.0 : maxVal * 1.25;
    final interval = _niceAxisInterval(rawMax);
    final maxY = (rawMax / interval).ceil() * interval;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        // Always-on value labels above each bar — see the identical
        // comment in _PopularityChart above for why this uses a "forced"
        // tooltip instead of a real touch interaction, and how the
        // fitInside flags keep it from spilling outside this chart's box.
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 6,
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              rod.toY.round().toString(),
              TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
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
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).extension<AppPalette>()!.textMedium),
              ),
            ),
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
            BarChartGroupData(x: i, showingTooltipIndicators: const [0], barRods: [
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
