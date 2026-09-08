import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'game_common.dart';

/// RGB MASTER — match a target color by dragging R/G/B sliders. 3 rounds;
/// each round's score is based on how close the match is (and a small speed
/// bonus). A visual, low-pressure game that's easy to pick up at a busy
/// booth.
class RgbMasterScreen extends StatefulWidget {
  const RgbMasterScreen({
    super.key,
    this.accentColor = AppColors.primary,
    this.exhibitorId,
    this.title = 'RGB Master',
  });

  final Color accentColor;
  final String? exhibitorId;
  final String title;

  @override
  State<RgbMasterScreen> createState() => _RgbMasterScreenState();
}

class _RgbMasterScreenState extends State<RgbMasterScreen> {
  static const int _totalRounds = 3;
  static const int _roundSeconds = 20;

  final _rand = Random();
  Color _target = Colors.blue;
  double _r = 128, _g = 128, _b = 128;
  int _round = 0;
  int _totalScore = 0;
  int _secondsLeft = _roundSeconds;
  Timer? _timer;
  bool _started = false;
  bool _gameOver = false;
  bool _roundLocked = false;
  DateTime? _startedAt;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _round = 0;
      _totalScore = 0;
      _started = true;
      _gameOver = false;
      _startedAt = DateTime.now();
    });
    _nextRound();
  }

  void _nextRound() {
    if (_round >= _totalRounds) {
      _endGame();
      return;
    }
    setState(() {
      _round += 1;
      _target = Color.fromARGB(
          255, _rand.nextInt(256), _rand.nextInt(256), _rand.nextInt(256));
      _r = 128;
      _g = 128;
      _b = 128;
      _secondsLeft = _roundSeconds;
      _roundLocked = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) _submitRound(auto: true);
    });
  }

  double get _matchPercent {
    final dr = _r - _target.red;
    final dg = _g - _target.green;
    final db = _b - _target.blue;
    final dist = sqrt(dr * dr + dg * dg + db * db);
    const maxDist = 441.67; // sqrt(255^2 * 3)
    return (100 - (dist / maxDist * 100)).clamp(0, 100).toDouble();
  }

  void _submitRound({bool auto = false}) {
    if (_roundLocked) return;
    _timer?.cancel();
    final match = _matchPercent;
    final speedBonus = auto ? 0 : (_secondsLeft * 0.5).round();
    final roundScore = match.round() + speedBonus;
    setState(() {
      _roundLocked = true;
      _totalScore += roundScore;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _started) _nextRound();
    });
  }

  Future<void> _endGame() async {
    _timer?.cancel();
    setState(() {
      _started = false;
      _gameOver = true;
    });
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore('rgb_master', _totalScore,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    if (!mounted) return;
    if (!allowed) {
      showPlayLimitDialog(context, color: widget.accentColor);
      return;
    }
    showGameResultDialog(
      context,
      emoji: _totalScore >= 250 ? '🎨' : '🖌️',
      title: 'Palette Complete!',
      message: 'Total score across $_totalRounds rounds: $_totalScore points.',
      color: widget.accentColor,
      onPlayAgain: _start,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final current = Color.fromARGB(255, _r.round(), _g.round(), _b.round());

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: gameAppBar(widget.title, color),
      body: !_started && !_gameOver
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎨', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    const Text('Match the target color using the sliders.',
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
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Round $_round / $_totalRounds',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: color)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _secondsLeft <= 5
                              ? AppColors.danger.withOpacity(0.15)
                              : AppColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('⏱ ${_secondsLeft}s',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _secondsLeft <= 5
                                    ? AppColors.danger
                                    : AppColors.textMedium)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Target',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMedium)),
                            const SizedBox(height: 8),
                            Container(
                              height: 90,
                              decoration: BoxDecoration(
                                color: _target,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Your Mix',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMedium)),
                            const SizedBox(height: 8),
                            Container(
                              height: 90,
                              decoration: BoxDecoration(
                                color: current,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${_matchPercent.round()}% match',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: color)),
                  const SizedBox(height: 12),
                  _ColorSlider(
                      label: 'R',
                      value: _r,
                      trackColor: Colors.red,
                      onChanged: _roundLocked
                          ? null
                          : (v) => setState(() => _r = v)),
                  _ColorSlider(
                      label: 'G',
                      value: _g,
                      trackColor: Colors.green,
                      onChanged: _roundLocked
                          ? null
                          : (v) => setState(() => _g = v)),
                  _ColorSlider(
                      label: 'B',
                      value: _b,
                      trackColor: Colors.blue,
                      onChanged: _roundLocked
                          ? null
                          : (v) => setState(() => _b = v)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _roundLocked ? null : () => _submitRound(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: Text(_roundLocked ? 'Locked in!' : 'Lock In Match',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.trackColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color trackColor;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 20,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w800, color: trackColor))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: trackColor,
              thumbColor: trackColor,
              inactiveTrackColor: trackColor.withOpacity(0.15),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
            width: 34,
            child: Text('${value.round()}',
                textAlign: TextAlign.end,
                style: const TextStyle(color: AppColors.textMedium))),
      ],
    );
  }
}
