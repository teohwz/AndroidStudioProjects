import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/puzzle_model.dart';
import '../../core/services/firestore_service.dart';

enum PuzzleState { idle, playing, solved, submitting, submitted }

class PuzzleController extends ChangeNotifier {
  final FirestoreService _fs;
  final FirebaseAuth _auth;

  PuzzleController({
    FirestoreService? firestoreService,
    FirebaseAuth? auth,
  })  : _fs = firestoreService ?? FirestoreService(),
        _auth = auth ?? FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────────────────────────
  PuzzleState _state = PuzzleState.idle;
  PuzzleModel? _currentPuzzle;
  List<int> _tiles = [];
  int _moves = 0;
  int _pointsEarned = 0;
  String? _errorMessage;

  // ── Getters ────────────────────────────────────────────────────────────────
  PuzzleState get state => _state;
  PuzzleModel? get currentPuzzle => _currentPuzzle;
  List<int> get tiles => List.unmodifiable(_tiles);
  int get moves => _moves;
  int get pointsEarned => _pointsEarned;
  String? get errorMessage => _errorMessage;

  bool get isSolved => _state == PuzzleState.solved;
  bool get isPlaying => _state == PuzzleState.playing;
  bool get isSubmitting => _state == PuzzleState.submitting;

  int get gridSize => _currentPuzzle?.gridSize ?? 3;

  /// Live preview of how many points the current move count would earn
  int get currentPointsPreview =>
      _currentPuzzle?.calculatePoints(_moves) ?? 0;

  // ── Load & shuffle a puzzle ────────────────────────────────────────────────
  void loadPuzzle(PuzzleModel puzzle) {
    _currentPuzzle = puzzle;
    _moves = 0;
    _pointsEarned = 0;
    _errorMessage = null;
    _shuffleTiles(puzzle.gridSize);
    _setState(PuzzleState.playing);
  }

  // ── Restart current puzzle ─────────────────────────────────────────────────
  void restart() {
    if (_currentPuzzle == null) return;
    _moves = 0;
    _pointsEarned = 0;
    _errorMessage = null;
    _shuffleTiles(_currentPuzzle!.gridSize);
    _setState(PuzzleState.playing);
  }

  // ── Tap a tile ─────────────────────────────────────────────────────────────
  void tapTile(int tileIndex) {
    if (_state != PuzzleState.playing) return;

    final emptyIndex = _tiles.indexOf(0);
    if (!_isAdjacent(tileIndex, emptyIndex, gridSize)) return;

    // Swap tile with empty slot
    final tmp = _tiles[tileIndex];
    _tiles[tileIndex] = 0;
    _tiles[emptyIndex] = tmp;
    _moves++;

    if (_isGoalState()) {
      _handleSolved();
    } else {
      notifyListeners();
    }
  }

  // ── Submit score to Firebase ───────────────────────────────────────────────
  Future<void> submitScore() async {
    if (_state != PuzzleState.solved ||
        _currentPuzzle == null) return;

    _setState(PuzzleState.submitting);
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = 'Must be logged in to submit score.';
      _setState(PuzzleState.solved);
      return;
    }

    try {
      _pointsEarned = _currentPuzzle!.calculatePoints(_moves);
      await _fs.addPoints(
          user.uid, user.displayName ?? 'Player', _pointsEarned);
      _setState(PuzzleState.submitted);
    } catch (e) {
      _errorMessage = 'Failed to submit score: $e';
      _setState(PuzzleState.solved);
    }
  }

  // ── Reset to idle ──────────────────────────────────────────────────────────
  void reset() {
    _currentPuzzle = null;
    _tiles = [];
    _moves = 0;
    _pointsEarned = 0;
    _errorMessage = null;
    _setState(PuzzleState.idle);
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _shuffleTiles(int size) {
    final total = size * size;
    _tiles = List.generate(total, (i) => i);
    final rand = Random();

    // Keep shuffling until solvable AND not already solved
    do {
      _tiles.shuffle(rand);
    } while (!_isSolvable(size) || _isGoalState());
  }

  /// Checks if a puzzle configuration is solvable using inversion count rule
  bool _isSolvable(int size) {
    int inversions = 0;
    final flat = _tiles.where((t) => t != 0).toList();
    for (int i = 0; i < flat.length; i++) {
      for (int j = i + 1; j < flat.length; j++) {
        if (flat[i] > flat[j]) inversions++;
      }
    }

    if (size.isOdd) {
      return inversions.isEven;
    } else {
      final emptyRow = _tiles.indexOf(0) ~/ size;
      final emptyFromBottom = size - emptyRow;
      return emptyFromBottom.isOdd
          ? inversions.isEven
          : inversions.isOdd;
    }
  }

  /// Goal: tiles[i] = i+1 for all except last which should be 0
  bool _isGoalState() {
    for (int i = 0; i < _tiles.length - 1; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return _tiles.last == 0;
  }

  /// Two tiles are adjacent if they share an edge (not diagonal)
  bool _isAdjacent(int a, int b, int size) {
    final rowA = a ~/ size, colA = a % size;
    final rowB = b ~/ size, colB = b % size;
    return (rowA == rowB && (colA - colB).abs() == 1) ||
        (colA == colB && (rowA - rowB).abs() == 1);
  }

  void _handleSolved() {
    _setState(PuzzleState.solved);
    // Auto-submit score
    submitScore();
  }

  void _setState(PuzzleState newState) {
    _state = newState;
    notifyListeners();
  }
}
