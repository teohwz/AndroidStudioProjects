import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_palette.dart';
import 'game_common.dart';

/// REFLEX TAP — a single tile lights up in a grid; tap it before it fades.
/// Speed ramps up with every correct hit. Three misses (wrong tap, or the
/// tile timing out) ends the round.
///
/// This one screen stands in for the "tap the lit/correct target" family of
/// booth game ideas (Catch the Light, Whack-a-Mole, Reflex Wall, Target
/// Shooter, Zombie Defense) — they're all the same core reflex mechanic
/// re-skinned, so rather than ship five near-duplicates we ship one solid,
/// well-tuned version. An exhibitor can reflavor it with their own title.
class ReflexTapScreen extends StatefulWidget {
  const ReflexTapScreen({
    super.key,
    this.accentColor = AppColors.primary,
    this.exhibitorId,
    this.title = 'Reflex Tap',
  });

  final Color accentColor;
  final String? exhibitorId;
  final String title;

  @override
  State<ReflexTapScreen> createState() => _ReflexTapScreenState();
}

class _ReflexTapScreenState extends State<ReflexTapScreen> {
  static const int _crossAxisCount = 3; // columns stay fixed — rows grow
  static const int _startRows = 3; // 3x3 to start
  static const int _maxRows = 9; // caps out at 3x9 = 27 tiles
  static const int _tapsPerRow = 5; // a new row every N correct taps
  static const int _startLives = 3;
  static const int _startIntervalMs = 1400;
  static const int _minIntervalMs = 300;
  static const int _rampStepMs = 100; // cut per correct tap (was 60)

  final _rand = Random();
  Timer? _tileTimer;

  int _activeTile = -1;
  int _lives = _startLives;
  int _score = 0;
  int _intervalMs = _startIntervalMs;
  int _rows = _startRows;
  int _correctTaps = 0; // counts toward the next row, resets each round
  bool _running = false;
  bool _gameOver = false;
  DateTime? _startedAt;

  // Board grows one row (3 more tiles) at a time as the round goes on,
  // floored at _startRows and capped at _maxRows so it never outgrows a
  // phone screen. Existing tile indices stay valid when this grows since
  // new tiles are only ever appended at the end.
  int get _gridCount => _crossAxisCount * _rows;

  @override
  void dispose() {
    _tileTimer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _lives = _startLives;
      _score = 0;
      _intervalMs = _startIntervalMs;
      _rows = _startRows;
      _correctTaps = 0;
      _running = true;
      _gameOver = false;
      _activeTile = -1;
      _startedAt = DateTime.now();
    });
    _scheduleNextTile();
  }

  void _scheduleNextTile() {
    if (!mounted || !_running) return;
    // Small gap before the next tile lights up, so it doesn't feel instant.
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted || !_running) return;
      int next;
      do {
        next = _rand.nextInt(_gridCount);
      } while (next == _activeTile && _gridCount > 1);
      setState(() => _activeTile = next);

      _tileTimer?.cancel();
      _tileTimer = Timer(Duration(milliseconds: _intervalMs), _onTimeout);
    });
  }

  void _onTimeout() {
    if (!mounted || !_running) return;
    setState(() => _activeTile = -1);
    _loseLife();
  }

  void _loseLife() {
    if (!mounted) return;
    setState(() => _lives -= 1);
    if (_lives <= 0) {
      _endGame();
    } else {
      _scheduleNextTile();
    }
  }

  void _onTapTile(int index) {
    if (!_running) return;
    _tileTimer?.cancel();
    if (index == _activeTile) {
      setState(() {
        _score += 10 + ((_startIntervalMs - _intervalMs) ~/ 100);
        _activeTile = -1;
        // Ramp difficulty — faster tiles, floored at _minIntervalMs.
        _intervalMs = max(_minIntervalMs, _intervalMs - _rampStepMs);
        // ...and a bigger board — one more row every _tapsPerRow correct
        // taps, capped at _maxRows.
        _correctTaps += 1;
        if (_correctTaps % _tapsPerRow == 0 && _rows < _maxRows) {
          _rows += 1;
        }
      });
      _scheduleNextTile();
    } else {
      setState(() => _activeTile = -1);
      _loseLife();
    }
  }

  Future<void> _endGame() async {
    _tileTimer?.cancel();
    setState(() {
      _running = false;
      _gameOver = true;
    });
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore('reflex_tap', _score,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    if (!mounted) return;
    if (!allowed) {
      showPlayLimitDialog(context, color: widget.accentColor);
      return;
    }
    showGameResultDialog(
      context,
      icon: _score >= 150 ? Icons.bolt_rounded : Icons.adjust_rounded,
      title: 'Round Over!',
      message: 'You scored $_score points.',
      color: widget.accentColor,
      onPlayAgain: _start,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: gameAppBar(widget.title, color),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatPill(
                    icon: Icons.bolt_rounded, label: '$_score pts', color: color),
                Row(
                  children: List.generate(
                    _startLives,
                    (i) => Icon(
                      i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: i < _lives ? Colors.redAccent : Colors.grey.shade300,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!_running && !_gameOver)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 64, color: color),
                      const SizedBox(height: 12),
                      Text('Tap the lit tile before it fades!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.textMedium)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _start,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: const Text('Start',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                // A LayoutBuilder + computed childAspectRatio, not a fixed
                // square tile: the board can't scroll (that'd be unplayable
                // against a countdown timer), so as _rows grows, tiles must
                // shrink to keep every row on-screen and tappable instead of
                // clipping extra rows off the bottom.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 14.0;
                    final tileW = (constraints.maxWidth -
                            spacing * (_crossAxisCount - 1)) /
                        _crossAxisCount;
                    final tileH =
                        (constraints.maxHeight - spacing * (_rows - 1)) /
                            _rows;
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _crossAxisCount,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: tileW / tileH,
                      ),
                      itemCount: _gridCount,
                      itemBuilder: (context, i) {
                        final lit = i == _activeTile;
                        return GestureDetector(
                          onTap: () => _onTapTile(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              color: lit ? color : color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: lit
                                  ? [
                                      BoxShadow(
                                          color: color.withOpacity(0.5),
                                          blurRadius: 16,
                                          spreadRadius: 2),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
