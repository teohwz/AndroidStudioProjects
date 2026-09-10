import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/quiz_model.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/fun_button.dart';

/// Exhibitor-scoped — always shows/creates quizzes for [boothId] (the
/// caller's own booth) only, never any other exhibitor's. The old free-text
/// "Exhibitor ID" field this used to expose (when any admin could manage
/// any exhibitor's quizzes) is gone — it's now fixed to the caller's booth.
class ManageQuizScreen extends StatefulWidget {
  const ManageQuizScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ManageQuizScreen> createState() => _ManageQuizScreenState();
}

class _ManageQuizScreenState extends State<ManageQuizScreen> {
  final _fs = FirestoreService();

  void _openQuizSheet([QuizModel? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _QuizFormSheet(fs: _fs, boothId: widget.boothId, existing: existing),
    );
  }

  void _confirmDelete(QuizModel q) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: Text('Delete "${q.title}"? Visitors will no longer see it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _fs.deleteQuiz(q.id);
            },
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Manage Quizzes 🧠',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.quizColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQuizSheet(),
        backgroundColor: AppColors.quizColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Quiz',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<QuizModel>>(
        stream: _fs.getQuizzesForExhibitorAdmin(widget.boothId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final quizzes = snap.data ?? [];
          if (quizzes.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🧠', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                const Text('No quizzes yet.',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 20),
                FunButton(
                  label: 'Create Quiz',
                  onPressed: () => _openQuizSheet(),
                  gradient: const LinearGradient(
                      colors: [AppColors.quizColor, Color(0xFF00BFA5)]),
                ),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: quizzes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final q = quizzes[i];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.quizColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.quiz_rounded,
                        color: AppColors.quizColor),
                  ),
                  title: Text(q.title,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${q.questions.length} questions · '
                      '${q.timeLimitSeconds}s · '
                      '${q.isActive ? "Active" : "Inactive"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.textMedium, size: 20),
                        onPressed: () => _openQuizSheet(q),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger, size: 20),
                        onPressed: () => _confirmDelete(q),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Quiz form bottom sheet ─────────────────────────────────────────────────────
class _QuizFormSheet extends StatefulWidget {
  const _QuizFormSheet(
      {required this.fs, required this.boothId, this.existing});
  final FirestoreService fs;
  final String boothId;
  final QuizModel? existing;

