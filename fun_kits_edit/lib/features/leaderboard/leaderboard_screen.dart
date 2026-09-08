import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_types.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/models/leaderboard_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

enum _LbMode { global, perGame, perExhibitor }

/// Generic row the podium/list widgets render — built from whichever source
/// (global totals, one game's breakdown, or one booth's session totals) is
/// currently selected, so the UI below doesn't care which mode it's in.
class _Row {
  final String name;
  final int points;
  final int rank;
  final int? gamesPlayed;
  const _Row(
      {required this.name,
      required this.points,
      required this.rank,
      this.gamesPlayed});

  String get medalEmoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _fs = FirestoreService();
  _LbMode _mode = _LbMode.global;
  String _selectedGame = kGameTypes.first.key;
  String? _selectedExhibitorId;
  String _selectedExhibitorName = '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Leaderboard 🏆',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: AppColors.textDark,
      ),
      body: Column(
        children: [
          if (auth.isAnonymous)
            _JoinToRankBanner(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.saveProgress),
            ),
          _FilterBar(
            mode: _mode,
            selectedGame: _selectedGame,
            selectedExhibitorName: _selectedExhibitorName,
            onModeChanged: (m) => setState(() => _mode = m),
            onGameChanged: (g) => setState(() => _selectedGame = g),
            onExhibitorPicked: (id, name) => setState(() {
              _selectedExhibitorId = id;
              _selectedExhibitorName = name;
            }),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _LbMode.global:
        return StreamBuilder<List<LeaderboardEntry>>(
          stream: _fs.getLeaderboard(),
          builder: (context, snap) => _renderRows(
            waiting: snap.connectionState == ConnectionState.waiting,
            rows: (snap.data ?? [])
                .map((e) => _Row(
                    name: e.displayName,
                    points: e.totalPoints,
                    rank: e.rank,
                    gamesPlayed: e.gamesPlayed))
                .toList(),
            emptyMessage: 'No scores yet. Play a game!',
          ),
        );
      case _LbMode.perGame:
        return StreamBuilder<List<LeaderboardEntry>>(
          stream: _fs.getLeaderboardByGame(_selectedGame),
          builder: (context, snap) => _renderRows(
            waiting: snap.connectionState == ConnectionState.waiting,
            rows: (snap.data ?? [])
                .map((e) => _Row(
                    name: e.displayName,
                    points: e.gameBreakdown[_selectedGame] ?? 0,
                    rank: e.rank))
                .toList(),
            emptyMessage: 'Nobody has played this game yet.',
          ),
        );
      case _LbMode.perExhibitor:
        if (_selectedExhibitorId == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Pick a booth above to see its leaderboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMedium)),
            ),
          );
        }
        return StreamBuilder<List<ExhibitorLeaderboardEntry>>(
          stream: _fs.getExhibitorLeaderboard(_selectedExhibitorId!),
          builder: (context, snap) => _renderRows(
            waiting: snap.connectionState == ConnectionState.waiting,
            rows: (snap.data ?? [])
                .map((e) =>
                    _Row(name: e.displayName, points: e.points, rank: e.rank))
                .toList(),
            emptyMessage: 'No plays logged at this booth yet.',
          ),
        );
    }
  }

  Widget _renderRows({
    required bool waiting,
    required List<_Row> rows,
    required String emptyMessage,
  }) {
    if (waiting) return const Center(child: CircularProgressIndicator());
    if (rows.isEmpty) {
      return Center(
          child: Text(emptyMessage,
              style: const TextStyle(color: AppColors.textMedium)));
    }
    final topThree = rows.take(3).toList();
    final remaining = rows.skip(3).toList();
    return Column(
      children: [
        SizedBox(height: 240, child: _PodiumWidget(topThree: topThree)),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: remaining.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _LeaderRow(row: remaining[i]),
          ),
        ),
      ],
    );
  }
}

// ── Anonymous-visitor nudge — you can look, but registering is what makes
// your spot on the board yours to keep (requirement #6: anonymous visitors
// can view the leaderboard but need to register with email to "join" it —
// the same uid just gets a permanent identity via AuthService.linkEmail,
// nothing here is migrated or lost). ──────────────────────────────────────
class _JoinToRankBanner extends StatelessWidget {
  const _JoinToRankBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Text('👀', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "You're viewing as a guest. Register with email to officially join the leaderboard.",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text('Register →',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.mode,
    required this.selectedGame,
    required this.selectedExhibitorName,
    required this.onModeChanged,
    required this.onGameChanged,
    required this.onExhibitorPicked,
  });

