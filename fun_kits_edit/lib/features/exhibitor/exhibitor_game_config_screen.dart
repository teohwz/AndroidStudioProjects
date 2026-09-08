import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_types.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/firestore_service.dart';

/// Enable/disable each of the 6 generic booth games and set how many
/// points completing it awards at THIS booth. Quiz and Lucky Draw aren't
/// here — creating one already means "enabled", and their points are set
/// per-quiz/per-draw in their own forms.
class ExhibitorGameConfigScreen extends StatelessWidget {
  const ExhibitorGameConfigScreen({super.key, required this.boothId});

  final String boothId;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Game Settings 🎮',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<ExhibitorModel?>(
        stream: fs.watchExhibitor(boothId),
        builder: (context, snap) {
          final booth = snap.data;
          if (booth == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Every visitor gets 1 free play per game here, plus one '
                  'shared bonus play (spent on whichever game they pick) '
                  'once they check in to your booth.',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                ),
              ),
              for (final g in kGenericBoothGames)
                _GameConfigCard(
                  boothId: boothId,
                  gameType: g.key,
                  label: g.label,
                  emoji: g.emoji,
                  config: booth.configFor(g.key),
                  fs: fs,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GameConfigCard extends StatefulWidget {
  const _GameConfigCard({
    required this.boothId,
    required this.gameType,
    required this.label,
    required this.emoji,
    required this.config,
    required this.fs,
  });

  final String boothId;
  final String gameType;
  final String label;
  final String emoji;
  final BoothGameConfig config;
  final FirestoreService fs;

  @override
  State<_GameConfigCard> createState() => _GameConfigCardState();
}

class _GameConfigCardState extends State<_GameConfigCard> {
  late bool _enabled;
  late TextEditingController _pointsCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.config.enabled;
    _pointsCtrl = TextEditingController(text: '${widget.config.points}');
  }

  @override
  void didUpdateWidget(covariant _GameConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync from Firestore if this card isn't mid-edit, so a live
    // stream update doesn't clobber what the exhibitor is currently typing.
    if (!_dirty) {
      _enabled = widget.config.enabled;
      _pointsCtrl.text = '${widget.config.points}';
    }
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final points = int.tryParse(_pointsCtrl.text.trim()) ?? widget.config.points;
    await widget.fs.updateGameConfig(
      boothId: widget.boothId,
      gameType: widget.gameType,
      enabled: _enabled,
      points: points.clamp(1, 1000),
    );
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Switch(
                value: _enabled,
                onChanged: (v) {
                  setState(() {
                    _enabled = v;
                    _dirty = true;
                  });
                  _save();
                },
                activeThumbColor: AppColors.success,
              ),
            ],
          ),
          Row(
            children: [
              const Text('Points on completion:',
                  style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _pointsCtrl,
                  enabled: _enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  onChanged: (_) => setState(() => _dirty = true),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              if (_dirty)
                TextButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