  @override
  State<_QuizFormSheet> createState() => _QuizFormSheetState();
}

class _QuizFormSheetState extends State<_QuizFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  int _timeLimitSeconds = 30;
  final List<_QuestionEntry> _questions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _timeLimitSeconds = e?.timeLimitSeconds ?? 30;
    if (e != null) {
      for (final q in e.questions) {
        _questions.add(_QuestionEntry.fromModel(q));
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _addQuestion() =>
      setState(() => _questions.add(_QuestionEntry()));

  void _removeQuestion(int i) =>
      setState(() => _questions.removeAt(i));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one question!')));
      return;
    }
    setState(() => _saving = true);

    final quizQuestions = _questions
        .map((q) => QuizQuestion(
              id: '',
              question: q.questionCtrl.text.trim(),
              options: q.optionCtrls.map((c) => c.text.trim()).toList(),
              correctIndex: q.correctIndex,
              correctIndices: q.correctIndices.toList(),
              points: q.bonusPoints,
              questionType: q.questionType,
            ))
        .toList();

    final quiz = QuizModel(
      id: widget.existing?.id ?? '',
      title: _titleCtrl.text.trim(),
      exhibitorId: widget.boothId,
      questions: quizQuestions,
      timeLimitSeconds: _timeLimitSeconds,
      isActive: widget.existing?.isActive ?? true,
    );

    try {
      if (widget.existing == null) {
        await widget.fs.addQuiz(quiz);
      } else {
        await widget.fs.updateQuiz(quiz);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.existing == null ? 'Create Quiz' : 'Edit Quiz',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleCtrl,
                decoration: _deco('Quiz Title *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Time per question:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _timeLimitSeconds,
                    items: [15, 20, 30, 45, 60]
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text('${s}s')))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _timeLimitSeconds = v!),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Questions',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add_rounded,
                        color: AppColors.quizColor),
                    label: const Text('Add',
                        style: TextStyle(color: AppColors.quizColor)),
                  ),
                ],
              ),
              ...List.generate(_questions.length, (i) => _QuestionCard(
                    index: i,
                    entry: _questions[i],
                    onRemove: () => _removeQuestion(i),
                    onCorrectChanged: (idx) =>
                        setState(() => _questions[i].correctIndex = idx),
                    onBonusChanged: (v) =>
                        setState(() => _questions[i].bonusPoints = v),
                    onTypeChanged: (type) =>
                        setState(() => _questions[i].questionType = type),
                    onCheckboxToggle: (idx) {
                      setState(() {
                        if (_questions[i].correctIndices.contains(idx)) {
                          _questions[i].correctIndices.remove(idx);
                        } else {
                          _questions[i].correctIndices.add(idx);
                        }
                      });
                    },
                  )),
              if (_questions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Text('Tap "Add" to create questions',
                        style: TextStyle(color: AppColors.textMedium)),
                  ),
                ),
              const SizedBox(height: 24),
              FunButton(
                label: _saving
                    ? 'Saving...'
                    : (widget.existing == null ? 'Save Quiz' : 'Update Quiz'),
                isLoading: _saving,
                onPressed: _save,
                gradient: const LinearGradient(
                    colors: [AppColors.quizColor, Color(0xFF00BFA5)]),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.grey.shade200, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.quizColor, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class _QuestionEntry {
  final questionCtrl = TextEditingController();
  final List<TextEditingController> optionCtrls =
      List.generate(4, (_) => TextEditingController());
  int correctIndex = 0;
  Set<int> correctIndices = {};
  int bonusPoints = 10;
  String questionType = 'multiple_choice'; // 'multiple_choice', 'checkbox', 'dropdown'

  _QuestionEntry();

  factory _QuestionEntry.fromModel(QuizQuestion q) {
    final e = _QuestionEntry();
    e.questionCtrl.text = q.question;
    for (int i = 0; i < q.options.length && i < 4; i++) {
      e.optionCtrls[i].text = q.options[i];
    }
    e.correctIndex = q.correctIndex;
    e.correctIndices = Set<int>.from(q.correctIndices);
    e.bonusPoints = q.points;
    e.questionType = q.questionType;
    return e;
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onCorrectChanged,
    required this.onBonusChanged,
    required this.onTypeChanged,
    required this.onCheckboxToggle,
  });

  final int index;
  final _QuestionEntry entry;
  final VoidCallback onRemove;
  final Function(int) onCorrectChanged;
  final Function(int) onBonusChanged;
  final Function(String) onTypeChanged;
  final Function(int) onCheckboxToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Q${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.quizColor)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            TextFormField(
              controller: entry.questionCtrl,
              decoration: InputDecoration(
                hintText: 'Enter question...',
                hintStyle: const TextStyle(color: AppColors.textMedium),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            // Question Type Selector
            Row(
              children: [
                const Text('Type:',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: entry.questionType,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'multiple_choice',
                        child: Text('Multiple Choice')),
                    DropdownMenuItem(
                        value: 'checkbox', child: Text('Checkbox')),
                    DropdownMenuItem(
                        value: 'dropdown', child: Text('Dropdown')),
                  ],
                  onChanged: (v) => onTypeChanged(v!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Options
            ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      entry.questionType == 'checkbox'
                          ? Checkbox(
                              value: entry.correctIndices.contains(i),
                              activeColor: AppColors.success,
                              onChanged: (v) => onCheckboxToggle(i),
                            )
                          : Radio<int>(
                              value: i,
                              groupValue: entry.correctIndex,
                              activeColor: AppColors.success,
                              onChanged: (v) => onCorrectChanged(v!),
                            ),
                      Expanded(
                        child: TextFormField(
                          controller: entry.optionCtrls[i],
                          decoration: InputDecoration(
                            hintText: 'Option ${['A', 'B', 'C', 'D'][i]}',
                            hintStyle: const TextStyle(
                                color: AppColors.textMedium, fontSize: 13),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                )),
            Text(
                entry.questionType == 'checkbox'
                    ? '● Green checkboxes = correct answers (multi-select)'
                    : '● Green radio = correct answer',
                style:
                    const TextStyle(color: AppColors.textMedium, fontSize: 11)),
            const SizedBox(height: 10),
            // Bonus points
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✅ Bonus pts',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success)),
                const SizedBox(height: 4),
                DropdownButton<int>(
                  value: entry.bonusPoints,
                  isDense: true,
                  items: [5, 10, 15, 20, 25, 50]
                      .map((v) => DropdownMenuItem(
                          value: v, child: Text('+$v')))
                      .toList(),
                  onChanged: (v) => onBonusChanged(v!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
