import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/lucky_draw_model.dart';
import '../../core/services/firestore_service.dart';

enum DrawState { idle, joining, spinning, won, closed }

class LuckyDrawController extends ChangeNotifier {
  final FirestoreService _fs;
  final FirebaseAuth _auth;

  LuckyDrawController({
    FirestoreService? firestoreService,
    FirebaseAuth? auth,
  })  : _fs = firestoreService ?? FirestoreService(),
        _auth = auth ?? FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────────────────────────
  DrawState _state = DrawState.idle;
  String? _errorMessage;
  String? _winnerUid;
  String? _winnerName;
  LuckyDrawModel? _activeDraw;

  // ── Getters ────────────────────────────────────────────────────────────────
  DrawState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get winnerUid => _winnerUid;
  String? get winnerName => _winnerName;
  LuckyDrawModel? get activeDraw => _activeDraw;

  bool get isSpinning => _state == DrawState.spinning;
  bool get hasWinner => _winnerUid != null;
  bool get isIdle => _state == DrawState.idle;

  String? get currentUid => _auth.currentUser?.uid;
  String? get currentDisplayName => _auth.currentUser?.displayName;

  bool isParticipant(LuckyDrawModel draw) =>
      currentUid != null &&
      draw.participants.contains(currentUid);

  // ── Join a lucky draw ──────────────────────────────────────────────────────
  Future<void> joinDraw(LuckyDrawModel draw) async {
    if (currentUid == null) {
      _setError('Please log in to join a draw.');
      return;
    }
    if (isParticipant(draw)) {
      _setError('You have already joined this draw!');
      return;
    }
    if (!draw.isActive) {
      _setError('This draw has already closed.');
      return;
    }

    _setState(DrawState.joining);
    try {
      await _fs.joinLuckyDraw(draw.id, currentUid!);
      _setState(DrawState.idle);
    } catch (e) {
      _setError('Failed to join draw: $e');
    }
  }

  // ── Spin and pick a winner (admin only) ───────────────────────────────────
  Future<void> spinAndPickWinner(LuckyDrawModel draw) async {
    if (_state == DrawState.spinning) return;
    if (draw.participants.isEmpty) {
      _setError('No participants to draw from!');
      return;
    }
    if (!draw.isActive) {
      _setError('This draw has already ended.');
      return;
    }

    _activeDraw = draw;
    _winnerUid = null;
    _winnerName = null;
    _setState(DrawState.spinning);

    // Simulate suspense delay for animation
    await Future.delayed(const Duration(seconds: 3));

    try {
      final rand = Random.secure();
      final pickedUid =
          draw.participants[rand.nextInt(draw.participants.length)];

      await _fs.setWinner(draw.id, pickedUid);
      await _fs.addPoints(
          pickedUid, currentDisplayName ?? 'Winner', 100);

      _winnerUid = pickedUid;
      _winnerName = _truncateUid(pickedUid);
      _setState(DrawState.won);
    } catch (e) {
      _setError('Failed to pick winner: $e');
    }
  }

  // ── Reset state ────────────────────────────────────────────────────────────
  void reset() {
    _state = DrawState.idle;
    _errorMessage = null;
    _winnerUid = null;
    _winnerName = null;
    _activeDraw = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setState(DrawState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = DrawState.idle;
    notifyListeners();
  }

  String _truncateUid(String uid) =>
      uid.length > 8 ? '${uid.substring(0, 8)}...' : uid;
}
