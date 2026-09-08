import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/quiz_model.dart';
import '../../core/services/firestore_service.dart';

enum QuizState { idle, loading, inProgress, answered, finished, error }

class QuizResult {
  final int totalQuestions;
  final int correctAnswers;
  final int totalPoints;
  final int timeTakenSeconds;

  QuizResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalPoints,
    required this.timeTakenSeconds,
  });

  double get accuracy =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0;

  String get grade {
    if (accuracy >= 0.9) return 'A+';
    if (accuracy >= 0.8) return 'A';
    if (accuracy >= 0.7) return 'B';
    if (accuracy >= 0.6) return 'C';
    return 'Try Again';
  }

  String get gradeEmoji {
    if (accuracy >= 0.8) return '🎉';
    if (accuracy >= 0.6) return '👍';
    return '💪';
  }
}

class QuizController extends ChangeNotifier {
  final FirestoreService _fs;
  final FirebaseAuth _auth;

  QuizController({
    FirestoreService? firestoreService,
    FirebaseAuth? auth,
  })  : _fs = firestoreService ?? FirestoreService(),
        _auth = auth ?? FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────────────────────────
  QuizState _state = QuizState.idle;
  QuizModel? _currentQuiz;
  int _currentIndex = 0;
  int _selectedOption = -1;
  int _score = 0;
  int _correctCount = 0;
  int _timeLeft = 30;
  int _totalTimeTaken = 0;
  Timer? _timer;
  QuizResult? _result;
  String? _errorMessage;
  List<int> _userAnswers = []; // -1 = skipped

  // ── Getters ────────────────────────────────────────────────────────────────
  QuizState get state => _state;
  QuizModel? get currentQuiz => _currentQuiz;
  int get currentIndex => _currentIndex;
  int get selectedOption => _selectedOption;
  int get score => _score;
  int get timeLeft => _timeLeft;
  QuizResult? get result => _result;
  String? get errorMessage => _errorMessage;
  List<int> get userAnswers => _userAnswers;

  bool get isAnswered => _state == QuizState.answered;
  bool get isFinished => _state == QuizState.finished;
  bool get isInProgress => _state == QuizState.inProgress;
  bool get isTimeCritical => _timeLeft <= 5;

  QuizQuestion? get currentQuestion =>
      _currentQuiz != null &&
              _currentIndex < _currentQuiz!.questions.length
          ? _currentQuiz!.questions[_currentIndex]
          : null;

  double get progress =>
      _currentQuiz != null && _currentQuiz!.questionCount > 0
          ? (_currentIndex + 1) / _currentQuiz!.questionCount
          : 0;

  // ── Start a quiz ───────────────────────────────────────────────────────────
  void startQuiz(QuizModel quiz) {
    _currentQuiz = quiz;
    _currentIndex = 0;
    _selectedOption = -1;
    _score = 0;
    _correctCount = 0;
    _totalTimeTaken = 0;
    _result = null;
    _errorMessage = null;
    _userAnswers = List.filled(quiz.questionCount, -1);
    _setState(QuizState.inProgress);
    _startTimer();
  }

  // ── Answer a question ──────────────────────────────────────────────────────
  void answerQuestion(int optionIndex) {
    if (_state != QuizState.inProgress || currentQuestion == null) {
      return;
    }
    _timer?.cancel();

    final question = currentQuestion!;
    final isCorrect = question.isCorrect(optionIndex);

    _selectedOption = optionIndex;
    _userAnswers[_currentIndex] = optionIndex;
    _totalTimeTaken +=
        (question.points ~/ 1) - _timeLeft + 1; // rough elapsed

    if (isCorrect) {
      _score += question.points;
      _correctCount++;
    }

    _setState(QuizState.answered);

    // Auto-advance after 1.2 s
    Future.delayed(
        const Duration(milliseconds: 1200), nextQuestion);
  }

  // ── Advance to next question or finish ─────────────────────────────────────
  void nextQuestion({bool forceSkip = false}) {
    if (_currentQuiz == null) return;
    _timer?.cancel();

    if (forceSkip && _state == QuizState.inProgress) {
      _userAnswers[_currentIndex] = -1; // mark as skipped
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _currentQuiz!.questionCount) {
      _finishQuiz();
      return;
    }

    _currentIndex = nextIndex;
    _selectedOption = -1;
    _setState(QuizState.inProgress);
    _startTimer();
  }

  // ── Finish and submit score ────────────────────────────────────────────────
  Future<void> _finishQuiz() async {
    _timer?.cancel();
    _result = QuizResult(
      totalQuestions: _currentQuiz!.questionCount,
      correctAnswers: _correctCount,
      totalPoints: _score,
      timeTakenSeconds: _totalTimeTaken,
    );
    _setState(QuizState.finished);

    final user = _auth.currentUser;
    if (user != null && _score > 0) {
      try {
        await _fs.addPoints(
            user.uid, user.displayName ?? 'Player', _score);
      } catch (_) {}
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────────
  void reset() {
    _timer?.cancel();
    _currentQuiz = null;
    _currentIndex = 0;
    _selectedOption = -1;
    _score = 0;
    _correctCount = 0;
    _timeLeft = 30;
    _totalTimeTaken = 0;
    _result = null;
    _errorMessage = null;
    _userAnswers = [];
    _setState(QuizState.idle);
  }

  // ── Internal timer ─────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _currentQuiz?.timeLimitSeconds ?? 30;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 0) {
        t.cancel();
        nextQuestion(forceSkip: true);
      } else {
        _timeLeft--;
        notifyListeners();
      }
    });
  }

  void _setState(QuizState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