  final _LbMode mode;
  final String selectedGame;
  final String selectedExhibitorName;
  final ValueChanged<_LbMode> onModeChanged;
  final ValueChanged<String> onGameChanged;
  final void Function(String id, String name) onExhibitorPicked;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Global',
                  emoji: '🌍',
                  selected: mode == _LbMode.global,
                  onTap: () => onModeChanged(_LbMode.global),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Per Game',
                  emoji: '🎮',
                  selected: mode == _LbMode.perGame,
                  onTap: () => onModeChanged(_LbMode.perGame),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Per Booth',
                  emoji: '🏢',
                  selected: mode == _LbMode.perExhibitor,
                  onTap: () => onModeChanged(_LbMode.perExhibitor),
                ),
              ),
            ],
          ),
          if (mode == _LbMode.perGame) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kGameTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final g = kGameTypes[i];
                  final sel = g.key == selectedGame;
                  return ChoiceChip(
                    label: Text('${g.emoji} ${g.label}'),
                    selected: sel,
                    onSelected: (_) => onGameChanged(g.key),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                    backgroundColor: AppColors.cardBg,
                  );
                },
              ),
            ),
          ],
          if (mode == _LbMode.perExhibitor) ...[
            const SizedBox(height: 10),
            _ExhibitorPicker(
              selectedName: selectedExhibitorName,
              onPicked: onExhibitorPicked,
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(
      {required this.label,
      required this.emoji,
      required this.selected,
      required this.onTap});
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$emoji $label',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected ? Colors.white : AppColors.textDark)),
      ),
    );
  }
}

class _ExhibitorPicker extends StatelessWidget {
  const _ExhibitorPicker(
      {required this.selectedName, required this.onPicked});
  final String selectedName;
  final void Function(String id, String name) onPicked;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<ExhibitorModel>>(
      stream: fs.getExhibitors(),
      builder: (context, snap) {
        final exhibitors = snap.data ?? [];
        if (exhibitors.isEmpty) {
          return const Text('No booths yet.',
              style: TextStyle(color: AppColors.textMedium, fontSize: 12));
        }
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: Text(
              selectedName.isEmpty ? 'Choose a booth' : selectedName,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final picked = await showModalBottomSheet<ExhibitorModel>(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: exhibitors
                        .map((e) => ListTile(
                              leading: const Text('🏢',
                                  style: TextStyle(fontSize: 20)),
                              title: Text(e.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              onTap: () => Navigator.pop(context, e),
                            ))
                        .toList(),
                  ),
                ),
              );
              if (picked != null) onPicked(picked.id, picked.name);
            },
          ),
        );
      },
    );
  }
}

// ── Rows / podium (generic — same widgets for all 3 modes) ────────────────
class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.row});
  final _Row row;

  @override
  Widget build(BuildContext context) {
    final isTop3 = row.rank <= 3;
    final isFirst = row.rank == 1;

    return Container(
      decoration: BoxDecoration(
        color: isTop3 ? AppColors.accent.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isTop3 ? AppColors.accent.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isTop3 ? AppColors.accent : AppColors.primary.withOpacity(0.15),
          child: Text(
            isFirst ? '👑' : '#${row.rank}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isTop3 ? Colors.white : AppColors.primary,
                fontSize: isFirst ? 18 : 13),
          ),
        ),
        title:
            Text(row.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: row.gamesPlayed != null
            ? Text('${row.gamesPlayed} games played')
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient:
                isTop3 ? AppColors.goldGradient : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${row.points} pts',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _PodiumWidget extends StatelessWidget {
  const _PodiumWidget({required this.topThree});
  final List<_Row> topThree;

  @override
  Widget build(BuildContext context) {
    final second = topThree.length > 1 ? topThree[1] : null;
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      color: AppColors.primary.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            Expanded(
                child:
                    _PodiumPosition(row: second, position: 2, height: 140))
          else
            const Spacer(),
          if (first != null)
            Expanded(
                child: _PodiumPosition(row: first, position: 1, height: 180))
          else
            const Spacer(),
          if (third != null)
            Expanded(
                child: _PodiumPosition(row: third, position: 3, height: 120))
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _PodiumPosition extends StatelessWidget {
  const _PodiumPosition({
    required this.row,
    required this.position,
    required this.height,
  });

  final _Row row;
  final int position;
  final double height;

  Color get _backgroundColor {
    switch (position) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(row.medalEmoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${row.points} pts',
            style: TextStyle(
              color: position == 2 ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_backgroundColor, _backgroundColor.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: _backgroundColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                position.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
