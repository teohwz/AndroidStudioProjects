import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_palette.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/fun_button.dart';
import '../games/game_common.dart';

/// Puzzle now plays by the same per-booth rules as the other games (see
/// kGenericBoothGames/kPrizeBoothGames): every visitor shares ONE attempt
/// pool per booth (see BoothAttemptPool), spendable on any of that booth's
/// games — enforced by FirestoreService.recordGamePlay via submitGameScore,
/// not by a global SharedPreferences-tracked attempts pool like this screen
/// used to have.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, this.exhibitorId});

  /// The booth this puzzle is played at. Null only for the legacy
  /// standalone `/puzzle` route (no booth context) — in that case the
  /// per-booth limiter is skipped entirely, same as submitGameScore does
  /// for every other game.
  final String? exhibitorId;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  static const int _gridSize = 3;
  static const int _totalTiles = _gridSize * _gridSize;
  final _fs = FirestoreService();

  late List<int> _tiles;
  bool _solved = false;
  int _moves = 0;
  bool _submitted = false;
  bool _loading = true;
  bool _locked = false; // already used this booth's free play + any bonus
  // Set once the puzzle becomes playable (fresh or resumed) — used to
  // compute this play's engagement duration. Resuming a saved-in-progress
  // puzzle intentionally restarts the clock from the resume point rather
  // than the original start (that timestamp isn't persisted), so this is
  // "time actively spent solving," not wall-clock since first opened.
  DateTime? _startedAt;

  String get _progressKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_';
    final booth = widget.exhibitorId ?? '_';
    return 'puzzle_state_${uid}_$booth';
  }

  @override
  void initState() {
    super.initState();
    _tiles = List.generate(_totalTiles, (i) => i);
    _init();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    var locked = false;
    if (uid != null &&
        widget.exhibitorId != null &&
        widget.exhibitorId!.isNotEmpty) {
      final remaining = await _fs.remainingAttempts(uid, widget.exhibitorId!);
      locked = remaining <= 0;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_progressKey);

    if (!mounted) return;
    setState(() {
      _locked = locked;
      _loading = false;
      if (!locked) {
        if (savedState != null) {
          final state = jsonDecode(savedState) as Map<String, dynamic>;
          _tiles = List<int>.from(state['tiles']);
          _moves = state['moves'];
          _solved = state['solved'] ?? false;
        } else {
          _initPuzzle();
        }
        _startedAt = DateTime.now();
      }
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _progressKey,
        jsonEncode({
          'tiles': _tiles,
          'moves': _moves,
          'solved': _solved,
        }));
  }

  Future<void> _clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  void _initPuzzle() {
    _tiles = List.generate(_totalTiles, (i) => i);
    _shuffle();
    _solved = false;
    _moves = 0;
    _submitted = false;
    _clearProgress();
  }

  void _shuffle() {
    final rand = Random();
    do {
      _tiles.shuffle(rand);
    } while (!_isSolvable(_tiles) || _isGoalState(_tiles));
  }

  bool _isSolvable(List<int> tiles) {
    int inversions = 0;
    final flat = tiles.where((t) => t != 0).toList();
    for (int i = 0; i < flat.length; i++) {
      for (int j = i + 1; j < flat.length; j++) {
        if (flat[i] > flat[j]) inversions++;
      }
    }
    if (_gridSize.isOdd) return inversions.isEven;
    final emptyRow = tiles.indexOf(0) ~/ _gridSize;
    final emptyFromBottom = _gridSize - emptyRow;
    return emptyFromBottom.isOdd ? inversions.isEven : inversions.isOdd;
  }

  bool _isGoalState(List<int> tiles) {
    for (int i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.last == 0;
  }

  void _onTileTap(int index) {
    if (_solved || _locked) return;
    final emptyIndex = _tiles.indexOf(0);
    final emptyRow = emptyIndex ~/ _gridSize;
    final emptyCol = emptyIndex % _gridSize;
    final tapRow = index ~/ _gridSize;
    final tapCol = index % _gridSize;
    final isAdjacent = (emptyRow == tapRow && (emptyCol - tapCol).abs() == 1) ||
        (emptyCol == tapCol && (emptyRow - tapRow).abs() == 1);
    if (!isAdjacent) return;
    setState(() {
      _tiles[emptyIndex] = _tiles[index];
      _tiles[index] = 0;
      _moves++;
      _saveProgress();
      if (_isGoalState(_tiles)) {
        _solved = true;
        _onSolved();
      }
    });
  }

  // Scoring: start at 100, deduct 5 per move, min 5.
  int get _currentPoints {
    final points = 100 - (_moves * 5);
    return points.clamp(5, 100);
  }

  Future<void> _onSolved() async {
    if (_submitted) return;
    _submitted = true;
    final points = _currentPoints;
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore('puzzle', points,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    await _clearProgress();
    if (!mounted) return;
    final palette = Theme.of(context).extension<AppPalette>()!;
    if (!allowed) {
      setState(() => _locked = true);
      showPlayLimitDialog(context, color: palette.puzzleColor);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, color: palette.puzzleColor),
            const SizedBox(width: 8),
            const Text('Puzzle Solved!'),
          ],
        ),
        content: Text('Solved in $_moves moves!\n+$points points earned!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _pauseAndReturn() async {
    if (!_solved && !_locked) await _saveProgress();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final palette = Theme.of(context).extension<AppPalette>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Slide Puzzle'),
        backgroundColor: palette.puzzleColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _pauseAndReturn,
        ),
      ),
      body: _locked ? _buildLocked() : _buildPuzzle(),
    );
  }

  Widget _buildLocked() {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.exhibitorColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded,
                  size: 36, color: palette.exhibitorColor),
            ),
            const SizedBox(height: 16),
            Text('No Attempts Left', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              "You've used up this booth's shared attempts. Complete a "
              'booth task (follow the exhibitor, play a featured mini-game) '
              'to earn more, or try another booth!',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMedium),
            ),
            const SizedBox(height: 24),
            FunButton(
              label: 'Back to Booth',
              onPressed: () => Navigator.pop(context),
              gradient: LinearGradient(
                  colors: [palette.exhibitorColor, palette.quizColor]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzle() {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final screenWidth = MediaQuery.of(context).size.width;
    final gridSize = (screenWidth - 64).clamp(0.0, 280.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(label: 'Moves', value: '$_moves'),
              _Stat(
                label: 'Points',
                value: '$_currentPoints',
                color: _currentPoints <= 10 ? palette.danger : palette.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Arrange numbers 1–8 in order.\nEach move deducts 5 points (min 5).',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMedium, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: gridSize,
            height: gridSize,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridSize,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: _totalTiles,
              itemBuilder: (_, i) {
                final value = _tiles[i];
                final isEmpty = value == 0;
                return GestureDetector(
                  onTap: () => _onTileTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: isEmpty
                          ? theme.colorScheme.outlineVariant.withOpacity(0.3)
                          : palette.puzzleColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isEmpty
                          ? []
                          : [
                              BoxShadow(
                                  color: palette.puzzleColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2)),
                            ],
                    ),
                    child: isEmpty
                        ? null
                        : Center(
                            child: Text(
                              '$value',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color ?? palette.textDark)),
        Text(label, style: TextStyle(color: palette.textMedium, fontSize: 11)),
      ],
    );
  }
}
