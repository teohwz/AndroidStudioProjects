import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/leaderboard_model.dart';
import '../../core/services/firestore_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Leaderboard 🏆',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: AppColors.textDark,
      ),
      body: StreamBuilder<List<LeaderboardEntry>>(
        stream: fs.getLeaderboard(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('No scores yet. Play a game!'));
          }

          final topThree = entries.take(3).toList();
          final remaining = entries.skip(3).toList();

          return Column(
            children: [
              // Podium section
              SizedBox(
                height: 240,
                child: _PodiumWidget(topThree: topThree),
              ),
              const Divider(height: 1),
              // Remaining leaderboard
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: remaining.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    return _LeaderRow(entry: remaining[i]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.entry});
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    final isFirst = entry.rank == 1;

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
            isFirst
                ? '👑'
                : '#${entry.rank}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isTop3 ? Colors.white : AppColors.primary,
                fontSize: isFirst ? 18 : 13),
          ),
        ),
        title: Text(entry.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${entry.gamesPlayed} games played'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient:
            isTop3 ? AppColors.goldGradient : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${entry.totalPoints} pts',
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
  final List<LeaderboardEntry> topThree;

  @override
  Widget build(BuildContext context) {
    // Arrange as: 2nd (left), 1st (center/higher), 3rd (right)
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
          // 2nd place (left) - height 140
          if (second != null)
            Expanded(
              child: _PodiumPosition(
                entry: second,
                position: 2,
                height: 140,
              ),
            )
          else
            const Spacer(),
          // 1st place (center) - height 180
          if (first != null)
            Expanded(
              child: _PodiumPosition(
                entry: first,
                position: 1,
                height: 180,
              ),
            )
          else
            const Spacer(),
          // 3rd place (right) - height 120
          if (third != null)
            Expanded(
              child: _PodiumPosition(
                entry: third,
                position: 3,
                height: 120,
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _PodiumPosition extends StatelessWidget {
  const _PodiumPosition({
    required this.entry,
    required this.position,
    required this.height,
  });

  final LeaderboardEntry entry;
  final int position;
  final double height;

  Color get _backgroundColor {
    switch (position) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Medal emoji
        Text(
          entry.medalEmoji,
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 4),
        // Name (truncated)
        Flexible(
          child: Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Points badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${entry.totalPoints} pts',
            style: TextStyle(
              color: position == 2 ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Podium block
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
                  fontSize: 32,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}