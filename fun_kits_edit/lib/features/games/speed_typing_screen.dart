import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'game_common.dart';

const _phraseBank = [
  'Fun Kits makes every exhibition unforgettable',
  'Scan the booth QR to start playing',
  'Collect points and climb the leaderboard',
  'Great exhibitors bring great experiences',
  'Every booth has its own set of challenges',
  'Speed and accuracy both earn you points',
  'Innovation happens when people connect',
  'Explore every booth before the show ends',
  'Practice makes perfect at every challenge',
  'The fastest typist wins bragging rights',
];

/// SPEED TYPING — retype a displayed phrase as quickly and accurately as
/// possible within a time limit. Score blends words-per-minute with
/// accuracy so sloppy-but-fast and careful-but-slow both get rewarded
/// fairly.
class SpeedTypingScreen extends StatefulWidget {
  const SpeedTypingScreen({
    super.key,
    this.accentColor = AppColors.primary,
    this.exhibitorId,
    this.title = 'Speed Typing',
  });

  final Color accentColor;
  final String? exhibitorId;
  final String title;

  @override
  State<SpeedTypingScreen> createState() => _SpeedTypingScreenState();
}

class _SpeedTypingScreenState extends State<SpeedTypingScreen> {
  static const int _limitSeconds = 30;

  final _rand = Random();
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;

  String _phrase = '';
  int _secondsLeft = _limitSeconds;
  DateTime? _startedAt;
  bool _started = false;
  bool _gameOver = false;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phrase = _phraseBank[_rand.nextInt(_phraseBank.length)];
      _ctrl.clear();
      _secondsLeft = _limitSeconds;
      _startedAt = null;
      _started = true;
      _gameOver = false;
    });
    _focusNode.requestFocus();
  }

  void _onChanged(String value) {
    if (!_started) return;
    _startedAt ??= DateTime.now();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) _finish();
    });
    if (value.length >= _phrase.length) _finish();
  }

  int _correctChars(String typed) {
    var correct = 0;
    for (var i = 0; i < typed.length && i < _phrase.length; i++) {
      if (typed[i] == _phrase[i]) correct++;
    }
    return correct;
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final typed = _ctrl.text;
    final correct = _correctChars(typed);
    final accuracy = _phrase.isEmpty ? 0.0 : correct / _phrase.length;
    final elapsedSeconds = _startedAt == null
        ? _limitSeconds
        : max(1, DateTime.now().difference(_startedAt!).inSeconds);
    final words = correct / 5;
    final minutes = elapsedSeconds / 60;
    final wpm = minutes > 0 ? words / minutes : 0.0;
    final score = (wpm * 0.6 + accuracy * 100 * 0.4).round().clamp(0, 300).toInt();

    setState(() {
      _started = false;
      _gameOver = true;
    });
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore('speed_typing', score,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    if (!mounted) return;
    if (!allowed) {
      showPlayLimitDialog(context, color: widget.accentColor);
      return;
    }
    showGameResultDialog(
      context,
      emoji: accuracy >= 0.95 ? '⌨️' : '📝',
      title: 'Time!',
      message: '${wpm.round()} WPM · ${(accuracy * 100).round()}% accurate '
          '— $score points.',
      color: widget.accentColor,
      onPlayAgain: _start,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final typed = _ctrl.text;

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
                    const Text('⌨️', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    const Text('Retype the phrase as fast and accurately as you can.',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _secondsLeft <= 8
                            ? AppColors.danger.withOpacity(0.15)
                            : color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('⏱ ${_secondsLeft}s',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _secondsLeft <= 8 ? AppColors.danger : color)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
                        children: List.generate(_phrase.length, (i) {
                          Color c = AppColors.textMedium;
                          if (i < typed.length) {
                            c = typed[i] == _phrase[i]
                                ? AppColors.success
                                : AppColors.danger;
                          }
                          return TextSpan(
                            text: _phrase[i],
                            style: TextStyle(color: c),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    autofocus: true,
                    maxLines: 2,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      hintText: 'Start typing...',
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _finish,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: const Text('Submit',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
