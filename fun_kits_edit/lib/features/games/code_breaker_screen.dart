import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_palette.dart';
import 'game_common.dart';

class _Guess {
  final List<int> digits;
  final int bulls; // right digit, right position
  final int cows; // right digit, wrong position
  const _Guess(this.digits, this.bulls, this.cows);
}

/// CODE BREAKER — a 4-digit "Bulls & Cows" style combination-lock puzzle.
/// Crack the secret (4 unique digits) before the timer runs out; fewer
/// guesses and less time used both mean more points.
class CodeBreakerScreen extends StatefulWidget {
  const CodeBreakerScreen({
    super.key,
    this.accentColor = AppColors.primary,
    this.exhibitorId,
    this.title = 'Code Breaker',
  });

  final Color accentColor;
  final String? exhibitorId;
  final String title;

  @override
  State<CodeBreakerScreen> createState() => _CodeBreakerScreenState();
}

class _CodeBreakerScreenState extends State<CodeBreakerScreen> {
  static const int _totalSeconds = 90;

  final _rand = Random();
  List<int> _secret = [];
  List<int> _current = [];
  final List<_Guess> _guesses = [];
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  bool _started = false;
  bool _gameOver = false;
  DateTime? _startedAt;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final digits = List.generate(10, (i) => i)..shuffle(_rand);
    setState(() {
      _secret = digits.take(4).toList();
      _current = [];
      _guesses.clear();
      _secondsLeft = _totalSeconds;
      _started = true;
      _gameOver = false;
      _startedAt = DateTime.now();
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) _endGame(solved: false);
    });
  }

  void _tapDigit(int d) {
    if (!_started || _current.length >= 4 || _current.contains(d)) return;
    setState(() => _current.add(d));
    if (_current.length == 4) _submitGuess();
  }

  void _backspace() {
    if (_current.isEmpty) return;
    setState(() => _current.removeLast());
  }

  void _submitGuess() {
    int bulls = 0, cows = 0;
    for (var i = 0; i < 4; i++) {
      if (_current[i] == _secret[i]) {
        bulls++;
      } else if (_secret.contains(_current[i])) {
        cows++;
      }
    }
    final guess = _Guess(List.from(_current), bulls, cows);
    setState(() {
      _guesses.insert(0, guess);
      _current = [];
    });
    if (bulls == 4) _endGame(solved: true);
  }

  Future<void> _endGame({required bool solved}) async {
    _timer?.cancel();
    final elapsed = _totalSeconds - _secondsLeft;
    int score;
    if (solved) {
      score = max(50, 500 - (_guesses.length - 1) * 40 - elapsed * 3);
    } else {
      final bestBulls =
          _guesses.isEmpty ? 0 : _guesses.map((g) => g.bulls).reduce(max);
      score = bestBulls * 15;
    }
    setState(() {
      _started = false;
      _gameOver = true;
    });
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore('code_breaker', score,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    if (!mounted) return;
    if (!allowed) {
      showPlayLimitDialog(context, color: widget.accentColor);
      return;
    }
    showGameResultDialog(
      context,
      icon: solved ? Icons.lock_open_rounded : Icons.timer_off_rounded,
      title: solved ? 'Code Cracked!' : "Time's Up!",
      message: solved
          ? 'Solved in ${_guesses.length} guess${_guesses.length == 1 ? '' : 'es'} — $score points.'
          : 'The code was ${_secret.join()}. You still earned $score points.',
      color: widget.accentColor,
      onPlayAgain: _start,
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
      body: !_started && !_gameOver
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 64, color: color),
                    const SizedBox(height: 12),
                    Text(
                        'Crack the 4-digit code. Green = right digit & spot, '
                        'yellow = right digit, wrong spot.',
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _secondsLeft <= 15
                              ? palette.danger.withOpacity(0.15)
                              : color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 15,
                                color: _secondsLeft <= 15
                                    ? palette.danger
                                    : color),
                            const SizedBox(width: 4),
                            Text('${_secondsLeft}s',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _secondsLeft <= 15
                                        ? palette.danger
                                        : color)),
                          ],
                        ),
                      ),
                      Text('${_guesses.length} guess${_guesses.length == 1 ? '' : 'es'}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.textMedium)),
                    ],
                  ),
                ),
                // Current guess boxes
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _current.length;
                      return Container(
                        width: 52,
                        height: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: filled ? color.withOpacity(0.15) : palette.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: filled ? color : Colors.grey.shade300, width: 2),
                        ),
                        child: Text(filled ? '${_current[i]}' : '',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800, color: color)),
                      );
                    }),
                  ),
                ),
                // Past guesses
                Expanded(
                  child: _guesses.isEmpty
                      ? Center(
                          child: Text('Your guesses will appear here',
                              style: TextStyle(color: palette.textMedium)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _guesses.length,
                          itemBuilder: (context, i) {
                            final g = _guesses[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: theme.colorScheme.outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  Text(g.digits.join('  '),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 16)),
                                  const Spacer(),
                                  ...List.generate(
                                      g.bulls,
                                      (_) => Padding(
                                            padding: const EdgeInsets.only(left: 2),
                                            child: Icon(Icons.circle,
                                                size: 12, color: palette.success),
                                          )),
                                  ...List.generate(
                                      g.cows,
                                      (_) => Padding(
                                            padding: const EdgeInsets.only(left: 2),
                                            child: Icon(Icons.circle,
                                                size: 12, color: palette.warning),
                                          )),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                // Keypad
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var d = 0; d < 10; d++)
                        _DigitKey(
                          digit: d,
                          disabled: _current.contains(d) || _current.length >= 4,
                          color: color,
                          onTap: () => _tapDigit(d),
                        ),
                      _KeyButton(
                        icon: Icons.backspace_rounded,
                        color: color,
                        onTap: _backspace,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey(
      {required this.digit, required this.disabled, required this.color, required this.onTap});
  final int digit;
  final bool disabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 56,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? theme.colorScheme.outlineVariant.withOpacity(0.3)
              : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$digit',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: disabled
                    ? theme.colorScheme.onSurfaceVariant
                    : color)),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
