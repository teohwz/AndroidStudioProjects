import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_types.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/models/quiz_model.dart';
import '../../core/models/lucky_draw_model.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/action_list_row.dart';
import '../../shared/widgets/checkable_task_row.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/points_pill.dart';
import '../quiz/quiz_screen.dart';
import '../lucky_draw/lucky_draw_screen.dart';
import '../puzzle/puzzle_screen.dart';
import '../games/reflex_tap_screen.dart';
import '../games/memory_matrix_screen.dart';
import '../games/code_breaker_screen.dart';
import '../games/rgb_master_screen.dart';
import '../games/speed_typing_screen.dart';
import '../games/spin_wheel_screen.dart';
import '../games/scratch_card_screen.dart';
import '../games/guess_number_screen.dart';
import '../../core/models/game_content_model.dart';

/// The themed landing page a visitor lands on after scanning a booth's QR
/// code — shows that exhibitor's customization (banner/colors/welcome
/// message) and only the games this booth has enabled. Auto check-in fires
/// on entry, matching the manual "Check In" flow on the Exhibitors list
/// (earns +1 attempt in this booth's shared pool on first visit — see
/// BoothAttemptPool). Also (re-)assigns the "Play a Mini-Game" task's 2
/// named games fresh on every open — see _assignMinigameTasks.
class BoothScreen extends StatefulWidget {
  const BoothScreen({super.key, required this.exhibitor});

  final ExhibitorModel exhibitor;

  @override
  State<BoothScreen> createState() => _BoothScreenState();
}

class _BoothScreenState extends State<BoothScreen> {
  final _fs = FirestoreService();
  bool _checkingIn = true;
  bool _justCheckedIn = false;

  @override
  void initState() {
    super.initState();
    _checkIn();
  }

