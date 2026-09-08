import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'game_common.dart';

/// MEMORY MATRIX — a Simon-says pattern game. The grid flashes a growing
/// sequence of tiles; the player repeats it from memory. Get one wrong and
/// the round ends. Score = rounds survived.
class MemoryMatrixScreen extends StatefulWidget {
  const MemoryMatrixScreen({
    super.key,
    this.accentColor = AppColors.primary,
    this.exhibitorId,
    this.title = 'Memory Matrix',
  });

  final Color accentColor;
  final String? exhibitorId;
  final String title;

  @override
  State<MemoryMatrixScreen> createState() => _MemoryMatrixScreenState();
}

class _MemoryMatrixScreenState extends State<MemoryMatrixScreen> {
  static const int _gridCount = 9; // 3x3

  final _rand = Random();
  final List<int> _sequence = [];

  int _playerStep = 0;
  int _flashTile = -1;
  bool _showingSequence = false;
  bool _accepting = false;
  bool _started = false;
  bool _gameOver = false;
  int _round = 0;
  DateTime? _startedAt;

  void _start() {
    setState(() {
      _sequence.clear();
      _round = 0;
      _started = true;
      _gameOver = false;
      _startedAt = DateTime.now();
    });
    _nextRound();
  }

  Future<void> _nextRound() async {
    setState(() {
      _round += 1;
      _sequence.add(_rand.nextInt(_gridCount));
      _playerStep = 0;
      _accepting = false;
      _showingSequence = true;
    });
    await _playSequence();
    if (!mounted) return;
    setState(() => _accepting = true);
  }

  Future<void> _playSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    for (final tile in _sequence) {
      if (!mounted) return;
      setState(() => _flashTile = tile);
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() => _flashTile = -1);
      await Future.delayed(const Duration(milliseconds: 180));
    }
    if (mounted) setState(() => _showingSequence = false);
  }

  void _onTapTile(int index) {
    if (!_accepting || _showingSequence) return;
    if (index == _sequence[_playerStep]) {
      setState(() {
        _flashTile = index;
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _flashTile = -1);
      });
      _playerStep += 1;
      if (_playerStep == _sequence.length) {
        _accepting = false;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _started && !_gameOver) _nextRound();
        });
      }
    } else {
      _endGame();
    }
  }

  Future<void> _endGame() async {
    setState(() {
      _started = false;
      _gameOver = true;
      _accepting = false;
    });
    final roundsSurvived = _round - 1;
    final score = roundsSurvived * 15;
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore('memory_matrix', score,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    if (!mounted) return;
    if (!allowed) {
      showPlayLimitDialog(context, color: widget.accentColor);
      return;
    }
    showGameResultDialog(
      context,
      emoji: roundsSurvived >= 6 ? '🧠' : '🔁',
      title: 'Pattern Broken!',
      message: 'You remembered $roundsSurvived round${roundsSurvived == 1 ? '' : 's'} '
          '— $score points.',
      color: widget.accentColor,
      onPlayAgain: _start,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: gameAppBar(widget.title, color),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _StatusRow(
              round: _round,
              status: !_started && !_gameOver
                  ? 'Ready?'
                  : _showingSequence
                      ? 'Watch closely...'
                      : 'Your turn!',
              color: color,
            ),
            const SizedBox(height: 24),
            if (!_started && !_gameOver)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧠', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      const Text('Watch the pattern, then repeat it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMedium)),
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
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                  ),
                  itemCount: _gridCount,
                  itemBuilder: (context, i) {
                    final lit = i == _flashTile;
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.round, required this.status, required this.color});
  final int round;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Round $round',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ),
        Text(status,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textMedium)),
      ],
    );
  }
}
