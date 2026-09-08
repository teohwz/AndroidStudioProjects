import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../app/routes.dart';
import '../auth/role_choice_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
//  LEVEL SYSTEM — purely client-side, derived from totalPoints. No new
//  Firestore schema required.
// ═══════════════════════════════════════════════════════════════════════
class _Level {
  final String title;
  final String emoji;
  final int minPoints;
  final Color color;
  const _Level(this.title, this.emoji, this.minPoints, this.color);
}

const _levels = [
  _Level('Rookie', '🌱', 0, Color(0xFF8B8FA3)),
  _Level('Explorer', '🧭', 50, Color(0xFF4ECDC4)),
  _Level('Champion', '⚡', 150, Color(0xFF6C63FF)),
  _Level('Legend', '🔥', 350, Color(0xFFFF6584)),
  _Level('Icon', '👑', 700, Color(0xFFFFD700)),
];

_Level _levelFor(int points) {
  var current = _levels.first;
  for (final l in _levels) {
    if (points >= l.minPoints) current = l;
  }
  return current;
}

_Level? _nextLevelFor(int points) {
  for (final l in _levels) {
    if (points < l.minPoints) return l;
  }
  return null; // maxed out
}

// ═══════════════════════════════════════════════════════════════════════
//  BADGES — computed client-side from points / streak / rank / etc.
// ═══════════════════════════════════════════════════════════════════════
class _Badge {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(_ProfileStats s) unlocked;
  const _Badge(this.id, this.emoji, this.title, this.description, this.unlocked);
}

class _ProfileStats {
  final int points;
  final int gamesPlayed;
  final int loginStreak;
  final int boothsVisited;
  final int? rank;
  const _ProfileStats({
    this.points = 0,
    this.gamesPlayed = 0,
    this.loginStreak = 0,
    this.boothsVisited = 0,
    this.rank,
  });
}

final _allBadges = <_Badge>[
  _Badge('first_steps', '👣', 'First Steps', 'Earn your first points',
      (s) => s.points > 0),
  _Badge('quiz_whiz', '🧠', 'Quiz Whiz', 'Play a quiz game',
      (s) => s.gamesPlayed >= 1),
  _Badge('explorer', '🏢', 'Booth Hopper', 'Check in to a booth',
      (s) => s.boothsVisited >= 1),
  _Badge('on_fire', '🔥', 'On Fire', '3-day login streak',
      (s) => s.loginStreak >= 3),
  _Badge('unstoppable', '⚡', 'Unstoppable', '7-day login streak',
      (s) => s.loginStreak >= 7),
  _Badge('top_ten', '🏆', 'Top 10', 'Reach the top 10 leaderboard',
      (s) => s.rank != null && s.rank! <= 10),
];