  Future<void> _checkIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _checkingIn = false);
      return;
    }
    // Fire the mini-game task's fresh random assignment alongside check-in
    // — independent of whether this is a new check-in, since it's meant to
    // re-roll every time the visitor opens this booth.
    unawaited(_assignMinigameTasks(uid));
    try {
      final isNew = await _fs.checkInBooth(uid, widget.exhibitor.id);
      if (!mounted) return;
      setState(() {
        _checkingIn = false;
        _justCheckedIn = isNew;
      });
      if (isNew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
                child: Text('Checked in! +1 attempt earned at this booth.')),
          ])));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  /// Picks (or re-rolls) the up-to-2 generic games named on the "Play a
  /// Mini-Game" booth task, from whichever of this booth's generic games
  /// are currently enabled — see FirestoreService.setMinigameTaskKeys.
  Future<void> _assignMinigameTasks(String uid) async {
    final eligible = kGenericBoothGames
        .where((g) => widget.exhibitor.configFor(g.key).enabled)
        .map((g) => g.key)
        .toList();
    try {
      await _fs.setMinigameTaskKeys(uid, widget.exhibitor.id, eligible);
    } catch (_) {
      // Non-critical — the Booth Tasks section simply won't show a
      // mini-game task this visit if this fails.
    }
  }

  /// Opens [rawUrl] in an external browser/app, prefixing `https://` when
  /// the exhibitor saved a bare domain (e.g. "facebook.com/acme").
  Future<void> _openLink(String rawUrl) async {
    final hasScheme = rawUrl.startsWith('http://') || rawUrl.startsWith('https://');
    final uri = Uri.tryParse(hasScheme ? rawUrl : 'https://$rawUrl');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort — nothing to show the visitor if their device has no
      // app/browser able to handle it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exhibitor;
    final color = ex.themeColor;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: ex.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 214,
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  image: ex.hasBanner
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(ex.bannerImageUrl),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.35),
                              BlendMode.darken),
                        )
                      : null,
                  gradient: ex.hasBanner
                      ? null
                      : LinearGradient(
                          colors: [color, ex.secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 58, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ex.logoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: ex.logoUrl, fit: BoxFit.cover)
                              : Icon(Icons.store_rounded,
                                  color: color, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                              if (ex.boothNumber.isNotEmpty || ex.category.isNotEmpty)
                                Text(
                                    [
                                      if (ex.boothNumber.isNotEmpty) 'Booth ${ex.boothNumber}',
                                      ex.category,
                                    ].join(' · '),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (uid != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: StreamBuilder<BoothAttemptPool>(
                          stream: _fs.watchAttemptPool(uid, ex.id),
                          builder: (context, snap) {
                            final remaining = snap.data?.attemptsRemaining;
                            if (remaining == null) {
                              return const SizedBox.shrink();
                            }
                            return PointsPill(
                              label: remaining == 1
                                  ? '1 attempt left'
                                  : '$remaining attempts left',
                              icon: Icons.confirmation_number_rounded,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_checkingIn)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Checking in...',
                            style: TextStyle(color: AppColors.textMedium)),
                      ]),
                    )
                  else if (_justCheckedIn)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Checked in — +1 attempt earned!',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  if (ex.welcomeMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.25)),
                      ),
                      child: Text(ex.welcomeMessage,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic)),
                    ),
                  if (ex.description.isNotEmpty) ...[
                    Text(ex.description,
                        style: const TextStyle(color: AppColors.textMedium)),
                    const SizedBox(height: 14),
                  ],
                  if (ex.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ex.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(t,
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  const SectionHeader('Instant Challenges',
                      padding: EdgeInsets.only(bottom: 4)),
                  const Text('No setup needed — jump straight in, themed for this booth.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Instant challenges — only the games this exhibitor has enabled
          // for their booth (see ExhibitorGameConfigScreen), themed with
          // their color. Every tile shows the SAME shared-pool "attempts
          // left" count (see BoothAttemptPool) — the real gate is
          // FirestoreService.recordGamePlay, fired when the round ends.
          StreamBuilder<BoothAttemptPool>(
            stream: uid == null ? null : _fs.watchAttemptPool(uid, ex.id),
            builder: (context, poolSnap) {
              final pool = poolSnap.data;
              final defs = _genericGameDefs(ex.id)
                  .where((d) => ex.configFor(d.gameType).enabled)
                  .toList();

              if (defs.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final d = defs[i];
                      final points = ex.configFor(d.gameType).points;
                      return _ChallengeTile(
                        icon: d.icon,
                        title: d.title,
                        color: color,
                        points: points,
                        remaining: uid == null ? null : pool?.attemptsRemaining,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => d.builder(color))),
                      );
                    },
                    childCount: defs.length,
                  ),
                ),
              );
            },
          ),
          // Booth Tasks — earn up to 2 more shared attempts at this
          // booth: +1 for following the exhibitor (any one of Facebook/
          // Instagram/Website), +1 for finishing a round of either of the
          // 2 mini-games named below (see _assignMinigameTasks). Hidden
          // entirely if this booth has neither a follow link nor an
          // enabled generic game to offer.
          if (uid != null)
            StreamBuilder<BoothAttemptPool>(
              stream: _fs.watchAttemptPool(uid, ex.id),
              builder: (context, poolSnap) {
                final pool = poolSnap.data ?? const BoothAttemptPool();
                final taskDefs = _genericGameDefs(ex.id)
                    .where((d) => pool.taskGameKeys.contains(d.gameType))
                    .toList();
                final showFollow = ex.hasFollowLinks;
                final showMinigame = taskDefs.isNotEmpty;
                if (!showFollow && !showMinigame) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader('Booth Tasks',
                            padding: EdgeInsets.only(bottom: 4)),
                        const Text(
                            'Complete these to earn extra attempts at this booth.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMedium)),
                        const SizedBox(height: 10),
                        if (showFollow)
                          _FollowTaskCard(
                            exhibitor: ex,
                            color: color,
                            earned: pool.followEarned,
                            onTapLink: (url) async {
                              await _openLink(url);
                              await _fs.creditFollowTask(uid, ex.id);
                            },
                          ),
                        if (showMinigame)
                          _MinigameTaskCard(
                            defs: taskDefs,
                            color: color,
                            earned: pool.minigameEarned,
                            onPlay: (d) => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => d.builder(color))),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // Booth-specific quizzes (exhibitor-authored content)
          SliverToBoxAdapter(
            child: StreamBuilder<List<QuizModel>>(
              stream: _fs.getQuizzesForExhibitor(ex.id),
              builder: (context, snap) {
                final quizzes = snap.data ?? [];
                if (quizzes.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Quizzes',
                          padding: EdgeInsets.only(bottom: 10)),
                      ...quizzes.map((q) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ActionListRow(
                              icon: Icons.quiz_rounded,
                              color: AppColors.quizColor,
                              label: q.title,
                              subtitle:
                                  '${q.questionCount} questions · ${q.timeLimitSeconds}s each',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => QuizScreen(initialQuiz: q))),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
          // Booth-specific lucky draws (exhibitor-authored content)
          SliverToBoxAdapter(
            child: StreamBuilder<List<LuckyDrawModel>>(
              stream: _fs.getLuckyDrawsForExhibitor(ex.id),
              builder: (context, snap) {
                final draws = snap.data ?? [];
                if (draws.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Lucky Draws',
                          padding: EdgeInsets.only(bottom: 10)),
                      ...draws.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ActionListRow(
                              icon: Icons.casino_rounded,
                              color: AppColors.luckyDrawColor,
                              label: d.title,
                              subtitle:
                                  d.prize.isNotEmpty ? d.prize : 'Lucky draw',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          LuckyDrawScreen(exhibitorId: ex.id))),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
          // Spin Wheel — only shown once the exhibitor has set up prizes
          // for it (see ManageSpinWheelScreen). One booth's wheel is
          // never themed like another's — see SpinWheelScreen's own
          // per-booth color rotation.
          SliverToBoxAdapter(
            child: StreamBuilder<SpinWheelConfig?>(
              stream: _fs.watchSpinWheelConfig(ex.id),
              builder: (context, snap) {
                final config = snap.data;
                if (config == null || !config.hasAvailablePrize) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Spin Wheel',
                          padding: EdgeInsets.only(bottom: 10)),
                      ActionListRow(
                        icon: Icons.autorenew_rounded,
                        color: AppColors.spinWheelColor,
                        label: 'Spin to Win',
                        subtitle: '${config.segments.length} prizes up for grabs',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SpinWheelScreen(
                                    accentColor: color, exhibitorId: ex.id))),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Scratch Card — same "only if configured" gating as Spin Wheel.
          SliverToBoxAdapter(
            child: StreamBuilder<ScratchCardConfig?>(
              stream: _fs.watchScratchCardConfig(ex.id),
              builder: (context, snap) {
                final config = snap.data;
                if (config == null || !config.hasAvailablePrize) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Scratch Card',
                          padding: EdgeInsets.only(bottom: 10)),
                      ActionListRow(
                        icon: Icons.layers_rounded,
                        color: AppColors.scratchCardColor,
                        label: 'Scratch & Win',
                        subtitle: config.revealMessage,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ScratchCardScreen(
                                    accentColor: color, exhibitorId: ex.id))),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Guess the Number — same "only if configured" gating.
          SliverToBoxAdapter(
            child: StreamBuilder<GuessNumberConfig?>(
              stream: _fs.watchGuessNumberConfig(ex.id),
              builder: (context, snap) {
                final config = snap.data;
                if (config == null || !config.hasContent) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Guess the Number',
                          padding: EdgeInsets.only(bottom: 10)),
                      ActionListRow(
                        icon: Icons.pin_rounded,
                        color: AppColors.guessNumberColor,
                        label: 'Guess the Number',
                        subtitle:
                            '${config.minValue}–${config.maxValue} · +${config.rewardPoints} points',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => GuessNumberScreen(
                                    accentColor: color, exhibitorId: ex.id))),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (ex.contactEmail.isNotEmpty ||
              ex.contactPhone.isNotEmpty ||
              ex.website.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: color)),
                      const SizedBox(height: 8),
                      if (ex.contactEmail.isNotEmpty)
                        _ContactRow(Icons.email_outlined, ex.contactEmail),
                      if (ex.contactPhone.isNotEmpty)
                        _ContactRow(Icons.phone_outlined, ex.contactPhone),
                      if (ex.website.isNotEmpty)
                        _ContactRow(Icons.language_outlined, ex.website),
                    ],
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

/// One of the 6 generic booth games — pairs its key (for gameConfig lookup)
/// with a builder that constructs the actual game screen once the visitor
/// taps in, themed with the booth's accent color.
class _GameDef {
  const _GameDef(this.gameType, this.icon, this.title, this.builder);
  final String gameType;
  final IconData icon;
  final String title;
  final Widget Function(Color accent) builder;
}

/// All 6 generic booth games (unfiltered by whether this booth has them
/// enabled) — shared by the Instant Challenges grid (filtered to enabled
/// games) and the Booth Tasks mini-game card (filtered to
/// BoothAttemptPool.taskGameKeys). Icons mirror game_types.dart's registry
/// so the same game always reads the same icon everywhere in the app.
List<_GameDef> _genericGameDefs(String exId) => [
      _GameDef('reflex_tap', Icons.bolt_rounded, 'Reflex Tap',
          (accent) => ReflexTapScreen(accentColor: accent, exhibitorId: exId)),
      _GameDef('memory_matrix', Icons.style_rounded, 'Memory Cards',
          (accent) => MemoryMatrixScreen(accentColor: accent, exhibitorId: exId)),
      _GameDef('code_breaker', Icons.lock_rounded, 'Code Breaker',
          (accent) => CodeBreakerScreen(accentColor: accent, exhibitorId: exId)),
      _GameDef('rgb_master', Icons.palette_rounded, 'RGB Master',
          (accent) => RgbMasterScreen(accentColor: accent, exhibitorId: exId)),
      _GameDef('speed_typing', Icons.keyboard_rounded, 'Speed Typing',
          (accent) => SpeedTypingScreen(accentColor: accent, exhibitorId: exId)),
      _GameDef('puzzle', Icons.extension_rounded, 'Slide Puzzle',
          (accent) => PuzzleScreen(exhibitorId: exId)),
    ];

class _ChallengeTile extends StatefulWidget {
  const _ChallengeTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.points,
    required this.onTap,
    this.remaining,
  });

  final IconData icon;
  final String title;
  final Color color;
  final int points;
  final VoidCallback onTap;
  /// Attempts left in this booth's SHARED pool (see BoothAttemptPool) —
  /// the same number on every tile at this booth, not per-game. Null when
  /// there's no signed-in visitor to check yet (still tappable, just no
  /// status badge). 0 once the pool is exhausted — the tile then shows "No
  /// attempts left" instead of a points badge, but tapping still works
  /// (the real gate fires when the round ends and submitGameScore's
  /// recordGamePlay call rejects it).
  final int? remaining;

  @override
  State<_ChallengeTile> createState() => _ChallengeTileState();
}

class _ChallengeTileState extends State<_ChallengeTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final remaining = widget.remaining;
    final locked = remaining == 0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color.withOpacity(0.16), widget.color.withOpacity(0.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.3), width: 1.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconBadge(icon: widget.icon, color: widget.color, size: 40),
                  if (remaining != null)
                    Icon(
                      locked ? Icons.lock_rounded : Icons.play_circle_fill_rounded,
                      size: 16,
                      color: locked ? AppColors.textMedium : widget.color,
                    ),
                ],
              ),
              Text(widget.title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: widget.color)),
              if (remaining != null)
                Text(
                  locked ? 'No attempts left' : '$remaining left · +${widget.points} pts',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: locked
                          ? AppColors.textMedium
                          : widget.color.withOpacity(0.8)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.textMedium),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMedium))),
        ]),
      );
}

