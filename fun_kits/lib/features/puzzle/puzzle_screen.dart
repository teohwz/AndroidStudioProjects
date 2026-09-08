import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/fun_button.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  final _fs = FirestoreService();
  static const int _gridSize = 3;
  static const int _totalTiles = _gridSize * _gridSize;

  late List<int> _tiles;
  bool _solved = false;
  int _moves = 0;
  bool _submitted = false;
  int _attempts = 3;
  bool _loadingAttempts = true;
  bool _outOfAttempts = false;

  @override
  void initState() {
    super.initState();
    _tiles = List.generate(_totalTiles, (i) => i);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingAttempts = false);
      return;
    }

    // Load attempts
    final a = await _fs.getPuzzleAttempts(uid);

    // Load saved progress
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString('puzzle_state_$uid');

    if (mounted) {
      setState(() {
        _attempts = a;
        _loadingAttempts = false;
        _outOfAttempts = a <= 0;

        if (savedState != null && !_outOfAttempts) {
          // Resume saved progress
          final state = jsonDecode(savedState) as Map<String, dynamic>;
          _tiles = List<int>.from(state['tiles']);
          _moves = state['moves'];
          _solved = state['solved'] ?? false;
        } else if (!_outOfAttempts) {
          _initPuzzle();
        }
      });
    }
  }

  Future<void> _saveProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'puzzle_state_$uid',
        jsonEncode({
          'tiles': _tiles,
          'moves': _moves,
          'solved': _solved,
        }));
  }

  Future<void> _clearProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('puzzle_state_$uid');
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
    if (_solved || _outOfAttempts) return;
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

  // New scoring: start at 100, deduct 5 per move, min 5
  int get _currentPoints {
    final points = 100 - (_moves * 5);
    return points.clamp(5, 100);
  }

  Future<void> _onSolved() async {
    if (_submitted) return;
    _submitted = true;
    final points = _currentPoints;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _fs.addPoints(user.uid, user.displayName ?? 'Player', points,
          gameType: 'puzzle');
    }
    await _clearProgress();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🎉 Puzzle Solved!',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text('Solved in $_moves moves!\n+$points points earned!'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _initPuzzle());
              },
              child: const Text('New Puzzle'),
            ),
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
  }

  Future<void> _closeAttempt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close This Attempt?'),
        content: const Text(
            'Your progress will be lost and 1 attempt will be used. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, close')),
        ],
      ),
    );
    if (confirm != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final newAttempts = _attempts - 1;
    await _fs.setPuzzleAttempts(uid, newAttempts);
    await _clearProgress();
    if (mounted) {
      setState(() {
        _attempts = newAttempts;
        _outOfAttempts = newAttempts <= 0;
        if (!_outOfAttempts) _initPuzzle();
      });
    }
  }

  Future<void> _pauseAndReturn() async {
    await _saveProgress();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAttempts) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Slide Puzzle 🧩',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.puzzleColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _pauseAndReturn,
        ),
        actions: [
          if (!_outOfAttempts)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'close') _closeAttempt();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'close', child: Text('Close Attempt')),
              ],
            ),
        ],
      ),
      body: _outOfAttempts ? _buildNoAttempts() : _buildPuzzle(),
    );
  }

  Widget _buildNoAttempts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😔', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Out of Attempts',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Earn more attempts by checking in at exhibitor booths!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium),
            ),
            const SizedBox(height: 24),
            _EarnAttemptsInfo(),
            const SizedBox(height: 24),
            FunButton(
              label: 'Visit Exhibitors →',
              onPressed: () => Navigator.pop(context),
              gradient: const LinearGradient(
                  colors: [AppColors.exhibitorColor, Color(0xFF00BFA5)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridSize = (screenWidth - 64).clamp(0.0, 280.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(label: 'Moves', value: '$_moves'),
              _Stat(
                label: 'Points',
                value: '$_currentPoints',
                color: _currentPoints <= 10
                    ? AppColors.danger
                    : AppColors.success,
              ),
              _Stat(
                label: 'Attempts',
                value: '$_attempts',
                color: _attempts <= 1 ? AppColors.danger : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Arrange numbers 1–8 in order.\nEach move deducts 5 points (min 5).',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMedium, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Puzzle grid
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
                          ? Colors.grey.shade200
                          : AppColors.puzzleColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isEmpty
                          ? []
                          : [
                              BoxShadow(
                                  color: AppColors.puzzleColor.withOpacity(0.3),
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

          // Earn attempts card
          _EarnAttemptsCard(
            uid: FirebaseAuth.instance.currentUser?.uid ?? '',
            fs: _fs,
            onEarned: () async {
              final a = await _fs.getPuzzleAttempts(
                  FirebaseAuth.instance.currentUser!.uid);
              if (mounted) setState(() => _attempts = a);
            },
          ),
          const SizedBox(height: 16),
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
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color ?? AppColors.textDark)),
        Text(label,
            style: const TextStyle(color: AppColors.textMedium, fontSize: 11)),
      ],
    );
  }
}

class _EarnAttemptsInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.puzzleColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.puzzleColor.withOpacity(0.3)),
      ),
      child: const Column(
        children: [
          Text('How to earn more attempts:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          SizedBox(height: 8),
          _EarnRow('🏢', 'Check in at any exhibitor booth', '+1 attempt'),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow(this.emoji, this.text, this.reward);
  final String emoji, text, reward;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(reward,
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ],
      );
}

class _EarnAttemptsCard extends StatefulWidget {
  const _EarnAttemptsCard(
      {required this.uid, required this.fs, required this.onEarned});
  final String uid;
  final FirestoreService fs;
  final VoidCallback onEarned;

  @override
  State<_EarnAttemptsCard> createState() => _EarnAttemptsCardState();
}

class _EarnAttemptsCardState extends State<_EarnAttemptsCard> {
  List<String> _checkedIn = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final ids = await widget.fs.getCheckedInBooths(widget.uid);
    if (mounted) setState(() {
      _checkedIn = ids;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.exhibitorColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.exhibitorColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.store_rounded,
                  color: AppColors.exhibitorColor, size: 18),
              SizedBox(width: 6),
              Text('Earn Extra Attempts',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.exhibitorColor,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Check in at booths to earn +1 attempt each (first visit only)',
            style: TextStyle(color: AppColors.textMedium, fontSize: 12),
          ),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${_checkedIn.length} booth(s) checked in',
                  style: const TextStyle(
                      color: AppColors.textMedium, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
