import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scratcher/scratcher.dart';
import 'package:confetti/confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/recent_winners_list.dart';
import '../../shared/widgets/register_required_dialog.dart';
import 'game_common.dart';

/// SCRATCH CARD — the prize is decided the moment the visitor taps "Play"
/// (see FirestoreService.playPrizeGame, the same weighted/atomic draw the
/// Spin Wheel uses), then revealed underneath a scratch-off layer for the
/// satisfying reveal moment. Card image, message, and prize pool are all
/// exhibitor-set — see ManageScratchCardScreen.
class ScratchCardScreen extends StatefulWidget {
  const ScratchCardScreen({
    super.key,
    this.accentColor = AppColors.primary,
    required this.exhibitorId,
    this.title = 'Scratch Card',
  });

  final Color accentColor;
  final String exhibitorId;
  final String title;

  @override
  State<ScratchCardScreen> createState() => _ScratchCardScreenState();
}

class _ScratchCardScreenState extends State<ScratchCardScreen> {
  final _fs = FirestoreService();
  late final ConfettiController _confetti;

  ScratchCardConfig? _config;
  bool _loading = true;
  String _phase = 'idle'; // idle | playing | revealing
  PrizeSegment? _won;
  bool _thresholdFired = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _fs.getScratchCardConfig(widget.exhibitorId);
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Future<void> _play() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Playing now requires a registered account (see the Prize Win
    // Notifications round) — a winner always needs somewhere real to be
    // notified. An anonymous visitor is prompted to register instead.
    if (user.isAnonymous) {
      showRegisterRequiredDialog(context, action: 'play the scratch card');
      return;
    }
    setState(() => _phase = 'playing');

    final result = await _fs.playPrizeGame(
      uid: user.uid,
      userName: user.displayName ?? 'Player',
      boothId: widget.exhibitorId,
      gameType: 'scratch_card',
    );

    if (!mounted) return;
    if (!result.success) {
      setState(() => _phase = 'idle');
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

    setState(() {
      _won = result.segment;
      _phase = 'revealing';
      _thresholdFired = false;
    });
  }

  void _onThreshold() {
    if (_thresholdFired) return;
    _thresholdFired = true;
    _confetti.play();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || _won == null) return;
      final won = _won!;
      showGameResultDialog(
        context,
        icon: won.isPoints ? Icons.star_rounded : Icons.card_giftcard_rounded,
        title: won.isPoints ? 'You Won!' : 'You Won a Prize!',
        message: won.isPoints
            ? '+${won.pointsValue} points!'
            : '${won.label} — show this screen to the booth staff to collect it!',
        color: widget.accentColor,
        onPlayAgain: () => setState(() => _phase = 'idle'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final config = _config;
    final hasPrizes = config != null && config.hasAvailablePrize;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: gameAppBar(widget.title, color),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasPrizes
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_rounded, size: 64, color: color),
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
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1.5,
                                child: _phase == 'revealing' && _won != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Scratcher(
                                          brushSize: 40,
                                          threshold: 55,
                                          color: color,
                                          onThreshold: _onThreshold,
                                          child: _RevealContent(
                                            imageUrl: config.cardImageUrl,
                                            won: _won!,
                                            message: config.revealMessage,
                                          ),
                                        ),
                                      )
                                    : _CardBack(
                                        imageUrl: config.cardImageUrl,
                                        color: color,
                                        loading: _phase == 'playing',
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_phase == 'idle')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _play,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('TAP TO PLAY',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                  ],
                                ),
                              ),
                            )
                          else if (_phase == 'revealing')
                            Text('Scratch the card to reveal your prize!',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: palette.textMedium)),
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
                        colors: [color, palette.gold, palette.success],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack(
      {required this.imageUrl, required this.color, required this.loading});
  final String imageUrl;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.confirmation_number_rounded,
                    size: 56, color: Colors.white),
                SizedBox(height: 8),
                Text('Mystery Card',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ],
            ),
    );
  }
}

class _RevealContent extends StatelessWidget {
  const _RevealContent(
      {required this.imageUrl, required this.won, required this.message});
  final String imageUrl;
  final PrizeSegment won;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Container(
      decoration: BoxDecoration(color: palette.cardBg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(won.isPoints ? Icons.star_rounded : Icons.card_giftcard_rounded,
                    size: 40, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  won.isPoints ? '+${won.pointsValue} points' : won.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
