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
  String? _winnerName;

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
    _loadWinnerName();
  }

  Future<void> _loadWinnerName() async {
    if (widget.draw.winnerUid == null) return;
    final name = await widget.fs.getUserDisplayName(widget.draw.winnerUid!);
    if (mounted) setState(() => _winnerName = name);
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
    // Only a REGISTERED participant can ever be drawn — joining a draw now
    // requires registration going forward (see the visitor Lucky Draw
    // screen's `_joinDraw`), but a draw already open before this feature
    // may still have anonymous participants from before that gate existed.
    // See FirestoreService.filterRegisteredUids for how "registered" is
    // approximated here.
    final eligible = await widget.fs.filterRegisteredUids(draw.participants);
    if (eligible.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No registered participants to draw from yet — everyone '
                'who joined so far is still anonymous.')));
      }
      return;
    }
    final winnerUid =
        eligible[(DateTime.now().millisecondsSinceEpoch) % eligible.length];
    await widget.fs.setWinner(draw.id, winnerUid);
    await widget.fs.addPoints(winnerUid, 'Winner', 100, gameType: 'lucky_draw');
    await widget.fs.logGameSession(winnerUid, 'lucky_draw', 100,
        exhibitorId: draw.exhibitorId.isNotEmpty ? draw.exhibitorId : null);
    // Logs the win to the shared prize_wins hand-out checklist/"Recent
    // Winners" list, and sends the winner their notification + simulated
    // email — see FirestoreService.recordLuckyDrawPrizeWin.
    await widget.fs.recordLuckyDrawPrizeWin(
      uid: winnerUid,
      boothId: draw.exhibitorId,
      prizeLabel: draw.prize,
    );
    if (mounted) {
      final name = await widget.fs.getUserDisplayName(winnerUid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Winner: $name'),
            ],
          ),
        ),
      );
      setState(() => _winnerName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draw;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final color = palette.luckyDrawColor;
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
              Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      size: 14, color: palette.warning),
                  const SizedBox(width: 4),
                  Text('Winner: ${_winnerName ?? "Loading..."}',
                      style: TextStyle(
                          color: palette.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _prize;
  int _durationHours = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _prize = TextEditingController(text: e?.prize ?? '');
    if (e?.endsAt != null) {
      final hrs = e!.endsAt!.difference(DateTime.now()).inHours;
      _durationHours = hrs.clamp(1, 72);
    }
  }

  @override
  void dispose() {
    _title.dispose(); _prize.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final endsAt = DateTime.now().add(Duration(hours: _durationHours));
    final draw = LuckyDrawModel(
      id: widget.existing?.id ?? '',
      title: _title.text.trim(),
      prize: _prize.text.trim(),
      exhibitorId: widget.boothId,
      isActive: widget.existing?.isActive ?? true,
      participants: widget.existing?.participants ?? [],
      endsAt: endsAt,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Open duration: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _durationHours,
                      items: [1, 2, 6, 12, 24, 48, 72]
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
      {String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
