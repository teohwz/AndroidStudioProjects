import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import 'game_common.dart';

/// GUESS THE NUMBER — exhibitor sets a min–max range and reward points;
/// the visitor gets up to [GuessNumberConfig.maxAttempts] guesses with
/// automatic Higher/Lower feedback after each one, plus the exhibitor's
/// optional hint, revealable any time.
class GuessNumberScreen extends StatefulWidget {
  const GuessNumberScreen({
    super.key,
    this.accentColor = AppColors.primary,
    required this.exhibitorId,
    this.title = 'Guess the Number',
  });

  final Color accentColor;
  final String exhibitorId;
  final String title;

  @override
  State<GuessNumberScreen> createState() => _GuessNumberScreenState();
}

class _GuessNumberScreenState extends State<GuessNumberScreen> {
  final _fs = FirestoreService();
  final _rand = Random();
  final _guessCtrl = TextEditingController();

  GuessNumberConfig? _config;
  bool _loading = true;

  int _secret = 0;
  bool _started = false;
  bool _gameOver = false;
  bool _hintRevealed = false;
  DateTime? _startedAt;
  final List<_GuessEntry> _guesses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _guessCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _fs.getGuessNumberConfig(widget.exhibitorId);
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  void _start() {
    final config = _config!;
    setState(() {
      _secret = config.minValue + _rand.nextInt(config.maxValue - config.minValue + 1);
      _started = true;
      _gameOver = false;
      _hintRevealed = false;
      _guesses.clear();
      _guessCtrl.clear();
      _startedAt = DateTime.now();
    });
  }

  Future<void> _submitGuess() async {
    if (_gameOver) return;
    final config = _config!;
    final guess = int.tryParse(_guessCtrl.text.trim());
    if (guess == null || guess < config.minValue || guess > config.maxValue) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Enter a number between ${config.minValue} and ${config.maxValue}.')));
      return;
    }
    _guessCtrl.clear();

    if (guess == _secret) {
      setState(() {
        _guesses.insert(0, _GuessEntry(guess, 'correct'));
        _gameOver = true;
      });
      await _finish(won: true, config: config);
      return;
    }

    setState(() {
      _guesses.insert(0, _GuessEntry(guess, guess < _secret ? 'higher' : 'lower'));
    });

    if (_guesses.length >= GuessNumberConfig.maxAttempts) {
      setState(() => _gameOver = true);
      await _finish(won: false, config: config);
    }
  }

  Future<void> _finish({required bool won, required GuessNumberConfig config}) async {
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore(
        'guess_number', won ? config.rewardPoints : 0,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    if (!mounted) return;
    if (!allowed) {
      showPlayLimitDialog(context, color: widget.accentColor);
      return;
    }
    showGameResultDialog(
      context,
      emoji: won ? '🎯' : '😅',
      title: won ? 'You Got It!' : 'Out of Guesses!',
      message: won
          ? 'You guessed it in ${_guesses.length} ${_guesses.length == 1 ? "try" : "tries"} '
              '— +${config.rewardPoints} points!'
          : 'The number was $_secret. Better luck next time!',
      color: widget.accentColor,
      onPlayAgain: _start,
    );
  }

  void _showHint() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💡', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(_config!.hint, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
    setState(() => _hintRevealed = true);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final config = _config;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: gameAppBar(widget.title, color,
          actions: [
            if (!_loading && config != null && config.hasHint)
              IconButton(
                icon: Icon(_hintRevealed
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded),
                tooltip: 'Hint',
                onPressed: _showHint,
              ),
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : config == null || !config.hasContent
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔢', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      const Text('This booth hasn\'t set this game up yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMedium)),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: !_started
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔢', style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 12),
                              Text(
                                  'Guess a number between ${config.minValue} and '
                                  '${config.maxValue}!\nYou get ${GuessNumberConfig.maxAttempts} tries.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
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
                        )
                      : Column(
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
                                  child: Text(
                                      'Attempt ${_guesses.length}/${GuessNumberConfig.maxAttempts}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800, color: color)),
                                ),
                                Text('Range: ${config.minValue}–${config.maxValue}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMedium)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (!_gameOver)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _guessCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.w800),
                                      decoration: const InputDecoration(
                                          hintText: 'Your guess',
                                          border: OutlineInputBorder()),
                                      onSubmitted: (_) => _submitGuess(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: _submitGuess,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 16)),
                                    child: const Text('Guess',
                                        style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _guesses.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final g = _guesses[i];
                                  final isCorrect = g.result == 'correct';
                                  final label = isCorrect
                                      ? 'Correct! 🎯'
                                      : g.result == 'higher'
                                          ? 'Go Higher ⬆️'
                                          : 'Go Lower ⬇️';
                                  final tileColor = isCorrect
                                      ? AppColors.success
                                      : color;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: tileColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: tileColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${g.value}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16)),
                                        Text(label,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: tileColor)),
                                      ],
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

class _GuessEntry {
  const _GuessEntry(this.value, this.result); // result: 'higher' | 'lower' | 'correct'
  final int value;
  final String result;
}
