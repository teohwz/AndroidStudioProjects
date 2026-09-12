import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_palette.dart';
import '../../core/models/quiz_model.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/fun_button.dart';
import '../../shared/widgets/icon_badge.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.initialQuiz, this.exhibitorId});

  /// When set (e.g. opened from a booth screen), the quiz starts
  /// immediately instead of showing the pick-a-quiz list.
  final QuizModel? initialQuiz;

  /// When set (and [initialQuiz] is not), the quiz list is filtered to a
  /// single booth's quizzes instead of every active quiz.
  final String? exhibitorId;

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
  DateTime? _quizStartedAt;

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
    final initial = widget.initialQuiz;
    if (initial != null && mounted && !_completedIds.contains(initial.id)) {
      _selectQuiz(initial);
    }
  }

  void _selectQuiz(QuizModel q) {
    setState(() {
      _selectedQuiz = q;
      _currentIndex = 0;
      _selectedOption = -1;
      _selectedCheckboxes.clear();
      _answered = false;
      _score = 0;
      _finished = false;
      _pointDelta = 0;
      _quizStartedAt = DateTime.now();
    });
    _startTimer();
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
      final delta = correct ? question.points : 0;
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
    final delta = correct ? question.points : 0;
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
    // A single shared 'quiz' bucket (not one key per quiz id) so every
    // quiz a visitor plays counts toward the same "Quiz" leaderboard
    // filter, and so game_sessions can be summed per-booth below. Only
    // award points when there's something to award — addPoints() with 0
    // would be a harmless no-op write, so this guard is purely to skip an
    // unnecessary transaction.
    if (_score > 0) {
      await _fs.addPoints(user.uid, user.displayName ?? 'Player', _score,
          gameType: 'quiz');
    }
    // Log the session unconditionally — a 0-point quiz attempt is still a
    // real play and must count toward "My Stats", per-booth leaderboards,
    // and gamesPlayed, exactly like every other mini-game already does via
    // submitGameScore()'s unconditional logGameSession call (game_common.
    // dart). Previously this call lived inside the `if (_score > 0)` block
    // above, so a visitor who got every question wrong left no
    // game_sessions record at all — invisible to every screen that reads
    // that collection, even though they genuinely played.
    final exhibitorId = _selectedQuiz!.exhibitorId;
    final durationMs = _quizStartedAt == null
        ? null
        : DateTime.now().difference(_quizStartedAt!).inMilliseconds;
    await _fs.logGameSession(user.uid, 'quiz', _score,
        exhibitorId: exhibitorId.isNotEmpty ? exhibitorId : null,
        durationMs: durationMs);
    await _fs.markQuizCompleted(user.uid, _selectedQuiz!.id);
    if (mounted) setState(() => _completedIds = [..._completedIds, _selectedQuiz!.id]);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.initialQuiz?.title ?? 'Quiz & Trivia'),
        backgroundColor: palette.quizColor,
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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return StreamBuilder<List<QuizModel>>(
      stream: widget.exhibitorId != null
          ? _fs.getQuizzesForExhibitor(widget.exhibitorId!)
          : _fs.getQuizzes(),
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
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: IconBadge(
                  icon: done ? Icons.check_circle_rounded : Icons.quiz_rounded,
                  color: done ? theme.colorScheme.onSurfaceVariant : palette.quizColor,
                  size: 46,
                ),
                title: Text(q.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        color:
                            done ? theme.colorScheme.onSurfaceVariant : null)),
                subtitle: Text(
                    '${q.questions.length} questions · ${q.timeLimitSeconds}s each'
                    '${done ? ' · Completed' : ''}'),
                trailing: done
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('Done',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ],
                      )
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: done
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'You have already completed this quiz.')))
                    : () => _selectQuiz(q),
              ),
            );
          },
        );
      },
    );
  }

  // ── Question View ──────────────────────────────────────────────────────────
  Widget _buildQuestion() {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
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
                    backgroundColor: palette.cardBg,
                    valueColor: AlwaysStoppedAnimation(palette.quizColor),
                    minHeight: 7,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${_currentIndex + 1}/${quiz.questions.length}',
                  style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timer_rounded, color: palette.warning, size: 18),
              const SizedBox(width: 4),
              Text('$_timeLeft s',
                  style: TextStyle(
                      color: _timeLeft <= 5 ? palette.danger : palette.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Score: $_score',
                    style: TextStyle(
                        color: palette.success, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          // Points info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _Chip('+${question.points} correct', palette.success),
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
                      color: _pointDelta > 0 ? palette.success : palette.danger),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.quizColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.quizColor.withOpacity(0.25)),
            ),
            child: Text(question.question,
                style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 16),
          // Render based on question type
          if (question.isDropdown && !_answered)
            // Dropdown
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant, width: 1.5),
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
                            ? palette.quizColor.withOpacity(0.08)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected
                                ? palette.quizColor
                                : theme.colorScheme.outlineVariant,
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            activeColor: palette.quizColor,
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
                      backgroundColor: palette.quizColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Submit Answer'),
                  ),
                ),
              ],
            )
          else
            // Multiple choice (default) OR show results after answering
            ...List.generate(question.options.length, (i) {
              Color bg = theme.colorScheme.surface;
              Color border = theme.colorScheme.outlineVariant;
              if (_answered) {
                final isCorrect = question.isCheckbox
                    ? question.correctIndices.contains(i)
                    : i == question.correctIndex;
                final wasSelected = question.isCheckbox
                    ? _selectedCheckboxes.contains(i)
                    : i == _selectedOption;

                if (isCorrect) {
                  bg = palette.success.withOpacity(0.15);
                  border = palette.success;
                } else if (wasSelected) {
                  bg = palette.danger.withOpacity(0.15);
                  border = palette.danger;
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
                          color: palette.quizColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(['A', 'B', 'C', 'D'][i],
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: palette.quizColor,
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
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(question.explanation!,
                        style: TextStyle(
                            fontSize: 13, color: theme.colorScheme.primary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final quiz = _selectedQuiz!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.quizColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events_rounded,
                  size: 48, color: palette.quizColor),
            ),
            const SizedBox(height: 16),
            Text('Quiz Complete!', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text('You scored $_score points!',
                style: TextStyle(fontSize: 18, color: palette.quizColor)),
            const SizedBox(height: 8),
            Text('Quiz "${quiz.title}" is now locked for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMedium, fontSize: 13)),
            const SizedBox(height: 32),
            FunButton(
              label: widget.initialQuiz != null ? 'Back to Booth' : 'Back to Quizzes',
              onPressed: () {
                if (widget.initialQuiz != null) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _selectedQuiz = null;
                    _currentIndex = 0;
                    _score = 0;
                    _finished = false;
                  });
                }
              },
              gradient: LinearGradient(
                  colors: [palette.quizColor, palette.puzzleColor]),
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
