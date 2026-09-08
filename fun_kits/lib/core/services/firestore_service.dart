import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exhibitor_model.dart';
import '../models/quiz_model.dart';
import '../models/puzzle_model.dart';
import '../models/leaderboard_model.dart';
import '../models/lucky_draw_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════
  //  EXHIBITORS
  // ═══════════════════════════════════════════════════════════════════════

  Stream<List<ExhibitorModel>> getExhibitors() {
    return _db
        .collection('exhibitors')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExhibitorModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addExhibitor(ExhibitorModel exhibitor) async {
    await _db.collection('exhibitors').add(exhibitor.toMap());
  }

  Future<void> updateExhibitor(ExhibitorModel exhibitor) async {
    await _db.collection('exhibitors').doc(exhibitor.id).update(exhibitor.toMap());
  }

  Future<void> deleteExhibitor(String id) async {
    await _db.collection('exhibitors').doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  QUIZZES
  // ═══════════════════════════════════════════════════════════════════════

  Stream<List<QuizModel>> getQuizzes() {
    return _db
        .collection('quizzes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => QuizModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addQuiz(QuizModel quiz) async {
    await _db.collection('quizzes').add(quiz.toMap());
  }

  Future<void> updateQuiz(QuizModel quiz) async {
    await _db.collection('quizzes').doc(quiz.id).update(quiz.toMap());
  }

  Future<void> deleteQuiz(String id) async {
    await _db.collection('quizzes').doc(id).delete();
  }

  /// Returns quiz IDs that this user has already completed
  Future<List<String>> getCompletedQuizIds(String uid) async {
    final snap = await _db
        .collection('quiz_completions')
        .where('uid', isEqualTo: uid)
        .get();
    return snap.docs.map((d) => d['quizId'] as String).toList();
  }

  /// Marks a quiz as completed by a user (one attempt per quiz)
  Future<void> markQuizCompleted(String uid, String quizId) async {
    await _db.collection('quiz_completions').add({
      'uid': uid,
      'quizId': quizId,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  LUCKY DRAWS
  // ═══════════════════════════════════════════════════════════════════════

  Stream<List<LuckyDrawModel>> getLuckyDraws() {
    return _db
        .collection('lucky_draws')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LuckyDrawModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // All draws including inactive (for admin)
  Stream<List<LuckyDrawModel>> getAllLuckyDraws() {
    return _db
        .collection('lucky_draws')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LuckyDrawModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> joinLuckyDraw(String drawId, String uid) async {
    await _db.collection('lucky_draws').doc(drawId).update({
      'participants': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> setWinner(String drawId, String winnerUid) async {
    await _db.collection('lucky_draws').doc(drawId).update({
      'winnerUid': winnerUid,
      'isActive': false,
    });
  }

  Future<void> addLuckyDraw(LuckyDrawModel draw) async {
    await _db.collection('lucky_draws').add(draw.toMap());
  }

  Future<void> updateLuckyDraw(LuckyDrawModel draw) async {
    await _db.collection('lucky_draws').doc(draw.id).update(draw.toMap());
  }

  Future<void> deleteLuckyDraw(String id) async {
    await _db.collection('lucky_draws').doc(id).delete();
  }

  /// Returns draw IDs the user has already joined (for single-draw rule)
  Future<String?> getUserActiveDraw(String uid) async {
    final snap = await _db
        .collection('lucky_draws')
        .where('isActive', isEqualTo: true)
        .where('participants', arrayContains: uid)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  LEADERBOARD
  // ═══════════════════════════════════════════════════════════════════════

  Stream<List<LeaderboardEntry>> getLeaderboard() {
    return _db
        .collection('leaderboard')
        .orderBy('totalPoints', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      int rank = 1;
      return snap.docs.map((doc) {
        final entry = LeaderboardEntry.fromMap(doc.id, doc.data());
        return entry.withRank(rank++);
      }).toList();
    });
  }

  Future<String?> getUserDisplayName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) return null;

      return doc.data()?['displayName'] as String?;
    } catch (e) {
      print('Error fetching user display name: $e');
      return null;
    }
  }

  /// Add points and track unique game plays (gameType = 'quiz'|'puzzle'|'lucky_draw')
  Future<void> addPoints(String uid, String displayName, int points,
      {String gameType = ''}) async {
    final ref = _db.collection('leaderboard').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data()!;
        final breakdown =
            Map<String, int>.from(data['gameBreakdown'] ?? {});

        // Only increment gamesPlayed if this gameType hasn't been counted yet
        bool isNewGame = false;
        if (gameType.isNotEmpty && !breakdown.containsKey(gameType)) {
          isNewGame = true;
          breakdown[gameType] = points;
        } else if (gameType.isNotEmpty) {
          breakdown[gameType] = (breakdown[gameType] ?? 0) + points;
        }

        tx.update(ref, {
          'totalPoints': FieldValue.increment(points),
          if (isNewGame) 'gamesPlayed': FieldValue.increment(1),
          'gameBreakdown': breakdown,
          'lastPlayedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'displayName': displayName,
          'totalPoints': points,
          'gamesPlayed': gameType.isNotEmpty ? 1 : 0,
          'gameBreakdown':
              gameType.isNotEmpty ? {gameType: points} : {},
          'lastPlayedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    // Mirror points to users collection
    await _db
        .collection('users')
        .doc(uid)
        .update({'points': FieldValue.increment(points)});
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PUZZLES
  // ═══════════════════════════════════════════════════════════════════════

  Stream<List<PuzzleModel>> getPuzzles() {
    return _db
        .collection('puzzles')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PuzzleModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addPuzzle(PuzzleModel puzzle) async {
    await _db.collection('puzzles').add(puzzle.toMap());
  }

  Future<void> updatePuzzle(PuzzleModel puzzle) async {
    await _db.collection('puzzles').doc(puzzle.id).update(puzzle.toMap());
  }

  Future<void> deletePuzzle(String id) async {
    await _db.collection('puzzles').doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PUZZLE ATTEMPTS (resurrection tokens)
  // ═══════════════════════════════════════════════════════════════════════

  Future<int> getPuzzleAttempts(String uid) async {
    final doc = await _db.collection('puzzle_attempts').doc(uid).get();
    if (!doc.exists) return 3; // default 3 attempts
    return doc.data()?['attempts'] ?? 3;
  }

  Future<void> setPuzzleAttempts(String uid, int attempts) async {
    await _db
        .collection('puzzle_attempts')
        .doc(uid)
        .set({'attempts': attempts}, SetOptions(merge: true));
  }

  Future<void> addPuzzleAttempts(String uid, int count) async {
    await _db.collection('puzzle_attempts').doc(uid).set(
        {'attempts': FieldValue.increment(count)},
        SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BOOTH CHECK-INS (earn puzzle attempts)
  // ═══════════════════════════════════════════════════════════════════════

  /// Returns booth IDs this user has already checked into
  Future<List<String>> getCheckedInBooths(String uid) async {
    final snap = await _db
        .collection('booth_checkins')
        .where('uid', isEqualTo: uid)
        .get();
    return snap.docs.map((d) => d['boothId'] as String).toList();
  }

  /// Check into a booth — earns +1 puzzle attempt if first time
  Future<bool> checkInBooth(String uid, String boothId) async {
    final existing = await _db
        .collection('booth_checkins')
        .where('uid', isEqualTo: uid)
        .where('boothId', isEqualTo: boothId)
        .get();
    if (existing.docs.isNotEmpty) return false; // already checked in

    await _db.collection('booth_checkins').add({
      'uid': uid,
      'boothId': boothId,
      'checkedInAt': FieldValue.serverTimestamp(),
    });
    await addPuzzleAttempts(uid, 1);
    return true; // new check-in
  }
}