const _avatarChoices = [
  '🦁', '🐼', '🦊', '🐸', '🐵', '🐯', '🦄', '🐨',
  '🐙', '🦉', '🐳', '🦋', '🐝', '🦖', '🐷', '🐧',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fs = FirestoreService();
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  int _lastKnownStreak = -1;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final result = await _fs.registerDailyVisit(uid);
      if (mounted) {
        setState(() {
          _lastKnownStreak = result.streak;
          _bootstrapped = true;
        });
        if (result.isNewDay && result.streak > 1) {
          _confetti.play();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _bootstrapped = true);
    }
  }

  Future<void> _editName(String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit your name',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          maxLength: 20,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter a display name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _fs.updateVisitorProfile(uid, displayName: result);
    }
  }

  Future<void> _pickAvatar(String? current) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick your avatar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _avatarChoices.map((emoji) {
                final selected = emoji == current;
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, emoji),
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen != null) {
      await _fs.updateVisitorProfile(uid, avatarEmoji: chosen);
    }
  }

  void _showBadges(_ProfileStats stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Your Badges',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: _allBadges.length,
                itemBuilder: (_, i) =>
                    _BadgeTile(badge: _allBadges[i], stats: stats),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          if (uid == null)
            const Center(child: CircularProgressIndicator())
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _fs.watchUserProfile(uid),
              builder: (context, snap) {
                final data = snap.data?.data() ?? {};
                final points = (data['points'] as num?)?.toInt() ?? 0;
                final displayName = data['displayName'] as String?;
                final avatarEmoji = data['avatarEmoji'] as String? ?? '🦁';
                final streak =
                    (data['loginStreak'] as num?)?.toInt() ?? _lastKnownStreak;
                final gamesPlayed = (data['gamesPlayed'] as num?)?.toInt() ?? 0;
                final boothsVisited =
                    (data['boothsVisited'] as num?)?.toInt() ?? 0;
                // Trigger confetti if the stream reveals a streak bump we
                // hadn't already celebrated in _bootstrap().
                if (_bootstrapped &&
                    streak > _lastKnownStreak &&
                    _lastKnownStreak != -1) {
                  _lastKnownStreak = streak;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _confetti.play());
                } else if (streak > _lastKnownStreak) {
                  _lastKnownStreak = streak;
                }

                final stats = _ProfileStats(
                  points: points,
                  gamesPlayed: gamesPlayed,
                  loginStreak: streak < 0 ? 0 : streak,
                  boothsVisited: boothsVisited,
                );

                return CustomScrollView(
                  slivers: [
                    _buildAppBar(context, auth),
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: _ProfileHeroCard(
                          points: points,
                          displayName: displayName,
                          avatarEmoji: avatarEmoji,
                          streak: stats.loginStreak,
                          onEditName: () => _editName(displayName),
                          onPickAvatar: () => _pickAvatar(avatarEmoji),
                        ),
                      ),
                    ),
                    if (auth.isAnonymous)
                      SliverToBoxAdapter(
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 80),
                          duration: const Duration(milliseconds: 500),
                          child: _SavePointsBanner(
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.saveProgress),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        duration: const Duration(milliseconds: 500),
                        child: _BadgesPreview(
                          stats: stats,
                          onSeeAll: () => _showBadges(stats),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        delay: const Duration(milliseconds: 150),
                        duration: const Duration(milliseconds: 500),
                        child: _ScanBoothCta(
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.scan),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                        child: Text('Explore',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark.withOpacity(0.8))),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final f = _features[i];
                            return FadeInUp(
                              delay: Duration(milliseconds: 180 + i * 60),
                              duration: const Duration(milliseconds: 450),
                              child: _FeatureCard(feature: f),
                            );
                          },
                          childCount: _features.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          // Celebration confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              maxBlastForce: 12,
              minBlastForce: 6,
              emissionFrequency: 0.08,
              numberOfParticles: 24,
              gravity: 0.25,
              shouldLoop: false,
              colors: const [
                AppColors.primary,
                AppColors.secondary,
                AppColors.accent,
                AppColors.success,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomQuickNav(context: context),
    );
  }

  Widget _buildAppBar(BuildContext context, AuthService auth) {
    return SliverAppBar(
      expandedHeight: 90,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          padding: const EdgeInsets.fromLTRB(24, 52, 24, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text('Welcome to 🎪',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
      title: const Text('Fun Kits',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      actions: [
        PopupMenuButton<String>(
          icon: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 20)),
          onSelected: (v) async {
            if (v == 'logout') {
              // A registered (email-linked) visitor logging out lands back
              // on the Visitor Login page — see AuthService.logout(),
              // which records this so future launches do too.
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.visitorLogin, (route) => false);
              }
            } else if (v == 'switch_role') {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoleChoiceScreen()));
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'switch_role', child: Text('Switch Role')),
            if (!auth.isAnonymous)
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
        ),
      ],
    );
  }
}

// ── Feature definitions ──────────────────────────────────────────────────
class _FeatureDef {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final String emoji;
  const _FeatureDef(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.route,
      required this.emoji});
}

