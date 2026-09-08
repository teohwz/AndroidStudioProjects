import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/models/quiz_model.dart';
import '../../core/models/lucky_draw_model.dart';
import '../../core/services/firestore_service.dart';
import '../quiz/quiz_screen.dart';
import '../lucky_draw/lucky_draw_screen.dart';
import '../puzzle/puzzle_screen.dart';
import '../games/reflex_tap_screen.dart';
import '../games/memory_matrix_screen.dart';
import '../games/code_breaker_screen.dart';
import '../games/rgb_master_screen.dart';
import '../games/speed_typing_screen.dart';

/// The themed landing page a visitor lands on after scanning a booth's QR
/// code — shows that exhibitor's customization (banner/colors/welcome
/// message) and only the games this booth has enabled. Auto check-in fires
/// on entry, matching the manual "Check In" flow on the Exhibitors list
/// (earns +1 shared bonus play at this booth on first visit).
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
              content:
                  Text('✅ Checked in! +1 bonus play earned at this booth.')));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingIn = false);
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
            expandedHeight: 190,
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
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
                            borderRadius: BorderRadius.circular(14),
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
                          child: Text('Checked in — +1 bonus play earned!',
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
                  Text('⚡ Instant Challenges',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  const Text('No setup needed — jump straight in, themed for this booth.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Instant challenges — only the games this exhibitor has enabled
          // for their booth (see ExhibitorGameConfigScreen), themed with
          // their color. Each tile shows whether the visitor still has a
          // free play or bonus play left here — the real gate is
          // FirestoreService.recordGamePlay, fired when the round ends.
          Builder(builder: (context) {
            final defs = <_GameDef>[
              _GameDef('reflex_tap', '⚡', 'Reflex Tap',
                  (accent) => ReflexTapScreen(accentColor: accent, exhibitorId: ex.id)),
              _GameDef('memory_matrix', '🧠', 'Memory Matrix',
                  (accent) => MemoryMatrixScreen(accentColor: accent, exhibitorId: ex.id)),
              _GameDef('code_breaker', '🔐', 'Code Breaker',
                  (accent) => CodeBreakerScreen(accentColor: accent, exhibitorId: ex.id)),
              _GameDef('rgb_master', '🎨', 'RGB Master',
                  (accent) => RgbMasterScreen(accentColor: accent, exhibitorId: ex.id)),
              _GameDef('speed_typing', '⌨️', 'Speed Typing',
                  (accent) => SpeedTypingScreen(accentColor: accent, exhibitorId: ex.id)),
              _GameDef('puzzle', '🧩', 'Slide Puzzle',
                  (accent) => PuzzleScreen(exhibitorId: ex.id)),
            ].where((d) => ex.configFor(d.gameType).enabled).toList();

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
                      emoji: d.emoji,
                      title: d.title,
                      color: color,
                      points: points,
                      remainingPlays: uid == null
                          ? null
                          : _fs.remainingPlays(uid, ex.id, d.gameType),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => d.builder(color))),
                    );
                  },
                  childCount: defs.length,
                ),
              ),
            );
          }),
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
                      const Text('🧠 Quizzes',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                      const SizedBox(height: 10),
                      ...quizzes.map((q) => _GameTile(
                            icon: Icons.quiz_rounded,
                            color: AppColors.quizColor,
                            title: q.title,
                            subtitle: '${q.questionCount} questions · ${q.timeLimitSeconds}s each',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => QuizScreen(initialQuiz: q))),
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
                      const Text('🎰 Lucky Draws',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                      const SizedBox(height: 10),
                      ...draws.map((d) => _GameTile(
                            icon: Icons.casino_rounded,
                            color: AppColors.luckyDrawColor,
                            title: d.title,
                            subtitle: d.prize.isNotEmpty ? '🎁 ${d.prize}' : 'Lucky draw',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => LuckyDrawScreen(exhibitorId: ex.id))),
                          )),
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
  const _GameDef(this.gameType, this.emoji, this.title, this.builder);
  final String gameType;
  final String emoji;
  final String title;
  final Widget Function(Color accent) builder;
}

class _ChallengeTile extends StatefulWidget {
  const _ChallengeTile({
    required this.emoji,
    required this.title,
    required this.color,
    required this.points,
    required this.onTap,
    this.remainingPlays,
  });

  final String emoji;
  final String title;
  final Color color;
  final int points;
  final VoidCallback onTap;
  /// Null when there's no signed-in visitor to check (still tappable, just
  /// no status badge). Resolves to 0 once the free play + any bonus at this
  /// booth are used up — the tile then shows "Played" instead of a points
  /// badge, but tapping still works (the real gate fires when the round
  /// ends and submitGameScore's recordGamePlay call rejects it).
  final Future<int>? remainingPlays;

  @override
  State<_ChallengeTile> createState() => _ChallengeTileState();
}

class _ChallengeTileState extends State<_ChallengeTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
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
                  Text(widget.emoji, style: const TextStyle(fontSize: 26)),
                  if (widget.remainingPlays != null)
                    FutureBuilder<int>(
                      future: widget.remainingPlays,
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox.shrink();
                        final locked = snap.data == 0;
                        return Icon(
                          locked
                              ? Icons.lock_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 16,
                          color: locked
                              ? AppColors.textMedium
                              : widget.color,
                        );
                      },
                    ),
                ],
              ),
              Text(widget.title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: widget.color)),
              if (widget.remainingPlays != null)
                FutureBuilder<int>(
                  future: widget.remainingPlays,
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final locked = snap.data == 0;
                    return Text(
                      locked ? 'Played' : 'Up to ${widget.points} pts',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: locked
                              ? AppColors.textMedium
                              : widget.color.withOpacity(0.8)),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
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
