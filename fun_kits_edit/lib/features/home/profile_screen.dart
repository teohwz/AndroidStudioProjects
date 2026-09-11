import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_palette.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../app/routes.dart';
import '../auth/role_choice_screen.dart';
import '../auth/visitor_register_screen.dart';
import '../../shared/widgets/hero_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/action_list_row.dart';

// ═══════════════════════════════════════════════════════════════════════
//  LEVEL SYSTEM — purely client-side, derived from totalPoints. No new
//  Firestore schema required. (Moved here from home_screen.dart as part of
//  the UI redesign's Phase 2 — the Home screen now only shows a live
//  points count; the Level/Badge/avatar-editing system lives on this
//  dedicated Profile tab instead.)
// ═══════════════════════════════════════════════════════════════════════
class _Level {
  final String title;
  final IconData icon;
  final int minPoints;
  final Color color;
  const _Level(this.title, this.icon, this.minPoints, this.color);
}

const _levels = [
  _Level('Rookie', Icons.eco_rounded, 0, Color(0xFF8B8FA3)),
  _Level('Explorer', Icons.explore_rounded, 50, Color(0xFF4ECDC4)),
  _Level('Champion', Icons.bolt_rounded, 150, Color(0xFF6C63FF)),
  _Level('Legend', Icons.local_fire_department_rounded, 350, Color(0xFFFF6584)),
  _Level('Icon', Icons.workspace_premium_rounded, 700, Color(0xFFFFD700)),
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
  final IconData icon;
  final String title;
  final String description;
  final bool Function(_ProfileStats s) unlocked;
  const _Badge(this.id, this.icon, this.title, this.description, this.unlocked);
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
  _Badge('first_steps', Icons.flag_rounded, 'First Steps',
      'Earn your first points', (s) => s.points > 0),
  _Badge('quiz_whiz', Icons.psychology_rounded, 'Quiz Whiz',
      'Play a quiz game', (s) => s.gamesPlayed >= 1),
  _Badge('explorer', Icons.storefront_rounded, 'Booth Hopper',
      'Check in to a booth', (s) => s.boothsVisited >= 1),
  _Badge('on_fire', Icons.local_fire_department_rounded, 'On Fire',
      '3-day login streak', (s) => s.loginStreak >= 3),
  _Badge('unstoppable', Icons.bolt_rounded, 'Unstoppable',
      '7-day login streak', (s) => s.loginStreak >= 7),
  _Badge('top_ten', Icons.emoji_events_rounded, 'Top 10',
      'Reach the top 10 leaderboard', (s) => s.rank != null && s.rank! <= 10),
];