/// "Follow the Exhibitor" Booth Task card — up to 3 sub-tasks (Facebook,
/// Instagram, Website), each shown only when the exhibitor has set that
/// link. Tapping ANY ONE opens the link and credits +1 attempt; the
/// category caps at +1 total regardless of how many are tapped.
class _FollowTaskCard extends StatelessWidget {
  const _FollowTaskCard({
    required this.exhibitor,
    required this.color,
    required this.earned,
    required this.onTapLink,
  });

  final ExhibitorModel exhibitor;
  final Color color;
  final bool earned;
  final Future<void> Function(String url) onTapLink;

  @override
  Widget build(BuildContext context) {
    final links = <(IconData, String, String)>[
      if (exhibitor.hasFacebook)
        (Icons.facebook_rounded, 'Facebook', exhibitor.facebookUrl),
      if (exhibitor.hasInstagram)
        (Icons.camera_alt_rounded, 'Instagram', exhibitor.instagramUrl),
      if (exhibitor.website.isNotEmpty)
        (Icons.language_rounded, 'Website', exhibitor.website),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Follow the Exhibitor',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ),
              if (earned)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            earned ? 'Earned +1 attempt' : 'Tap any one below to earn +1 attempt',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMedium),
          ),
          const SizedBox(height: 8),
          ...links.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CheckableTaskRow(
                  icon: l.$1,
                  label: 'Visit our ${l.$2}',
                  earned: earned,
                  onTap: () => onTapLink(l.$3),
                ),
              )),
        ],
      ),
    );
  }
}

/// "Play a Mini-Game" Booth Task card — up to 2 dynamically-named games
/// (see BoothAttemptPool.taskGameKeys / _assignMinigameTasks). Finishing a
/// full round of either credits +1 attempt automatically (handled
/// server-side by FirestoreService.recordGamePlay) — tapping a row here
/// just opens the same game screen as its Instant Challenges tile.
class _MinigameTaskCard extends StatelessWidget {
  const _MinigameTaskCard({
    required this.defs,
    required this.color,
    required this.earned,
    required this.onPlay,
  });

  final List<_GameDef> defs;
  final Color color;
  final bool earned;
  final void Function(_GameDef def) onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Play a Mini-Game',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ),
              if (earned)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            earned
                ? 'Earned +1 attempt'
                : 'Finish either round below to earn +1 attempt',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMedium),
          ),
          const SizedBox(height: 8),
          ...defs.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CheckableTaskRow(
                  icon: d.icon,
                  label: 'Play the mini-game (${d.title})',
                  earned: earned,
                  onTap: () => onPlay(d),
                ),
              )),
        ],
      ),
    );
  }
}
