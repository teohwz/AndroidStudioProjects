import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/quiz_model.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/fun_button.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _fs = FirestoreService();
  List<String> _completedIds = [];
  bool _loadingCompleted = true;

  QuizModel? _selectedQuiz;
  int _currentIndex = 0;
  int _selectedOption = -1;
  Set<int> _selectedCheckboxes = {};
  bool _answered = false;
  int _score = 0;
  bool _finished = false;
  int _timeLeft = 30;
  Timer? _timer;
  int _pointDelta = 0; // last +/- feedback

  @override
  void initState() {
    super.initState();
    _loadCompleted();
  }

  Future<void> _loadCompleted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final ids = await _fs.getCompletedQuizIds(uid);
      if (mounted) setState(() { _completedIds = ids; _loadingCompleted = false; });
    } else {
      setState(() => _loadingCompleted = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _selectedQuiz?.timeLimitSeconds ?? 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) { t.cancel(); _nextQuestion(forceSkip: true); }
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    final question = _selectedQuiz!.questions[_currentIndex];
    
    if (question.isCheckbox) {
      setState(() {
        if (_selectedCheckboxes.contains(index)) {
          _selectedCheckboxes.remove(index);
        } else {
          _selectedCheckboxes.add(index);
        }
      });
    } else {
      _timer?.cancel();
      final correct = question.isCorrect(index);
      final delta = correct ? question.points : -question.penalty;
      setState(() {
        _selectedOption = index;
        _answered = true;
        _score = (_score + delta).clamp(0, 99999);
        _pointDelta = delta;
      });
      Future.delayed(const Duration(milliseconds: 1300), _nextQuestion);
    }
  }

  void _submitCheckbox() {
    if (_answered) return;
    _timer?.cancel();
    final question = _selectedQuiz!.questions[_currentIndex];
    final correct = question.isCheckboxCorrect(_selectedCheckboxes.toList());
    final delta = correct ? question.points : -question.penalty;
    setState(() {
      _answered = true;
      _score = (_score + delta).clamp(0, 99999);
      _pointDelta = delta;
    });
    Future.delayed(const Duration(milliseconds: 1300), _nextQuestion);
  }

  void _nextQuestion({bool forceSkip = false}) {
    final quiz = _selectedQuiz!;
    if (_currentIndex + 1 >= quiz.questions.length) {
      _timer?.cancel();
      setState(() => _finished = true);
      _submitScore();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = -1;
      _selectedCheckboxes.clear();
      _answered = false;
      _pointDelta = 0;
    });
    _startTimer();
  }

  Future<void> _submitScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_score > 0) {
      await _fs.addPoints(user.uid, user.displayName ?? 'Player', _score,
          gameType: 'quiz_${_selectedQuiz!.id}');
    }
    await _fs.markQuizCompleted(user.uid, _selectedQuiz!.id);
    if (mounted) setState(() => _completedIds = [..._completedIds, _selectedQuiz!.id]);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Quiz & Trivia 🧠',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.quizColor,
        foregroundColor: Colors.white,
      ),
      body: _loadingCompleted
          ? const Center(child: CircularProgressIndicator())
          : _selectedQuiz == null
              ? _buildQuizList()
              : _finished
                  ? _buildResult()
                  : _buildQuestion(),
    );
  }

  // ── Quiz List ──────────────────────────────────────────────────────────────
  Widget _buildQuizList() {
    return StreamBuilder<List<QuizModel>>(
      stream: _fs.getQuizzes(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final quizzes = snap.data ?? [];
        if (quizzes.isEmpty) {
          return const Center(child: Text('No active quizzes yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: quizzes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final q = quizzes[i];
            final done = _completedIds.contains(q.id);
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: done
                        ? Colors.grey.shade200
                        : AppColors.quizColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    done ? Icons.check_circle_rounded : Icons.quiz_rounded,
                    color: done ? AppColors.textMedium : AppColors.quizColor,
                  ),
                ),
                title: Text(q.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: done ? AppColors.textMedium : AppColors.textDark)),
                subtitle: Text(
                    '${q.questions.length} questions · ${q.timeLimitSeconds}s each'
                    '${done ? ' · Completed' : ''}'),
                trailing: done
                    ? const Text('Done ✓',
                        style: TextStyle(
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w600,
                            fontSize: 12))
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: done
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'You have already completed this quiz.')))
                    : () {
                        setState(() {
                          _selectedQuiz = q;
                          _currentIndex = 0;
                          _selectedOption = -1;
                          _answered = false;
                          _score = 0;
                          _finished = false;
                          _pointDelta = 0;
                        });
                        _startTimer();
                      },
              ),
            );
          },
        );
      },
    );
  }

  // ── Question View ──────────────────────────────────────────────────────────
  Widget _buildQuestion() {
    final quiz = _selectedQuiz!;
    final question = quiz.questions[_currentIndex];
    final progress = (_currentIndex + 1) / quiz.questions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.quizColor),
                    minHeight: 7,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${_currentIndex + 1}/${quiz.questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.timer, color: AppColors.warning, size: 18),
              const SizedBox(width: 4),
              Text('$_timeLeft s',
                  style: TextStyle(
                      color: _timeLeft <= 5 ? AppColors.danger : AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Score: $_score',
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          // Points/penalty info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _Chip('+${question.points} correct', AppColors.success),
                const SizedBox(width: 8),
                if (question.penalty > 0)
                  _Chip('-${question.penalty} wrong', AppColors.danger),
              ],
            ),
          ),
          // Point delta feedback
          if (_answered && _pointDelta != 0)
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Text(
                  _pointDelta > 0 ? '+$_pointDelta pts!' : '$_pointDelta pts',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _pointDelta > 0 ? AppColors.success : AppColors.danger),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.quizColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.quizColor.withOpacity(0.25)),
            ),
            child: Text(question.question,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          // Render based on question type
          if (question.isDropdown && !_answered)
            // Dropdown
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
              ),
              child: DropdownButton<int>(
                value: _selectedOption >= 0 ? _selectedOption : null,
                hint: const Text('Select an option...'),
                isExpanded: true,
                underline: const SizedBox(),
                items: List.generate(
                  question.options.length,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(question.options[i]),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) _selectOption(v);
                },
              ),
            )
          else if (question.isCheckbox && !_answered)
            // Checkbox (multi-select)
            Column(
              children: [
                ...List.generate(question.options.length, (i) {
                  final selected = _selectedCheckboxes.contains(i);
                  return GestureDetector(
                    onTap: () => _selectOption(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.quizColor.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected
                                ? AppColors.quizColor
                                : const Color(0xFFE0E0E0),
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            activeColor: AppColors.quizColor,
                            onChanged: (_) => _selectOption(i),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(question.options[i],
                                  style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _selectedCheckboxes.isEmpty ? null : _submitCheckbox,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.quizColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Submit Answer',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            )
          else
            // Multiple choice (default) OR show results after answering
            ...List.generate(question.options.length, (i) {
              Color bg = Colors.white;
              Color border = const Color(0xFFE0E0E0);
              if (_answered) {
                final isCorrect = question.isCheckbox
                    ? question.correctIndices.contains(i)
                    : i == question.correctIndex;
                final wasSelected = question.isCheckbox
                    ? _selectedCheckboxes.contains(i)
                    : i == _selectedOption;

                if (isCorrect) {
                  bg = AppColors.success.withOpacity(0.15);
                  border = AppColors.success;
                } else if (wasSelected) {
                  bg = AppColors.danger.withOpacity(0.15);
                  border = AppColors.danger;
                }
              }
              return GestureDetector(
                onTap: () => _selectOption(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.quizColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(['A', 'B', 'C', 'D'][i],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.quizColor,
                                  fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(question.options[i],
                              style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
              );
            }),
          // Explanation
          if (_answered && question.hasExplanation)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('💡 ${question.explanation}',
                  style: const TextStyle(fontSize: 13, color: Colors.blue)),
            ),
        ],
      ),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final quiz = _selectedQuiz!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('Quiz Complete!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('You scored $_score points!',
                style: const TextStyle(
                    fontSize: 18, color: AppColors.quizColor)),
            const SizedBox(height: 8),
            Text('Quiz "${quiz.title}" is now locked for you.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMedium, fontSize: 13)),
            const SizedBox(height: 32),
            FunButton(
              label: 'Back to Quizzes',
              onPressed: () => setState(() {
                _selectedQuiz = null;
                _currentIndex = 0;
                _score = 0;
                _finished = false;
              }),
              gradient: const LinearGradient(
                  colors: [AppColors.quizColor, Color(0xFF00BFA5)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}