// Exhibitor-authored content (Quiz, Lucky Draw) keeps its global Home
// shortcut — visitors can browse every exhibitor's quizzes/draws in one
// place, in addition to the same content showing up filtered on that
// exhibitor's own BoothScreen. Only the procedurally-generated "Instant
// Challenges" (Reflex Tap, Memory Matrix, Code Breaker, RGB Master, Speed
// Typing) and the Slide Puzzle are booth-only, since those need no
// exhibitor setup and the point was to reward scanning a booth to find them.
final _features = <_FeatureDef>[
  _FeatureDef(
    icon: Icons.casino_rounded,
    title: 'Lucky Draw',
    subtitle: 'Try your luck!',
    color: AppColors.luckyDrawColor,
    route: AppRoutes.luckyDraw,
    emoji: '🎰',
  ),
  _FeatureDef(
    icon: Icons.quiz_rounded,
    title: 'Quiz',
    subtitle: 'Test your knowledge',
    color: AppColors.quizColor,
    route: AppRoutes.quiz,
    emoji: '🧠',
  ),
  _FeatureDef(
    icon: Icons.leaderboard_rounded,
    title: 'Leaderboard',
    subtitle: 'Top players',
    color: AppColors.leaderboardColor,
    route: AppRoutes.leaderboard,
    emoji: '🏆',
  ),
  _FeatureDef(
    icon: Icons.store_rounded,
    title: 'Exhibitors',
    subtitle: 'Explore booths',
    color: AppColors.exhibitorColor,
    route: AppRoutes.exhibitor,
    emoji: '🏢',
  ),
  _FeatureDef(
    icon: Icons.card_giftcard_rounded,
    title: 'Rewards Shop',
    subtitle: 'Redeem e-vouchers',
    color: AppColors.primary,
    route: AppRoutes.shop,
    emoji: '🎁',
  ),
  _FeatureDef(
    icon: Icons.history_rounded,
    title: 'Points History',
    subtitle: 'See where you earned it',
    color: AppColors.exhibitorColor,
    route: AppRoutes.pointsHistory,
    emoji: '📜',
  ),
  _FeatureDef(
    icon: Icons.bar_chart_rounded,
    title: 'My Stats',
    subtitle: 'Most played, scores & time',
    color: AppColors.quizColor,
    route: AppRoutes.myStats,
    emoji: '📊',
  ),
];

// ── Save-your-points nudge — only shown to anonymous visitors ─────────────
class _SavePointsBanner extends StatelessWidget {
  const _SavePointsBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Points saved on this device only — uninstalling loses them.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text('Save →',
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

// ═══════════════════════════════════════════════════════════════════════
//  PROFILE HERO CARD
// ═══════════════════════════════════════════════════════════════════════
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.points,
    required this.displayName,
    required this.avatarEmoji,
    required this.streak,
    required this.onEditName,
    required this.onPickAvatar,
  });

  final int points;
  final String? displayName;
  final String avatarEmoji;
  final int streak;
  final VoidCallback onEditName;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final level = _levelFor(points);
    final next = _nextLevelFor(points);
    final double progress = next == null
        ? 1.0
        : ((points - level.minPoints) / (next.minPoints - level.minPoints))
            .clamp(0.0, 1.0)
            .toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onPickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: level.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: level.color, width: 2.5),
                      ),
                      child: Text(avatarEmoji,
                          style: const TextStyle(fontSize: 30)),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded,
                            size: 14, color: AppColors.textMedium),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onEditName,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              (displayName == null || displayName!.isEmpty)
                                  ? 'Set your name'
                                  : displayName!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_rounded,
                              size: 14, color: AppColors.textMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(level.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(level.title,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: level.color)),
                        if (streak > 0) ...[
                          const SizedBox(width: 10),
                          const Text('🔥', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 2),
                          Text('$streak day streak',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: points),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text('$value',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary)),
                  ),
                  const Text('points',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textMedium)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.cardBg,
                valueColor: AlwaysStoppedAnimation(level.color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? 'Max level reached! 👑'
                : '${next.minPoints - points} pts to ${next.title} ${next.emoji}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}

// ── Badges preview row ───────────────────────────────────────────────────
class _BadgesPreview extends StatelessWidget {
  const _BadgesPreview({required this.stats, required this.onSeeAll});

  final _ProfileStats stats;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _allBadges.where((b) => b.unlocked(stats)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: onSeeAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 36,
                child: Stack(
                  children: [
                    for (var i = 0; i < math.min(3, _allBadges.length); i++)
                      Positioned(
                        left: i * 24.0,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _allBadges[i].unlocked(stats)
                                ? AppColors.accent.withOpacity(0.2)
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            _allBadges[i].emoji,
                            style: TextStyle(
                                fontSize: 16,
                                color: _allBadges[i].unlocked(stats)
                                    ? null
                                    : Colors.grey.withOpacity(0.5)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Badges',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('$unlockedCount / ${_allBadges.length} unlocked',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.stats});

  final _Badge badge;
  final _ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final unlocked = badge.unlocked(stats);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.accent.withOpacity(0.1) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: unlocked
                ? AppColors.accent.withOpacity(0.4)
                : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.35,
            child: Text(badge.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(badge.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: unlocked
                            ? AppColors.textDark
                            : AppColors.textMedium)),
                Text(badge.description,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.textMedium)),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18),
        ],
      ),
    );
  }
}

