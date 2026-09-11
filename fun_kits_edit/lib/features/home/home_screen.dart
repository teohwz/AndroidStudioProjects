import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/app_palette.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../app/routes.dart';
import '../notifications/notifications_screen.dart';
import '../../shared/widgets/hero_header.dart';
import '../../shared/widgets/points_pill.dart';
import '../../shared/widgets/feature_tile.dart';
import '../../shared/widgets/action_list_row.dart';
import '../../shared/widgets/section_header.dart';

// ═══════════════════════════════════════════════════════════════════════
//  HOME — UI redesign Phase 2 (Carnival design system). Simplified to the
//  mockup's flat structure: purple hero header (greeting + points), the
//  Scan Booth CTA, a primary 2×2 "Games" grid, and a secondary "More" list
//  for everything else. The old Level/Badge/avatar-editing subsystem and
//  the account menu (Switch Role/Register/Logout) moved to ProfileScreen,
//  reachable from the new "Profile" bottom-nav tab — see profile_screen.dart.
// ═══════════════════════════════════════════════════════════════════════
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

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    if (name == null || name.isEmpty) return '$part! 👋';
    return '$part, $name!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final auth = context.watch<AuthService>();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final primaryFeatures = <_FeatureDef>[
      _FeatureDef(
        icon: Icons.quiz_rounded,
        title: 'Quiz',
        subtitle: 'Test your knowledge',
        color: palette.quizColor,
        route: AppRoutes.quiz,
      ),
      _FeatureDef(
        icon: Icons.casino_rounded,
        title: 'Lucky Draw',
        subtitle: 'Try your luck!',
        color: palette.luckyDrawColor,
        route: AppRoutes.luckyDraw,
      ),
      _FeatureDef(
        icon: Icons.card_giftcard_rounded,
        title: 'Rewards Shop',
        subtitle: 'Redeem e-vouchers',
        color: theme.colorScheme.primary,
        route: AppRoutes.shop,
      ),
      _FeatureDef(
        icon: Icons.leaderboard_rounded,
        title: 'Ranking',
        subtitle: 'Top players',
        color: palette.gold,
        route: AppRoutes.leaderboard,
      ),
    ];

    final secondaryFeatures = <_FeatureDef>[
      _FeatureDef(
        icon: Icons.store_rounded,
        title: 'Exhibitors',
        subtitle: 'Explore booths',
        color: palette.exhibitorColor,
        route: AppRoutes.exhibitor,
      ),
      _FeatureDef(
        icon: Icons.history_rounded,
        title: 'Points History',
        subtitle: 'See where you earned it',
        color: palette.exhibitorColor,
        route: AppRoutes.pointsHistory,
      ),
      _FeatureDef(
        icon: Icons.bar_chart_rounded,
        title: 'My Stats',
        subtitle: 'Most played, scores & time',
        color: palette.quizColor,
        route: AppRoutes.myStats,
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                final streak =
                    (data['loginStreak'] as num?)?.toInt() ?? _lastKnownStreak;

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

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: FadeInDown(
                        duration: const Duration(milliseconds: 450),
                        child: HeroHeader(
                          color: theme.colorScheme.primary,
                          padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _greeting(displayName),
                                      style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white),
                                    ),
                                  ),
                                  _NotificationBell(
                                      uid: auth.currentUser?.uid),
                                ],
                              ),
                              const SizedBox(height: 14),
                              PointsPill(
                                  label: '$points pts',
                                  icon: Icons.stars_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (auth.isAnonymous)
                      SliverToBoxAdapter(
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 80),
                          duration: const Duration(milliseconds: 450),
                          child: _SavePointsBanner(
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.saveProgress),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        delay: const Duration(milliseconds: 120),
                        duration: const Duration(milliseconds: 450),
                        child: _ScanBoothCta(
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.scan),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: const SectionHeader('Games'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.05,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final f = primaryFeatures[i];
                            return FadeInUp(
                              delay: Duration(milliseconds: 160 + i * 60),
                              duration: const Duration(milliseconds: 400),
                              child: FeatureTile(
                                icon: f.icon,
                                color: f.color,
                                label: f.title,
                                subtitle: f.subtitle,
                                onTap: () =>
                                    Navigator.pushNamed(context, f.route),
                              ),
                            );
                          },
                          childCount: primaryFeatures.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: const SectionHeader('More'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final f = secondaryFeatures[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FadeInUp(
                                delay: Duration(
                                    milliseconds: 260 + i * 60),
                                duration: const Duration(milliseconds: 400),
                                child: ActionListRow(
                                  icon: f.icon,
                                  color: f.color,
                                  label: f.title,
                                  subtitle: f.subtitle,
                                  onTap: () =>
                                      Navigator.pushNamed(context, f.route),
                                ),
                              ),
                            );
                          },
                          childCount: secondaryFeatures.length,
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
              colors: [
                theme.colorScheme.primary,
                palette.secondaryGradient.colors.first,
                palette.gold,
                palette.success,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomQuickNav(),
    );
  }
}

