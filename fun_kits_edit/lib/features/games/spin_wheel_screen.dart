import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:confetti/confetti.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/recent_winners_list.dart';
import '../../shared/widgets/register_required_dialog.dart';
import 'game_common.dart';

/// SPIN WHEEL — an exhibitor-configurable prize wheel. Every booth's wheel
/// is themed automatically around that booth's own accent color (a rainbow
/// of hues rotated from it), so the wheel actually looks different at every
/// booth a visitor spins at. Each segment independently pays out flat
/// points or a limited-stock physical prize — see FirestoreService.
/// playPrizeGame for the actual (weighted, atomic) draw.
class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({
    super.key,
    this.accentColor = AppColors.primary,
    required this.exhibitorId,
    this.title = 'Spin Wheel',
  });

  final Color accentColor;
  final String exhibitorId;
  final String title;

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen> {
  final _fs = FirestoreService();
  final _selectedController = StreamController<int>.broadcast();
  late final ConfettiController _confetti;

  List<PrizeSegment> _segments = [];
  List<Color> _colors = [];
  bool _loading = true;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _load();
  }

  @override
  void dispose() {
    _selectedController.close();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _fs.getSpinWheelConfig(widget.exhibitorId);
    if (!mounted) return;
    final segments = config?.segments ?? [];
    setState(() {
      _segments = segments;
      _colors = _wheelColors(widget.accentColor, segments.length);
      _loading = false;
    });
  }

  /// Rotates a rainbow of hues out from the booth's own accent color, one
  /// per segment — themed to this booth, distinct from every other one.
  List<Color> _wheelColors(Color base, int count) {
    if (count == 0) return [];
    final hsl = HSLColor.fromColor(base);
    return List.generate(count, (i) {
      final hue = (hsl.hue + (360 / count) * i) % 360;
      return HSLColor.fromAHSL(
              1, hue, hsl.saturation.clamp(0.45, 0.85), 0.55)
          .toColor();
    });
  }

  Future<void> _spin() async {
    if (_spinning || _segments.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Playing now requires a registered account (see the Prize Win
    // Notifications round) — a winner always needs somewhere real to be
    // notified. An anonymous visitor is prompted to register instead.
    if (user.isAnonymous) {
      showRegisterRequiredDialog(context, action: 'spin the wheel');
      return;
    }
    setState(() => _spinning = true);

    final result = await _fs.playPrizeGame(
      uid: user.uid,
      userName: user.displayName ?? 'Player',
      boothId: widget.exhibitorId,
      gameType: 'spin_wheel',
    );

    if (!mounted) return;
    if (!result.success) {
      setState(() => _spinning = false);
      if (result.failureReason == 'play_limit_reached') {
        showPlayLimitDialog(context, color: widget.accentColor);
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sentiment_dissatisfied_rounded,
                    size: 48, color: widget.accentColor),
                const SizedBox(height: 8),
                const Text('All out of prizes right now — check back later!',
                    textAlign: TextAlign.center),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back to Booth')),
            ],
          ),
        );
      }
      return;
    }

    final won = result.segment!;
    var index = _segments.indexWhere((s) => s.id == won.id);
    if (index < 0) index = 0; // segment list changed since load; still animate
    _selectedController.add(index);

    await Future.delayed(const Duration(milliseconds: 4200));
    if (!mounted) return;
    setState(() => _spinning = false);
    _confetti.play();

    showGameResultDialog(
      context,
      icon: won.isPoints ? Icons.star_rounded : Icons.card_giftcard_rounded,
      title: won.isPoints ? 'You Won!' : 'You Won a Prize!',
      message: won.isPoints
          ? '+${won.pointsValue} points!'
          : '${won.label} — show this screen to the booth staff to collect it!',
      color: widget.accentColor,
      onPlayAgain: _spin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: gameAppBar(widget.title, color),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _segments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.autorenew_rounded, size: 64, color: color),
                      const SizedBox(height: 12),
                      Text('This booth hasn\'t set up any prizes yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.textMedium)),
                    ],
                  ),
                )
              : Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Expanded(
                            child: FortuneWheel(
                              selected: _selectedController.stream,
                              physics: CircularPanPhysics(
                                duration: const Duration(milliseconds: 4000),
                                curve: Curves.decelerate,
                              ),
                              items: [
                                for (var i = 0; i < _segments.length; i++)
                                  FortuneItem(
                                    style: FortuneItemStyle(
                                      color: _colors[i],
                                      borderColor: Colors.white,
                                      borderWidth: 2,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        _segments[i].label,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _spinning ? null : _spin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_spinning) ...[
                                    const Icon(Icons.autorenew_rounded, size: 18),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                      _spinning ? 'Spinning...' : 'SPIN THE WHEEL',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          RecentWinnersList(
                              boothId: widget.exhibitorId, color: color),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confetti,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                        numberOfParticles: 30,
                        colors: _colors,
                      ),
                    ),
                  ],
                ),
    );
  }
}
