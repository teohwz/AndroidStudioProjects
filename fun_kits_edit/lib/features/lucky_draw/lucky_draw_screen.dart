import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_palette.dart';
import '../../core/models/lucky_draw_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/mask_name.dart';
import '../../shared/widgets/register_required_dialog.dart';
import '../../shared/widgets/icon_badge.dart';

class LuckyDrawScreen extends StatefulWidget {
  const LuckyDrawScreen({super.key, this.exhibitorId});

  /// When set (e.g. opened from a booth screen), only that booth's draws
  /// are shown instead of every active draw.
  final String? exhibitorId;

  @override
  State<LuckyDrawScreen> createState() => _LuckyDrawScreenState();
}

class _LuckyDrawScreenState extends State<LuckyDrawScreen> {
  final _fs = FirestoreService();
  String? _joinedDrawId; // the draw this user is currently in
  bool _loadingJoined = true;
  Map<String, String> _winnerNames = {}; // drawId -> winner name

  @override
  void initState() {
    super.initState();
    _loadJoinedDraw();
  }

  Future<void> _loadJoinedDraw() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loadingJoined = false); return; }
    final id = await _fs.getUserActiveDraw(uid);
    if (mounted) setState(() { _joinedDrawId = id; _loadingJoined = false; });
    _loadWinnerNames();
  }

  Stream<List<LuckyDrawModel>> get _draws => widget.exhibitorId != null
      ? _fs.getLuckyDrawsForExhibitor(widget.exhibitorId!)
      : _fs.getLuckyDraws();

  Future<void> _loadWinnerNames() async {
    // Get all draws and load winner names — masked (see maskWinnerName):
    // this screen is visible to every visitor at the booth, not just the
    // winner, so the real name never appears here (contrast with
    // ManageLuckyDrawScreen's exhibitor-facing view, which needs the real
    // name to identify who to hand the prize to).
    final draws = await _draws.first;
    final names = <String, String>{};
    for (final draw in draws) {
      if (draw.winnerUid != null) {
        final name = await _fs.getUserDisplayName(draw.winnerUid!);
        names[draw.id] = maskWinnerName(name);
      }
    }
    if (mounted) setState(() => _winnerNames = names);
  }

  Future<void> _joinDraw(LuckyDrawModel draw) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Joining now requires a registered account (see the Prize Win
    // Notifications round) — a winner always needs somewhere real to be
    // notified. An anonymous visitor is prompted to register instead.
    if (user.isAnonymous) {
      showRegisterRequiredDialog(context, action: 'join a Lucky Draw');
      return;
    }

    // Already in this draw
    if (draw.participants.contains(user.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already joined this draw!')));
      return;
    }

    // Already in a different active draw
    if (_joinedDrawId != null && _joinedDrawId != draw.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You can only join one active draw at a time.')));
      return;
    }

    await _fs.joinLuckyDraw(draw.id, user.uid);
    if (mounted) {
      setState(() => _joinedDrawId = draw.id);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You joined the draw!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingJoined) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Lucky Draw'),
        backgroundColor: palette.luckyDrawColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<LuckyDrawModel>>(
        stream: _draws,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final draws = snap.data ?? [];

          // Once a draw ends (isActive=false), clear joinedDrawId so user can join another
          final activeIds = draws.map((d) => d.id).toSet();
          if (_joinedDrawId != null && !activeIds.contains(_joinedDrawId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _joinedDrawId = null);
            });
          }

          if (draws.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.casino_rounded,
                      size: 56, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No active draws right now.',
                      style: TextStyle(color: palette.textMedium)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: draws.length,
            itemBuilder: (_, i) {
              final draw = draws[i];
              final hasJoined = draw.participants.contains(uid);
              final isMyDraw = _joinedDrawId == draw.id;
              final canJoin = _joinedDrawId == null || isMyDraw;

              return _DrawCard(
                draw: draw,
                hasJoined: hasJoined,
                canJoin: canJoin,
                onJoin: () => _joinDraw(draw),
                winnerName: _winnerNames[draw.id],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Draw Card (visitor view — participate + countdown only) ──────────────────
class _DrawCard extends StatefulWidget {
  const _DrawCard({
    required this.draw,
    required this.hasJoined,
    required this.canJoin,
    required this.onJoin,
    this.winnerName,
  });

  final LuckyDrawModel draw;
  final bool hasJoined;
  final bool canJoin;
  final VoidCallback onJoin;
  final String? winnerName;

  @override
  State<_DrawCard> createState() => _DrawCardState();
}

class _DrawCardState extends State<_DrawCard> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.draw.remaining;
    if (_remaining > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _remaining = widget.draw.remaining);
        if (_remaining == Duration.zero) _ticker?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final color = palette.luckyDrawColor;
    final hasTimer = widget.draw.endsAt != null;
    final ended = widget.draw.hasEnded;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                IconBadge(icon: Icons.casino_rounded, color: color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.draw.title, style: theme.textTheme.titleMedium),
                      Text(widget.draw.prize,
                          style: TextStyle(color: palette.textMedium, fontSize: 13)),
                    ],
                  ),
                ),
                if (widget.hasJoined)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: palette.success),
                        const SizedBox(width: 4),
                        Text('Joined',
                            style: TextStyle(
                                color: palette.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Countdown timer
            if (hasTimer)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ended
                      ? theme.colorScheme.outlineVariant.withOpacity(0.2)
                      : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: ended
                          ? theme.colorScheme.outlineVariant
                          : color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      ended ? Icons.lock_clock_rounded : Icons.timer_outlined,
                      size: 18,
                      color: ended ? palette.textMedium : color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ended
                          ? 'Draw closed'
                          : 'Closes in ${_fmt(_remaining)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ended ? palette.textMedium : color,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 16, color: palette.textMedium),
                const SizedBox(width: 6),
                Text('${widget.draw.participants.length} participants',
                    style: TextStyle(color: palette.textMedium, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 14),

            // Winner banner
            if (widget.draw.winnerUid != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.gold.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        size: 18, color: palette.warning),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          'Winner: ${widget.winnerName ?? "Drawing..."}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: palette.warning)),
                    ),
                  ],
                ),
              )
            else if (!ended && !widget.hasJoined && widget.canJoin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onJoin,
                  icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                  label: const Text('Join Draw'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else if (!widget.canJoin && !widget.hasJoined)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Finish your current draw first',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMedium, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