// ── Scan CTA — radar-sweep scanner, not a breathing pulse ─────────────────
// A rotating conic gradient sweeps around the icon like an active scanner,
// with a few twinkling sparkle accents drifting around the card. Reads
// instantly as "this is scanning for something" rather than a generic
// heartbeat animation.
class _ScanBoothCta extends StatefulWidget {
  const _ScanBoothCta({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ScanBoothCta> createState() => _ScanBoothCtaState();
}

class _ScanBoothCtaState extends State<_ScanBoothCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.secondaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: AppColors.secondary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Drifting sparkle accents, phase-offset off one controller.
              // Anchored from the right edge so they hug the card
              // regardless of screen width.
              ..._sparkleAnchors.asMap().entries.map((e) {
                final i = e.key;
                final anchor = e.value;
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final t = (_ctrl.value + i * 0.33) % 1.0;
                    final opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
                    return Positioned(
                      right: anchor.dx,
                      top: anchor.dy,
                      child: Opacity(
                        opacity: opacity,
                        child: const Text('✨', style: TextStyle(fontSize: 14)),
                      ),
                    );
                  },
                );
              }),
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rotating radar-sweep ring behind the icon.
                        AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, _) => Transform.rotate(
                            angle: _ctrl.value * 2 * math.pi,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.9),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                  stops: const [0.0, 0.55, 0.72, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan Booth QR',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        Text('New games, theme & logo at every booth',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _sparkleAnchors = [
  Offset(28, -6),
  Offset(6, 22),
  Offset(18, 48),
];

// ── Feature card w/ press-scale micro-interaction ────────────────────────
class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature});
  final _FeatureDef feature;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  double _scale = 1.0;

  void _setScale(double s) => setState(() => _scale = s);

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return GestureDetector(
      onTapDown: (_) => _setScale(0.94),
      onTapCancel: () => _setScale(1.0),
      onTapUp: (_) => _setScale(1.0),
      onTap: () => Navigator.pushNamed(context, f.route),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: f.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: f.color.withOpacity(0.3), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(f.emoji, style: const TextStyle(fontSize: 28)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: f.color)),
                  Text(f.subtitle,
                      style:
                          TextStyle(fontSize: 11, color: f.color.withOpacity(0.7))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom quick-nav bar ─────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final String? route;
  const _NavItem(this.icon, this.label, this.route);
}

class _BottomQuickNav extends StatelessWidget {
  const _BottomQuickNav({required this.context});
  final BuildContext context;

  static const _items = [
    _NavItem(Icons.home_rounded, 'Home', null),
    _NavItem(Icons.leaderboard_rounded, 'Ranks', AppRoutes.leaderboard),
    _NavItem(Icons.qr_code_scanner_rounded, 'Scan', AppRoutes.scan),
    _NavItem(Icons.store_rounded, 'Booths', AppRoutes.exhibitor),
  ];

  @override
  Widget build(BuildContext _) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _items.map((item) {
            final isHome = item.route == null;
            return GestureDetector(
              onTap: isHome
                  ? null
                  : () => Navigator.pushNamed(context, item.route!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon,
                      color: isHome ? AppColors.primary : AppColors.textMedium,
                      size: 24),
                  const SizedBox(height: 3),
                  Text(item.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: isHome ? FontWeight.w800 : FontWeight.w500,
                          color: isHome
                              ? AppColors.primary
                              : AppColors.textMedium)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