// Avatar choices stay emoji by design — these are user-personalization
// picks (like choosing a character), not app iconography, so the Material
// Icons redesign doesn't touch them.
const _avatarChoices = [
  '🦁', '🐼', '🦊', '🐸', '🐵', '🐯', '🦄', '🐨',
  '🐙', '🦉', '🐳', '🦋', '🐝', '🦖', '🐷', '🐧',
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fs = FirestoreService();

  Future<void> _editName(String? current) async {
    final theme = Theme.of(context);
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
            style:
                ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
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
            Text('Pick your avatar', style: theme.textTheme.titleMedium),
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
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : palette.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
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
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Your Badges',
                  style: Theme.of(ctx).textTheme.titleLarge),
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

  Future<void> _logout(AuthService auth) async {
    // A registered (email-linked) visitor logging out lands back on the
    // Visitor Login page — see AuthService.logout(), which records this so
    // future launches do too.
    await auth.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.visitorLogin, (route) => false);
    }
  }

  void _switchRole() {
    // A visitor switching roles can only be switching TO Exhibitor — hide
    // the Visitor card on the screen they land on (see
    // RoleChoiceScreen.hideRole).
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const RoleChoiceScreen(hideRole: 'visitor')));
  }

  void _register() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VisitorRegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final auth = context.watch<AuthService>();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _fs.watchUserProfile(uid),
              builder: (context, snap) {
                final data = snap.data?.data() ?? {};
                final points = (data['points'] as num?)?.toInt() ?? 0;
                final displayName = data['displayName'] as String?;
                final avatarEmoji = data['avatarEmoji'] as String? ?? '🦁';
                final streak = (data['loginStreak'] as num?)?.toInt() ?? 0;
                final gamesPlayed = (data['gamesPlayed'] as num?)?.toInt() ?? 0;
                final boothsVisited =
                    (data['boothsVisited'] as num?)?.toInt() ?? 0;

                final stats = _ProfileStats(
                  points: points,
                  gamesPlayed: gamesPlayed,
                  loginStreak: streak < 0 ? 0 : streak,
                  boothsVisited: boothsVisited,
                );

                final level = _levelFor(points);
                final next = _nextLevelFor(points);
                final progress = next == null
                    ? 1.0
                    : ((points - level.minPoints) /
                            (next.minPoints - level.minPoints))
                        .clamp(0.0, 1.0)
                        .toDouble();

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: HeroHeader(
                        color: theme.colorScheme.primary,
                        padding: const EdgeInsets.fromLTRB(12, 48, 12, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.arrow_back_rounded,
                                      color: Colors.white),
                                ),
                                const Expanded(
                                  child: Text('Profile',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800)),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded,
                                      color: Colors.white),
                                  onSelected: (v) {
                                    if (v == 'logout') {
                                      _logout(auth);
                                    } else if (v == 'switch_role') {
                                      _switchRole();
                                    } else if (v == 'register') {
                                      _register();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'switch_role',
                                        child: Text('Switch Role')),
                                    if (auth.isAnonymous)
                                      const PopupMenuItem(
                                          value: 'register',
                                          child: Text('Register')),
                                    if (!auth.isAnonymous)
                                      const PopupMenuItem(
                                          value: 'logout',
                                          child: Text('Logout')),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _pickAvatar(avatarEmoji),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: level.color, width: 3),
                                          ),
                                          child: Text(avatarEmoji,
                                              style:
                                                  const TextStyle(fontSize: 30)),
                                        ),
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                                color: level.color,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5)),
                                            child: const Icon(
                                                Icons.edit_rounded,
                                                size: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _editName(displayName),
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  (displayName == null ||
                                                          displayName.isEmpty)
                                                      ? 'Set your name'
                                                      : displayName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.edit_rounded,
                                                  size: 14,
                                                  color: Colors.white70),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(level.icon,
                                                size: 14,
                                                color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(level.title,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: Colors.white)),
                                            if (streak > 0) ...[
                                              const SizedBox(width: 10),
                                              const Icon(
                                                  Icons
                                                      .local_fire_department_rounded,
                                                  size: 14,
                                                  color: Colors.white70),
                                              const SizedBox(width: 2),
                                              Text('$streak day streak',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white70,
                                                      fontWeight:
                                                          FontWeight.w600)),
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
                                        duration:
                                            const Duration(milliseconds: 900),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, value, _) => Text(
                                            '$value',
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white)),
                                      ),
                                      const Text('points',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white70)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                          begin: 0.0, end: progress),
                                      duration:
                                          const Duration(milliseconds: 900),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, _) =>
                                          LinearProgressIndicator(
                                        value: value,
                                        minHeight: 8,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.25),
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    next == null
                                        ? 'Max level reached!'
                                        : '${next.minPoints - points} pts to ${next.title}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: SectionHeader(
                          'Badges',
                          padding: EdgeInsets.zero,
                          action: TextButton(
                            onPressed: () => _showBadges(stats),
                            child: const Text('See all'),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _BadgesPreviewRow(
                        stats: stats,
                        onTap: () => _showBadges(stats),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                        child: const SectionHeader('Stats'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.95,
                        ),
                        delegate: SliverChildListDelegate([
                          StatCard(
                              label: 'Games Played',
                              value: '$gamesPlayed',
                              icon: Icons.sports_esports_rounded),
                          StatCard(
                              label: 'Booths Visited',
                              value: '$boothsVisited',
                              icon: Icons.storefront_rounded),
                          StatCard(
                              label: 'Day Streak',
                              value: '$streak',
                              icon: Icons.local_fire_department_rounded),
                        ]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                        child: const SectionHeader('Account'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ActionListRow(
                              icon: Icons.swap_horiz_rounded,
                              color: theme.colorScheme.primary,
                              label: 'Switch Role',
                              subtitle: 'Register as an exhibitor',
                              onTap: _switchRole,
                            ),
                          ),
                          if (auth.isAnonymous)
                            ActionListRow(
                              icon: Icons.person_add_rounded,
                              color: palette.success,
                              label: 'Register',
                              subtitle: 'Save your points to an account',
                              onTap: _register,
                            )
                          else
                            ActionListRow(
                              icon: Icons.logout_rounded,
                              color: palette.danger,
                              label: 'Logout',
                              onTap: () => _logout(auth),
                            ),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ── Badges preview strip ─────────────────────────────────────────────────
class _BadgesPreviewRow extends StatelessWidget {
  const _BadgesPreviewRow({required this.stats, required this.onTap});

  final _ProfileStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final unlockedCount = _allBadges.where((b) => b.unlocked(stats)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 36,
                  child: Stack(
                    children: [
                      for (var i = 0; i < math.min(4, _allBadges.length); i++)
                        Positioned(
                          left: i * 22.0,
                          child: IconBadge(
                            icon: _allBadges[i].icon,
                            color: _allBadges[i].unlocked(stats)
                                ? palette.gold
                                : theme.colorScheme.outlineVariant,
                            style: _allBadges[i].unlocked(stats)
                                ? IconBadgeStyle.solid
                                : IconBadgeStyle.soft,
                            size: 36,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Badges', style: theme.textTheme.titleSmall),
                      Text('$unlockedCount / ${_allBadges.length} unlocked',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final unlocked = badge.unlocked(stats);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? palette.gold.withOpacity(0.1) : palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: unlocked
                ? palette.gold.withOpacity(0.4)
                : theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconBadge(
            icon: badge.icon,
            color: unlocked ? palette.gold : theme.colorScheme.onSurfaceVariant,
            style: unlocked ? IconBadgeStyle.solid : IconBadgeStyle.soft,
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(badge.title,
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: unlocked ? null : theme.colorScheme.onSurfaceVariant)),
                Text(badge.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (unlocked)
            Icon(Icons.check_circle_rounded, color: palette.success, size: 18),
        ],
      ),
    );
  }
}
