import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/lucky_draw_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';
import '../../shared/widgets/fun_button.dart';

class ManageLuckyDrawScreen extends StatefulWidget {
  const ManageLuckyDrawScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ManageLuckyDrawScreen> createState() => _ManageLuckyDrawScreenState();
}

class _ManageLuckyDrawScreenState extends State<ManageLuckyDrawScreen> {
  final _fs = FirestoreService();

  void _showDrawDialog([LuckyDrawModel? existing]) {
    showDialog(
      context: context,
      builder: (_) => _DrawFormDialog(
          fs: _fs, boothId: widget.boothId, existing: existing),
    );
  }

  void _confirmDelete(LuckyDrawModel draw) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Draw?'),
        content: Text('Delete "${draw.title}"? Visitors will no longer see it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _fs.deleteLuckyDraw(draw.id);
            },
            child: Text('Delete', style: TextStyle(color: palette.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Lucky Draws',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.luckyDrawColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDrawDialog(),
        backgroundColor: palette.luckyDrawColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Draw',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<LuckyDrawModel>>(
        stream: _fs.getLuckyDrawsForExhibitorAdmin(widget.boothId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final draws = snap.data ?? [];
          if (draws.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.casino_rounded,
                      size: 64, color: palette.luckyDrawColor),
                  const SizedBox(height: 12),
                  const Text('No draws yet.',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 20),
                  FunButton(
                    label: 'Create Draw',
                    onPressed: () => _showDrawDialog(),
                    gradient: palette.primaryGradient,
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: draws.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _DrawAdminCard(
              draw: draws[i],
              fs: _fs,
              onEdit: () => _showDrawDialog(draws[i]),
              onDelete: () => _confirmDelete(draws[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Admin draw card ────────────────────────────────────────────────────────────
class _DrawAdminCard extends StatefulWidget {
  const _DrawAdminCard({
    required this.draw,
    required this.fs,
    required this.onEdit,
    required this.onDelete,
  });
  final LuckyDrawModel draw;
  final FirestoreService fs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_DrawAdminCard> createState() => _DrawAdminCardState();
}

class _DrawAdminCardState extends State<_DrawAdminCard> {
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
  void dispose() { _ticker?.cancel(); super.dispose(); }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _doDraw() async {
    final draw = widget.draw;
    if (draw.participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No participants yet!')));
      return;
    }
    // Every participant here is already a registered (non-anonymous)
    // account — joining a draw requires registration up front (see the
    // visitor Lucky Draw screen's `_joinDraw`), so no further eligibility
    // check is needed (or even possible: an exhibitor can't read another
    // visitor's profile doc — see FirestoreService's note on this).
    final winnerUid = draw.participants[
        (DateTime.now().millisecondsSinceEpoch) % draw.participants.length];
    try {
      // This is deliberately the ONLY write this method makes. Awarding
      // the 100 points, logging the game session, and recording the prize
      // win all write to documents the WINNER owns (users/leaderboard/
      // prize_wins) — an exhibitor's account can't do any of that (every
      // one of those rules is isOwner-gated), which is exactly why this
      // used to fail right here with no visible error. That part now
      // happens on the winning visitor's own client the next time it sees
      // this draw — see FirestoreService.claimLuckyDrawPrizeIfEligible.
      await widget.fs.setWinner(draw.id, winnerUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Flexible(
                  child: Text('Winner picked! They\'ll be notified once '
                      'they open the app.')),
            ],
          ),
        ));
      }
    } catch (e) {
      // Draw Winner used to fail exactly like this — silently, with
      // nothing shown — when an earlier step threw (see the removed
      // filterRegisteredUids note in FirestoreService). This catch-all
      // makes sure any future failure here is visible instead of invisible.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not draw a winner. Check your connection and try '
                'again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draw;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final color = palette.luckyDrawColor;
    // Confirmed requirement: once a draw is closed — its timer has run out
    // OR a winner has already been picked, whichever comes first — it can
    // no longer be edited. These are two independent signals (a draw can
    // time out with no winner yet, or a winner can be drawn before the
    // timer runs out), so both are checked here rather than relying on
    // just the Active/Closed badge above (which only reflects `isActive`,
    // i.e. only the winner-drawn signal).
    final closed = !d.isActive || d.hasEnded;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.casino_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      Row(
                        children: [
                          Icon(Icons.card_giftcard_rounded,
                              size: 13, color: palette.textMedium),
                          const SizedBox(width: 4),
                          Text(d.prize,
                              style: TextStyle(
                                  color: palette.textMedium, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: d.isActive
                        ? palette.success.withOpacity(0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(d.isActive ? 'Active' : 'Closed',
                      style: TextStyle(
                          color:
                              d.isActive ? palette.success : palette.textMedium,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 13, color: palette.textMedium),
                const SizedBox(width: 4),
                Text('${d.participants.length} participants',
                    style: TextStyle(color: palette.textMedium, fontSize: 13)),
              ],
            ),
            if (d.endsAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: palette.textMedium),
                  const SizedBox(width: 4),
                  Text(
                    d.hasEnded
                        ? 'Ended'
                        : 'Closes in ${_fmt(_remaining)}',
                    style: TextStyle(
                        color: d.hasEnded
                            ? palette.textMedium
                            : palette.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if (d.winnerUid != null) ...[
              const SizedBox(height: 6),
              // Live rather than a one-shot load: this only has a real
              // name once the winner's OWN app has claimed the prize (see
              // FirestoreService.claimLuckyDrawPrizeIfEligible) — an
              // exhibitor can't read a visitor's profile to look it up
              // directly, so this streams from the `prize_wins` record
              // their claim creates and updates itself the moment that
              // happens, with no refresh needed.
              StreamBuilder<String?>(
                stream:
                    widget.fs.watchLuckyDrawWinnerName(d.id, d.winnerUid!),
                builder: (context, snap) {
                  final name = snap.data;
                  return Row(
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          size: 14, color: palette.warning),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                            name != null
                                ? 'Winner: $name'
                                : 'Winner picked — waiting for them to '
                                    'open the app',
                            style: TextStyle(
                                color: palette.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (d.isActive && d.winnerUid == null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _doDraw,
                      icon: const Icon(Icons.emoji_events_rounded, size: 16),
                      label: const Text('Draw Winner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.gold,
                        foregroundColor: palette.textDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (d.isActive && d.winnerUid == null)
                  const SizedBox(width: 8),
                // Hidden entirely once closed (confirmed requirement) —
                // only Delete remains available for a draw that's timed
                // out or already has a winner.
                if (!closed)
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: palette.textMedium, size: 20),
                    onPressed: widget.onEdit,
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: palette.danger, size: 20),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Draw form dialog ───────────────────────────────────────────────────────────
class _DrawFormDialog extends StatefulWidget {
  const _DrawFormDialog(
      {required this.fs, required this.boothId, this.existing});
  final FirestoreService fs;
  final String boothId;
  final LuckyDrawModel? existing;

  @override
  State<_DrawFormDialog> createState() => _DrawFormDialogState();
}

class _DrawFormDialogState extends State<_DrawFormDialog> {
  // The "Open duration" dropdown's fixed preset options — kept as one
  // shared list (rather than duplicated where the DropdownButton builds
  // its items) specifically so initState's nearest-preset snap below can
  // never drift out of sync with what the dropdown actually offers.
  static const _durationPresets = [1, 2, 6, 12, 24, 48, 72];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _prize;
  late final TextEditingController _pointsCtrl;
  int _durationHours = 1;
  String _prizeType = 'points';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _prize = TextEditingController(text: e?.prize ?? '');
    _prizeType = e?.prizeType ?? 'points';
    _pointsCtrl = TextEditingController(text: '${e?.pointsValue ?? 100}');
    if (e?.endsAt != null) {
      // This is the time REMAINING until the existing draw closes, not the
      // duration it was originally created with — a live, ever-changing
      // number (71, 43, whatever "hours left" happens to be right now),
      // while the dropdown below only offers 7 fixed presets. Using it
      // directly as `_durationHours` almost never lands exactly on one of
      // them, which crashed this dialog with a DropdownButton assertion
      // ("There should be exactly one item with ... value: 71") the moment
      // an exhibitor reopened an existing draw to edit it. Snapping to
      // whichever preset is numerically closest keeps the same "roughly
      // how long is left" intent while guaranteeing the dropdown's
      // starting value is always one of its own items.
      final hrs = e!.endsAt!.difference(DateTime.now()).inHours.clamp(1, 72);
      _durationHours = _durationPresets
          .reduce((a, b) => (hrs - a).abs() <= (hrs - b).abs() ? a : b);
    }
  }

  @override
  void dispose() {
    _title.dispose(); _prize.dispose(); _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final endsAt = DateTime.now().add(Duration(hours: _durationHours));
    final isPoints = _prizeType == 'points';
    final draw = LuckyDrawModel(
      id: widget.existing?.id ?? '',
      title: _title.text.trim(),
      prize: _prize.text.trim(),
      exhibitorId: widget.boothId,
      isActive: widget.existing?.isActive ?? true,
      participants: widget.existing?.participants ?? [],
      endsAt: endsAt,
      prizeType: _prizeType,
      pointsValue:
          isPoints ? (int.tryParse(_pointsCtrl.text.trim()) ?? 100) : 0,
    );
    try {
      if (widget.existing == null) {
        await widget.fs.addLuckyDraw(draw);
      } else {
        await widget.fs.updateLuckyDraw(draw);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Draw' : 'Create Lucky Draw',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_title, 'Draw Title *',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),
                _field(_prize, 'Prize Description *',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'points',
                          label: Text('Points'),
                          icon: Icon(Icons.stars_rounded)),
                      ButtonSegment(
                          value: 'physical',
                          label: Text('Physical Prize'),
                          icon: Icon(Icons.card_giftcard_rounded)),
                    ],
                    selected: {_prizeType},
                    onSelectionChanged: (s) =>
                        setState(() => _prizeType = s.first),
                  ),
                ),
                if (_prizeType == 'points') ...[
                  const SizedBox(height: 12),
                  _field(
                    _pointsCtrl,
                    'Points awarded *',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Enter a number > 0';
                      return null;
                    },
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'No points are awarded for a physical prize — the '
                      'winner collects it in person, tracked on the Prize '
                      'Wins screen.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Open duration: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _durationHours,
                      items: _durationPresets
                          .map((h) => DropdownMenuItem(
                              value: h,
                              child: Text('$h hr${h > 1 ? 's' : ''}')))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _durationHours = v!),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: palette.luckyDrawColor),
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? Function(String?)? validator,
      TextInputType? keyboardType}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
