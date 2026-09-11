import 'package:flutter/material.dart';

import '../../core/constants/game_types.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';
import '../admin/manage_spin_wheel_screen.dart';
import '../admin/manage_scratch_card_screen.dart';
import '../admin/manage_guess_number_screen.dart';
import '../admin/manage_memory_cards_screen.dart';

/// Enable/disable each of the 6 generic booth games and set how many
/// points completing it awards at THIS booth. Quiz and Lucky Draw aren't
/// here — creating one already means "enabled", and their points are set
/// per-quiz/per-draw in their own forms. The "wow" prize games (Spin Wheel,
/// Scratch Card, Guess the Number) live in their own section below — each
/// only shows up on the visitor's booth screen once its own "Customize"
/// editor has real content saved, so there's no enable switch for them.
class ExhibitorGameConfigScreen extends StatelessWidget {
  const ExhibitorGameConfigScreen({super.key, required this.boothId});

  final String boothId;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Game Settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.colorScheme.primary,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Every visitor gets 1 free play per game here, plus one '
                  'shared bonus play (spent on whichever game they pick) '
                  'once they check in to your booth.',
                  style: TextStyle(color: palette.textMedium, fontSize: 12),
                ),
              ),
              for (final g in kGenericBoothGames)
                _GameConfigCard(
                  boothId: boothId,
                  gameType: g.key,
                  label: g.label,
                  icon: g.icon,
                  config: booth.configFor(g.key),
                  fs: fs,
                  customizeBuilder: g.key == 'memory_matrix'
                      ? (context) => ManageMemoryCardsScreen(boothId: boothId)
                      : null,
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded,
                        size: 18, color: palette.textDark),
                    const SizedBox(width: 6),
                    const Text('Prize Games',
                        style:
                            TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'These only appear on your booth once you\'ve customized '
                  'them below — set up their prizes to switch them on.',
                  style: TextStyle(color: palette.textMedium, fontSize: 12),
                ),
              ),
              _PrizeGameCard(
                icon: Icons.autorenew_rounded,
                label: 'Spin Wheel',
                color: palette.spinWheelColor,
                builder: (context) => ManageSpinWheelScreen(boothId: boothId),
              ),
              _PrizeGameCard(
                icon: Icons.layers_rounded,
                label: 'Scratch Card',
                color: palette.scratchCardColor,
                builder: (context) => ManageScratchCardScreen(boothId: boothId),
              ),
              _PrizeGameCard(
                icon: Icons.pin_rounded,
                label: 'Guess the Number',
                color: palette.guessNumberColor,
                builder: (context) => ManageGuessNumberScreen(boothId: boothId),
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
    required this.icon,
    required this.config,
    required this.fs,
    this.customizeBuilder,
  });

  final String boothId;
  final String gameType;
  final String label;
  final IconData icon;
  final BoothGameConfig config;
  final FirestoreService fs;
  /// When set, shows a "Customize" button that pushes this screen — used
  /// only by Memory Matrix right now, for its pair images.
  final WidgetBuilder? customizeBuilder;

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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: palette.textDark),
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
                activeThumbColor: palette.success,
              ),
            ],
          ),
          Row(
            children: [
              Text('Points on completion:',
                  style: TextStyle(fontSize: 12, color: palette.textMedium)),
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
          if (widget.customizeBuilder != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: widget.customizeBuilder!)),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Customize Images'),
              ),
            ),
        ],
      ),
    );
  }
}

/// One of the "wow" prize games — no enable switch, just a button through
/// to that game's own content editor (its Firestore doc's existence is
/// what actually turns it on for visitors).
class _PrizeGameCard extends StatelessWidget {
  const _PrizeGameCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final Color color;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: builder)),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            child: const Text('Customize'),
          ),
        ],
      ),
    );
  }
}
