/// Represents a single quiz question with options and metadata
class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex; // for multiple choice and dropdown
  final List<int> correctIndices; // for checkbox (multi-select)
  final int points;
  final int penalty;
  final String? explanation;
  final String? imageUrl;
  final String questionType; // 'multiple_choice', 'checkbox', 'dropdown'

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.correctIndex = 0,
    this.correctIndices = const [],
    this.points = 10,
    this.penalty = 0,
    this.explanation,
    this.imageUrl,
    this.questionType = 'multiple_choice',
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasExplanation => explanation != null && explanation!.isNotEmpty;
  bool get isCheckbox => questionType == 'checkbox';
  bool get isDropdown => questionType == 'dropdown';

  bool isCorrect(int index) => correctIndex == index;
  
  bool isCheckboxCorrect(List<int> selectedIndices) {
    if (!isCheckbox) return false;
    final selected = Set<int>.from(selectedIndices);
    final correct = Set<int>.from(correctIndices);
    return selected.length == correct.length &&
        selected.difference(correct).isEmpty;
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) => QuizQuestion(
        id: map['id'] ?? '',
        question: map['question'] ?? '',
        options: List<String>.from(map['options'] ?? []),
        correctIndex: map['correctIndex'] ?? 0,
        correctIndices: List<int>.from(map['correctIndices'] ?? []),
        points: map['points'] ?? 10,
        penalty: map['penalty'] ?? 0,
        explanation: map['explanation'],
        imageUrl: map['imageUrl'],
        questionType: map['questionType'] ?? 'multiple_choice',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'correctIndices': correctIndices,
        'points': points,
        'penalty': penalty,
        'explanation': explanation,
        'imageUrl': imageUrl,
        'questionType': questionType,
      };
}

/// Represents a full quiz with metadata and list of questions
class QuizModel {
  final String id;
  final String title;
  final String description;
  final String exhibitorId;
  final List<QuizQuestion> questions;
  final int timeLimitSeconds;
  final bool isActive;
  final String category;
  final String difficulty;
  final int totalPlays;
  final DateTime? createdAt;

  QuizModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.exhibitorId,
    required this.questions,
    this.timeLimitSeconds = 30,
    this.isActive = true,
    this.category = 'General',
    this.difficulty = 'medium',
    this.totalPlays = 0,
    this.createdAt,
  });

  int get maxPoints => questions.fold(0, (sum, q) => sum + q.points);
  int get questionCount => questions.length;
  double get estimatedMinutes => (questionCount * timeLimitSeconds) / 60;

  factory QuizModel.fromMap(String id, Map<String, dynamic> map) => QuizModel(
        id: id,
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        exhibitorId: map['exhibitorId'] ?? '',
        questions: (map['questions'] as List<dynamic>? ?? [])
            .map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
            .toList(),
        timeLimitSeconds: map['timeLimitSeconds'] ?? 30,
        isActive: map['isActive'] ?? true,
        category: map['category'] ?? 'General',
        difficulty: map['difficulty'] ?? 'medium',
        totalPlays: map['totalPlays'] ?? 0,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'exhibitorId': exhibitorId,
        'questions': questions.map((q) => q.toMap()).toList(),
        'timeLimitSeconds': timeLimitSeconds,
        'isActive': isActive,
        'category': category,
        'difficulty': difficulty,
        'totalPlays': totalPlays,
        'createdAt': createdAt,
      };

  QuizModel copyWith({
    String? title,
    String? description,
    String? exhibitorId,
    List<QuizQuestion>? questions,
    int? timeLimitSeconds,
    bool? isActive,
    String? category,
    String? difficulty,
  }) =>
      QuizModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        exhibitorId: exhibitorId ?? this.exhibitorId,
        questions: questions ?? this.questions,
        timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
        isActive: isActive ?? this.isActive,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        totalPlays: totalPlays,
        createdAt: createdAt,
      );
}