// ── Notification bell (Home hero header) ─────────────────────────────────
// Shows an unread-count badge from FirestoreService.watchNotifications and
// opens the NotificationsScreen inbox. Hidden entirely if there's no
// signed-in user yet (a brief window during app bootstrap only).
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final uid = this.uid;
    if (uid == null) return const SizedBox.shrink();
    final fs = FirestoreService();
    return StreamBuilder<List<NotificationModel>>(
      stream: fs.watchNotifications(uid),
      builder: (context, snap) {
        final unread = (snap.data ?? []).where((n) => !n.read).length;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const NotificationsScreen())),
          icon: Badge(
            label: Text('$unread'),
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_rounded, color: Colors.white),
          ),
        );
      },
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
  const _FeatureDef({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

// ── Save-your-points nudge — only shown to anonymous visitors ─────────────
class _SavePointsBanner extends StatelessWidget {
  const _SavePointsBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: palette.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.warning.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: palette.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Points saved on this device only — uninstalling loses them.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Save →',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: palette.warning)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scan CTA — radar-sweep scanner, not a breathing pulse ─────────────────
// A rotating conic gradient sweeps around the icon like an active scanner,
// with a few twinkling sparkle accents drifting around the card. Reads
// instantly as "this is scanning for something" rather than a generic
// heartbeat animation. Pulls its color from the theme's AppPalette so it
// stays coral in light mode and its dark-mode counterpart automatically.
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
    final palette = Theme.of(context).extension<AppPalette>()!;
    final accent = palette.secondaryGradient.colors.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: palette.secondaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: accent.withOpacity(0.35),
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
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 14, color: Colors.white),
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
                            color: accent,
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

// ── Bottom quick-nav bar ─────────────────────────────────────────────────
// Home / Ranking / Rewards / Profile — matches the reference mockup. Scan
// is the big CTA card above, not a nav tab. Only the Home screen shows this
// bar; the other destinations are pushed as ordinary standalone screens
// (same pattern as before this redesign).
class _NavItem {
  final IconData icon;
  final String label;
  final String? route;
  const _NavItem(this.icon, this.label, this.route);
}

class _BottomQuickNav extends StatelessWidget {
  const _BottomQuickNav();

  static const _items = [
    _NavItem(Icons.home_rounded, 'Home', null),
    _NavItem(Icons.leaderboard_rounded, 'Ranking', AppRoutes.leaderboard),
    _NavItem(Icons.card_giftcard_rounded, 'Rewards', AppRoutes.shop),
    _NavItem(Icons.person_rounded, 'Profile', AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
            final color = isHome
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant;
            return GestureDetector(
              onTap: isHome
                  ? null
                  : () => Navigator.pushNamed(context, item.route!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: color, size: 24),
                  const SizedBox(height: 3),
                  Text(item.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isHome ? FontWeight.w800 : FontWeight.w500,
                          color: color)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
