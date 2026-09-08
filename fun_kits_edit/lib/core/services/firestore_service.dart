import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exhibitor_model.dart';
import '../models/quiz_model.dart';
import '../models/puzzle_model.dart';
import '../models/leaderboard_model.dart';
import '../models/lucky_draw_model.dart';
import '../models/reward_model.dart';
import '../models/redemption_model.dart';
import '../models/inventory_log_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════
  //  EXHIBITORS
  // ═══════════════════════════════════════════════════════════════════════

  /// Visitor-facing directory — active booths only. Filtered client-side
  /// (not via a Firestore `where('isActive', ...)` query) so pre-existing
  /// exhibitor docs from before this field existed — which have no
  /// `isActive` at all — still show up, matching ExhibitorModel.fromMap's
  /// "missing means true" default rather than being silently hidden by a
  /// query that would exclude anything lacking the field.
  Stream<List<ExhibitorModel>> getExhibitors() {
    return _db
        .collection('exhibitors')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExhibitorModel.fromMap(doc.id, doc.data()))
            .where((e) => e.isActive)
            .toList());
  }

  /// Every booth regardless of active/claimed state — Super Admin's Manage
  /// Booths screen.
  Stream<List<ExhibitorModel>> getBoothsAdmin() {
    return _db.collection('exhibitors').orderBy('name').snapshots().map(
        (snap) => snap.docs
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

  /// Super Admin creates a minimal booth "slot" ahead of assigning it to an
  /// exhibitor — just enough to generate an invite code against. The
  /// exhibitor fills in everything else (name/logo/theme/etc.) themselves
  /// after redeeming their code, from their own Booth Editor.
  Future<String> createBoothSlot({
    required String boothNumber,
    String name = '',
  }) async {
    final ref = await _db.collection('exhibitors').add({
      'name': name.isEmpty ? 'Booth $boothNumber' : name,
      'description': '',
      'contactEmail': '',
      'boothNumber': boothNumber,
      'category': 'General',
      'tags': <String>[],
      'isSponsored': false,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> setBoothActive(String boothId, bool isActive) async {
    await _db.collection('exhibitors').doc(boothId).update({
      'isActive': isActive,
    });
  }

  /// Saves ONLY the fields an exhibitor is allowed to change about their
  /// own booth — never ownerUid/isActive/boothNumber (Super-Admin-only
  /// concerns) — see ExhibitorModel.toCustomizationMap.
  Future<void> updateBoothCustomization(ExhibitorModel booth) async {
    await _db
        .collection('exhibitors')
        .doc(booth.id)
        .update(booth.toCustomizationMap());
  }

  /// Enable/disable one of the 6 generic games at this booth and set the
  /// flat number of points it awards on completion.
  Future<void> updateGameConfig({
    required String boothId,
    required String gameType,
    required bool enabled,
    required int points,
  }) async {
    await _db.collection('exhibitors').doc(boothId).update({
      'gameConfig.$gameType': {'enabled': enabled, 'points': points},
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EXHIBITOR INVITES — how a brand-new exhibitor account is ever created.
  //  There is deliberately no self-registration path: Super Admin generates
  //  a single-use code tied to one specific booth slot; the exhibitor
  //  redeems it (see AuthService.registerExhibitor) to create their OWN
  //  Firebase account, atomically linked to that booth. See firestore.rules
  //  for how this is enforced server-side, not just by this code existing.
  // ═══════════════════════════════════════════════════════════════════════

  /// Generates a short, human-typeable invite code tied to [boothId] and
  /// writes it as the new doc's id. Retries on the astronomically unlikely
  /// chance of a collision with an existing code.
  Future<String> generateExhibitorInvite({
    required String boothId,
    required String createdByUid,
  }) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I ambiguity
    final rnd = Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(8, (_) => chars[rnd.nextInt(chars.length)])
          .join();
      final ref = _db.collection('exhibitor_invites').doc(code);
      final existing = await ref.get();
      if (existing.exists) continue; // collision — retry with a new code
      await ref.set({
        'boothId': boothId,
        'used': false,
        'usedByUid': null,
        'usedAt': null,
        'createdByUid': createdByUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return code;
    }
    throw Exception('Could not generate a unique invite code — try again.');
  }

  /// All invite codes ever issued for [boothId] (newest first) — Super
  /// Admin's Manage Booths screen shows whether a booth's latest code is
  /// still unused or already claimed.
  Stream<List<Map<String, dynamic>>> getInvitesForBooth(String boothId) {
    return _db
        .collection('exhibitor_invites')
        .where('boothId', isEqualTo: boothId)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => {'code': d.id, ...d.data()}).toList();
      docs.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at == null || bt == null) return 0;
        return (bt as Timestamp).compareTo(at as Timestamp);
      });
      return docs;
    });
  }

  /// Redeems an exhibitor invite [code] for the just-created Firebase Auth
  /// account [uid]. Atomically: validates the code is unused and its booth
  /// still unclaimed, marks the code used, links the booth's ownerUid, and
  /// creates `users/{uid}` with role 'exhibitor'. Called from
  /// AuthService.registerExhibitor() right after createUserWithEmailAndPassword
  /// succeeds — if this fails, the caller deletes the just-created auth
  /// account rather than leaving an orphan with no role/booth.
  Future<RedemptionOutcome> redeemExhibitorInvite({
    required String code,
    required String uid,
    required String displayName,
    required String email,
  }) async {
    final inviteRef = _db.collection('exhibitor_invites').doc(code);
    final userRef = _db.collection('users').doc(uid);

    return _db.runTransaction<RedemptionOutcome>((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        return const RedemptionOutcome.failure('invalid_code');
      }
      final invite = inviteSnap.data()!;
      if (invite['used'] == true) {
        return const RedemptionOutcome.failure('already_used');
      }
      final boothId = invite['boothId'] as String? ?? '';
      final boothRef = _db.collection('exhibitors').doc(boothId);
      final boothSnap = await tx.get(boothRef);
      if (!boothSnap.exists) {
        return const RedemptionOutcome.failure('booth_missing');
      }
      if ((boothSnap.data()?['ownerUid'] as String?)?.isNotEmpty == true) {
        return const RedemptionOutcome.failure('booth_already_claimed');
      }

      tx.update(inviteRef, {
        'used': true,
        'usedByUid': uid,
        'usedAt': FieldValue.serverTimestamp(),
      });
      tx.update(boothRef, {'ownerUid': uid});
      tx.set(userRef, {
        'displayName': displayName,
        'email': email,
        'role': 'exhibitor',
        'boothId': boothId,
        'points': 0,
        'accountStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return RedemptionOutcome.success(boothId);
    });
  }

  /// Looks up a single exhibitor by its Firestore document id.
  /// Used when a QR code (`funkits:booth:<id>`) is scanned.
  Future<ExhibitorModel?> getExhibitorById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _db.collection('exhibitors').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ExhibitorModel.fromMap(doc.id, doc.data()!);
  }

  /// Live view of one booth — the Exhibitor Dashboard's own booth, updating
  /// immediately as the exhibitor edits it.
  Stream<ExhibitorModel?> watchExhibitor(String boothId) {
    return _db.collection('exhibitors').doc(boothId).snapshots().map((doc) =>
        doc.exists && doc.data() != null
            ? ExhibitorModel.fromMap(doc.id, doc.data()!)
            : null);
  }

  /// Fallback lookup for manual booth-code entry (e.g. camera unavailable).
  Future<ExhibitorModel?> getExhibitorByBoothNumber(String boothNumber) async {
    if (boothNumber.isEmpty) return null;
    final snap = await _db
        .collection('exhibitors')
        .where('boothNumber', isEqualTo: boothNumber)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ExhibitorModel.fromMap(snap.docs.first.id, snap.docs.first.data());
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

  /// Active quizzes belonging to a single booth — used on the booth screen
  /// reached via QR scan.
  Stream<List<QuizModel>> getQuizzesForExhibitor(String exhibitorId) {
    return _db
        .collection('quizzes')
        .where('isActive', isEqualTo: true)
        .where('exhibitorId', isEqualTo: exhibitorId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => QuizModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Every quiz belonging to a single booth, active or not — the
  /// exhibitor's OWN Manage Quizzes screen (unlike the visitor-facing
  /// method above, this must show inactive quizzes too so they can be
  /// re-enabled/edited, not just newly created ones).
  Stream<List<QuizModel>> getQuizzesForExhibitorAdmin(String exhibitorId) {
    return _db
        .collection('quizzes')
        .where('exhibitorId', isEqualTo: exhibitorId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => QuizModel.fromMap(doc.id, doc.data()))
            .toList());
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

  /// Active lucky draws belonging to a single booth.
  Stream<List<LuckyDrawModel>> getLuckyDrawsForExhibitor(String exhibitorId) {
    return _db
        .collection('lucky_draws')
        .where('isActive', isEqualTo: true)
        .where('exhibitorId', isEqualTo: exhibitorId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LuckyDrawModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Every lucky draw belonging to a single booth, active or not — the
  /// exhibitor's own Manage Lucky Draws screen.
  Stream<List<LuckyDrawModel>> getLuckyDrawsForExhibitorAdmin(
      String exhibitorId) {
    return _db
        .collection('lucky_draws')
        .where('exhibitorId', isEqualTo: exhibitorId)
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
  /// Awards points and tracks unique game plays. Exhibitor and Super Admin
  /// accounts never earn points or appear on any leaderboard — enforced
  /// HERE (not just by hiding UI) since this is the one function every
  /// point-earning path in the app funnels through.
  Future<void> addPoints(String uid, String displayName, int points,
      {String gameType = ''}) async {
    final requesterDoc = await _db.collection('users').doc(uid).get();
    final requesterRole = requesterDoc.data()?['role'] as String? ?? 'visitor';
    if (requesterRole == 'exhibitor' || requesterRole == 'super_admin') return;

    final ref = _db.collection('leaderboard').doc(uid);
    final isNewGame = await _db.runTransaction<bool>((tx) async {
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
        return isNewGame;
      } else {
        tx.set(ref, {
          'displayName': displayName,
          'totalPoints': points,
          'gamesPlayed': gameType.isNotEmpty ? 1 : 0,
          'gameBreakdown':
              gameType.isNotEmpty ? {gameType: points} : {},
          'lastPlayedAt': FieldValue.serverTimestamp(),
        });
        return gameType.isNotEmpty;
      }
    });
    // Mirror points (and, on a newly-counted game type, gamesPlayed) to the
    // users collection so the Home screen's badges can read them without a
    // second stream. merge: true so this never throws for a brand-new
    // anonymous visitor whose users/{uid} doc doesn't exist yet — .update()
    // would crash with NOT_FOUND in that case.
    await _db.collection('users').doc(uid).set(
      {
        'points': FieldValue.increment(points),
        if (isNewGame) 'gamesPlayed': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  GAME SESSIONS — lightweight per-play log. Not part of the points
  //  transaction (best-effort, never throws) — powers future per-booth /
  //  per-game analytics (roadmap item 5: most-played game, engagement,
  //  exhibitor-level popularity).
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> logGameSession(
    String uid,
    String gameType,
    int points, {
    String? exhibitorId,
    int? durationMs,
  }) async {
    try {
      await _db.collection('game_sessions').add({
        'uid': uid,
        'gameType': gameType,
        'points': points,
        if (exhibitorId != null) 'exhibitorId': exhibitorId,
        // How long this one play actually took, wall-clock, from the
        // moment the game started to the moment it ended — powers "My
        // Stats"' total engagement time and is otherwise informational.
        // Null for game types with no meaningful play duration (e.g.
        // Lucky Draw, an instant admin-triggered draw).
        if (durationMs != null) 'durationMs': durationMs,
        'playedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical — never block score submission on analytics logging.
    }
  }

  /// Raw per-booth session log — powers the Exhibitor Analytics screen
  /// (total participants, game popularity, daily trend). Aggregated
  /// client-side by the caller, same trade-off already made by
  /// getExhibitorLeaderboard() above (no server-side group-by at
  /// prototype scale).
  Stream<List<Map<String, dynamic>>> getBoothSessions(String boothId) {
    return _db
        .collection('game_sessions')
        .where('exhibitorId', isEqualTo: boothId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// A visitor's own points-earning history (newest first) — powers the
  /// Points History screen linked from Home. Bounded to the most recent
  /// 200 entries; fine at prototype scale.
  Stream<List<Map<String, dynamic>>> getPointsHistory(String uid) {
    return _db
        .collection('game_sessions')
        .where('uid', isEqualTo: uid)
        .orderBy('playedAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
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

  /// Check into a booth — earns +1 shared bonus game-attempt at THIS booth
  /// if first time (see canPlayGame/recordGamePlay below; this used to
  /// grant a global +1 Puzzle attempt before Puzzle moved onto the same
  /// per-booth limiter as the other 5 generic games).
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
    await _db.collection('game_plays').doc('${uid}_$boothId').set(
      {
        'uid': uid,
        'boothId': boothId,
        'bonusRemaining': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    // Track how many distinct booths this visitor has checked into, for the
    // "Booth Hopper" badge on the Home screen. merge: true so this never
    // throws for a brand-new visitor whose users/{uid} doc doesn't exist yet.
    await _db.collection('users').doc(uid).set(
      {'boothsVisited': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    return true; // new check-in
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PER-BOOTH GAME PLAY LIMITER — every visitor gets exactly 1 free play
  //  per generic game (see kGenericBoothGames) at each booth, plus ONE
  //  shared bonus attempt per booth (granted by checkInBooth above, spent
  //  on whichever single one of that booth's games the visitor chooses).
  //  `game_plays/{uid}_{boothId}` holds `plays: {gameType: count}` +
  //  `bonusRemaining` (0 or 1). Never trust the UI-only check
  //  (canPlayGame) for the real decision — recordGamePlay's transaction is
  //  what actually prevents a double-tap/two-tabs race from spending the
  //  single shared bonus twice or granting more than 2 plays of one game.
  // ═══════════════════════════════════════════════════════════════════════

  DocumentReference<Map<String, dynamic>> _gamePlayRef(
          String uid, String boothId) =>
      _db.collection('game_plays').doc('${uid}_$boothId');

  /// Read-only check for the booth screen's UI (grey out / label a game
  /// tile) — NOT the security boundary. Returns how many more times
  /// [gameType] can be played at [boothId] right now: 0 (locked), or more.
  Future<int> remainingPlays(String uid, String boothId, String gameType) async {
    final snap = await _gamePlayRef(uid, boothId).get();
    if (!snap.exists) return 1; // free play, never touched this booth
    final data = snap.data()!;
    final plays = Map<String, dynamic>.from(data['plays'] ?? {});
    final playCount = (plays[gameType] as num?)?.toInt() ?? 0;
    final bonusRemaining = (data['bonusRemaining'] as num?)?.toInt() ?? 0;
    if (playCount == 0) return 1; // free play still available
    if (playCount == 1 && bonusRemaining > 0) return 1; // bonus spendable here
    return 0; // this game is fully used up at this booth
  }

  /// Atomically validates AND consumes one play of [gameType] at [boothId]
  /// for [uid] — call this right before awarding points (see
  /// game_common.submitGameScore), never only at "Play" tap time. Returns
  /// true if the play was allowed and recorded, false if the visitor has
  /// no free play or bonus left for this game at this booth.
  Future<bool> recordGamePlay(
      String uid, String boothId, String gameType) async {
    final ref = _gamePlayRef(uid, boothId);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final plays = Map<String, dynamic>.from(data['plays'] ?? {});
      final playCount = (plays[gameType] as num?)?.toInt() ?? 0;
      final bonusRemaining = (data['bonusRemaining'] as num?)?.toInt() ?? 0;

      bool spendBonus = false;
      if (playCount == 0) {
        // using the free play — nothing else to check
      } else if (playCount == 1 && bonusRemaining > 0) {
        spendBonus = true;
      } else {
        return false; // no free play or bonus left for this game here
      }

      plays[gameType] = playCount + 1;
      tx.set(
        ref,
        {
          'uid': uid,
          'boothId': boothId,
          'plays': plays,
          if (spendBonus) 'bonusRemaining': bonusRemaining - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  VISITOR PROFILE (display name, avatar, daily streak) — powers the
  //  gamified Home screen. Visitors never fill in a form for any of this;
  //  it's set from the profile editor / avatar picker on Home.
  // ═══════════════════════════════════════════════════════════════════════

  /// Live view of `users/{uid}` — displayName, avatarEmoji, loginStreak, etc.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateVisitorProfile(
    String uid, {
    String? displayName,
    String? avatarEmoji,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null && displayName.isNotEmpty) {
      data['displayName'] = displayName;
    }
    if (avatarEmoji != null && avatarEmoji.isNotEmpty) {
      data['avatarEmoji'] = avatarEmoji;
    }
    if (data.isEmpty) return;

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    // Keep the leaderboard's copy of the name in sync too.
    if (displayName != null && displayName.isNotEmpty) {
      await _db
          .collection('leaderboard')
          .doc(uid)
          .set({'displayName': displayName}, SetOptions(merge: true));
    }
  }

  /// Call once per app open. Bumps the streak by 1 if the visitor's last
  /// recorded visit was exactly yesterday, resets to 1 if it's been longer
  /// (or this is their first visit), and leaves it untouched if they've
  /// already been counted today.
  Future<DailyVisitResult> registerDailyVisit(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final todayKey = _dateKey(DateTime.now());
    final lastKey = data['lastVisitDate'] as String?;
    final currentStreak = (data['loginStreak'] as num?)?.toInt() ?? 0;

    if (lastKey == todayKey) {
      return DailyVisitResult(
          streak: currentStreak == 0 ? 1 : currentStreak, isNewDay: false);
    }

    final newStreak =
        (lastKey != null && _isConsecutiveDay(lastKey, todayKey))
            ? currentStreak + 1
            : 1;
    await ref.set(
        {'loginStreak': newStreak, 'lastVisitDate': todayKey},
        SetOptions(merge: true));
    return DailyVisitResult(streak: newStreak, isNewDay: true);
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool _isConsecutiveDay(String lastKey, String todayKey) {
    try {
      final last = DateTime.parse(lastKey);
      final today = DateTime.parse(todayKey);
      return today.difference(last).inDays == 1;
    } catch (_) {
      return false;
    }
  }

  /// Single leaderboard entry for one visitor (not the top-N list).
  Future<LeaderboardEntry?> getLeaderboardEntry(String uid) async {
    final doc = await _db.collection('leaderboard').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return LeaderboardEntry.fromMap(doc.id, doc.data()!);
  }

  /// Best-effort rank among the top 100 by points. Returns null if the
  /// visitor isn't in that range yet (prototype-scale lookup, not a
  /// server-side ranked query).
  Future<int?> getUserRank(String uid) async {
    final snap = await _db
        .collection('leaderboard')
        .orderBy('totalPoints', descending: true)
        .limit(100)
        .get();
    final index = snap.docs.indexWhere((d) => d.id == uid);
    return index == -1 ? null : index + 1;
  }

  /// Per-game leaderboard: ranks visitors by their points in ONE game type
  /// (e.g. 'quiz', 'puzzle', 'reflex_tap') rather than their overall total.
  /// Firestore's orderBy on a dotted map path only returns docs that HAVE
  /// that field, so visitors who never played this game are naturally
  /// excluded rather than showing up with a false "0".
  Stream<List<LeaderboardEntry>> getLeaderboardByGame(String gameType) {
    return _db
        .collection('leaderboard')
        .orderBy('gameBreakdown.$gameType', descending: true)
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

  /// Per-exhibitor (booth) leaderboard: sums each visitor's points from
  /// `game_sessions` logged at this booth. Firestore has no server-side
  /// group-by/sum-by-key, so this aggregates client-side — fine at
  /// prototype scale (one booth's session log), not meant for huge volumes.
  Stream<List<ExhibitorLeaderboardEntry>> getExhibitorLeaderboard(
      String exhibitorId) {
    return _db
        .collection('game_sessions')
        .where('exhibitorId', isEqualTo: exhibitorId)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <ExhibitorLeaderboardEntry>[];

      final totals = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = data['uid'] as String?;
        if (uid == null) continue;
        final pts = (data['points'] as num?)?.toInt() ?? 0;
        totals[uid] = (totals[uid] ?? 0) + pts;
      }

      final uids = totals.keys.toList();
      // Batch-fetch display names (whereIn caps at 30 ids per query).
      final names = <String, String>{};
      for (var i = 0; i < uids.length; i += 30) {
        final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
        final usersSnap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in usersSnap.docs) {
          names[d.id] = (d.data()['displayName'] as String?) ?? 'Player';
        }
      }

      final rows = totals.entries
          .map((e) => ExhibitorLeaderboardEntry(
                uid: e.key,
                displayName: names[e.key] ?? 'Player',
                points: e.value,
              ))
          .toList()
        ..sort((a, b) => b.points.compareTo(a.points));

      int rank = 1;
      return rows.take(50).map((e) => e.withRank(rank++)).toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  REWARDS (E-VOUCHERS) — the Points Shop catalogue. Entirely
  //  Firestore-driven (`rewards/{id}`) so a Super Admin can add/retire
  //  brands and vouchers without a code change (requirement: catalogue
  //  must not require code changes to extend).
  // ═══════════════════════════════════════════════════════════════════════

  /// What the Shop screen shows a visitor — active rewards only.
  Stream<List<RewardModel>> getActiveRewards() {
    return _db
        .collection('rewards')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RewardModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.brandName.compareTo(b.brandName)));
  }

  /// Every reward regardless of active state — Super Admin's Manage
  /// Rewards / Manage Inventory screens.
  Stream<List<RewardModel>> getAllRewardsAdmin() {
    return _db.collection('rewards').snapshots().map((snap) => snap.docs
        .map((d) => RewardModel.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.brandName.compareTo(b.brandName)));
  }

  Future<String> addReward(RewardModel reward) async {
    final ref = await _db.collection('rewards').add({
      ...reward.toCreateMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Edits reward metadata (name/brand/description/value/points/category/
  /// active/images) — deliberately never touches `stock`. See
  /// RewardModel.toUpdateMap for why, and adjustStock()/redeemReward() for
  /// the only two paths allowed to change inventory.
  Future<void> updateReward(RewardModel reward) async {
    await _db.collection('rewards').doc(reward.id).update({
      ...reward.toUpdateMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRewardActive(String rewardId, bool isActive) async {
    await _db.collection('rewards').doc(rewardId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReward(String rewardId) async {
    await _db.collection('rewards').doc(rewardId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  REDEMPTION — the one operation in this whole feature that MUST be
  //  atomic. All five checks/writes happen inside a single Firestore
  //  transaction: if any check fails, NOTHING is written (Firestore
  //  transactions are all-or-nothing and serialized server-side, which is
  //  what actually prevents the "last voucher, two users" race — not the
  //  order operations appear in this function). Never stores a voucher
  //  code/PIN — this is a demo fulfillment flow (see RedemptionStatus).
  // ═══════════════════════════════════════════════════════════════════════

  /// Redeems [rewardId] for [uid]. Returns a [RedemptionOutcome] describing
  /// success (with the new redemption's id) or exactly which check failed,
  /// so the UI can show a precise message instead of a generic error.
  Future<RedemptionOutcome> redeemReward({
    required String uid,
    required String rewardId,
    required String deliveryEmail,
    String? accountEmail,
  }) async {
    final rewardRef = _db.collection('rewards').doc(rewardId);
    final userRef = _db.collection('users').doc(uid);
    final redemptionRef = _db.collection('redemptions').doc();

    return _db.runTransaction<RedemptionOutcome>((tx) async {
      // ── reads (must all happen before any write in a transaction) ──────
      final rewardSnap = await tx.get(rewardRef);
      final userSnap = await tx.get(userRef);

      if (!rewardSnap.exists) {
        return const RedemptionOutcome.failure('not_found');
      }
      final reward = RewardModel.fromMap(rewardRef.id, rewardSnap.data()!);
      if (!reward.isActive) {
        return const RedemptionOutcome.failure('inactive');
      }
      if (reward.stock <= 0) {
        return const RedemptionOutcome.failure('out_of_stock');
      }
      final userData = userSnap.data() ?? {};
      final points = (userData['points'] as num?)?.toInt() ?? 0;
      if (points < reward.pointsRequired) {
        return const RedemptionOutcome.failure('insufficient_points');
      }

      // ── writes ──────────────────────────────────────────────────────────
      tx.update(rewardRef, {
        'stock': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        userRef,
        {'points': FieldValue.increment(-reward.pointsRequired)},
        SetOptions(merge: true),
      );
      tx.set(redemptionRef, {
        'userId': uid,
        if (accountEmail != null && accountEmail.isNotEmpty)
          'accountEmail': accountEmail,
        'rewardId': rewardId,
        'rewardName': reward.name,
        'brandName': reward.brandName,
        'voucherValue': reward.voucherValue,
        'pointsSpent': reward.pointsRequired,
        'deliveryEmail': deliveryEmail,
        'status': RedemptionStatus.pendingDelivery,
        'refunded': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return RedemptionOutcome.success(redemptionRef.id);
    });
  }

  /// A visitor's own redemption history, newest first.
  Stream<List<RedemptionModel>> getUserRedemptions(String uid) {
    return _db
        .collection('redemptions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RedemptionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Every redemption in the system, newest first — Super Admin's Manage
  /// Redemptions screen does its user/email/reward/brand/status/date
  /// filtering client-side over this (prototype scale; same pattern
  /// already used for the per-booth leaderboard aggregation).
  Stream<List<RedemptionModel>> getAllRedemptions() {
    return _db
        .collection('redemptions')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RedemptionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Plain status change (no point/stock movement) — normal fulfillment
  /// progression, e.g. Pending Delivery → Processing → Delivered.
  Future<void> updateRedemptionStatus(
      String redemptionId, String newStatus) async {
    await _db.collection('redemptions').doc(redemptionId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancels a redemption AND refunds its points, atomically, restoring the
  /// voucher's stock by 1 so it can be redeemed again. Guarded by the
  /// redemption's own `refunded` flag — set once, checked every time — so
  /// the exact same redemption can never be refunded twice, no matter how
  /// many times a Super Admin taps the button or how the request races.
  Future<RedemptionOutcome> cancelAndRefundRedemption(
      String redemptionId) async {
    final redemptionRef = _db.collection('redemptions').doc(redemptionId);

    return _db.runTransaction<RedemptionOutcome>((tx) async {
      final redemptionSnap = await tx.get(redemptionRef);
      if (!redemptionSnap.exists) {
        return const RedemptionOutcome.failure('not_found');
      }
      final redemption =
          RedemptionModel.fromMap(redemptionRef.id, redemptionSnap.data()!);
      if (redemption.refunded) {
        return const RedemptionOutcome.failure('already_refunded');
      }

      final userRef = _db.collection('users').doc(redemption.userId);
      final rewardRef = _db.collection('rewards').doc(redemption.rewardId);
      final userSnap = await tx.get(userRef);
      final rewardSnap = await tx.get(rewardRef);

      tx.update(redemptionRef, {
        'status': RedemptionStatus.refunded,
        'refunded': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (userSnap.exists) {
        tx.set(
          userRef,
          {'points': FieldValue.increment(redemption.pointsSpent)},
          SetOptions(merge: true),
        );
      }
      // Restock only if the reward still exists (it may have since been
      // deleted) — refunding points must never fail because of that.
      if (rewardSnap.exists) {
        tx.update(rewardRef, {
          'stock': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return const RedemptionOutcome.success(null);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  INVENTORY — Super Admin stock adjustments, always logged for an audit
  //  trail (requirement: "Super Admin inventory adjustments should also
  //  generate an inventory log"). This is the ONLY path (besides
  //  redeemReward()'s automatic -1) that may change `reward.stock`.
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> adjustStock({
    required String rewardId,
    required int delta,
    required String reason,
    required String changedByUid,
    required String changedByLabel,
  }) async {
    final rewardRef = _db.collection('rewards').doc(rewardId);
    final logRef = _db.collection('inventory_logs').doc();

    await _db.runTransaction<void>((tx) async {
      final snap = await tx.get(rewardRef);
      if (!snap.exists) return;
      final reward = RewardModel.fromMap(rewardRef.id, snap.data()!);
      final newStock = (reward.stock + delta).clamp(0, 1 << 31).toInt();

      tx.update(rewardRef, {
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(logRef, {
        'rewardId': rewardId,
        'rewardName': reward.name,
        'previousStock': reward.stock,
        'adjustment': newStock - reward.stock,
        'newStock': newStock,
        'reason': reason,
        'changedByUid': changedByUid,
        'changedByLabel': changedByLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<InventoryLogModel>> getInventoryLogs({String? rewardId}) {
    Query<Map<String, dynamic>> q = _db.collection('inventory_logs');
    if (rewardId != null) q = q.where('rewardId', isEqualTo: rewardId);
    return q
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => InventoryLogModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  REWARDS CONFIG — currently just the low-stock threshold, kept
  //  configurable (not hardcoded) per requirement 13.
  // ═══════════════════════════════════════════════════════════════════════

  static const int defaultLowStockThreshold = 10;

  Stream<int> getLowStockThreshold() {
    return _db
        .collection('app_config')
        .doc('rewards')
        .snapshots()
        .map((doc) =>
            (doc.data()?['lowStockThreshold'] as num?)?.toInt() ??
            defaultLowStockThreshold);
  }

  Future<void> setLowStockThreshold(int threshold) async {
    await _db.collection('app_config').doc('rewards').set(
      {'lowStockThreshold': threshold},
      SetOptions(merge: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  USER MANAGEMENT (Super Admin) — points adjustments, ban/unban, and
  //  role changes on OTHER users' accounts. The client call below is only
  //  half the story: firestore.rules is what actually stops a normal user
  //  from calling these same writes on themselves or anyone else — see
  //  that file's comments for the exact constraints enforced server-side.
  // ═══════════════════════════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> getAllUsersAdmin() {
    return _db.collection('users').snapshots().map((snap) =>
        snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  /// Adds (positive) or removes (negative) points from a user's balance as
  /// a deliberate Super Admin action — distinct from a visitor earning
  /// points by playing, and from redeemReward()'s automatic deduction.
  Future<void> adminAdjustUserPoints(String uid, int delta) async {
    await _db.collection('users').doc(uid).set(
      {'points': FieldValue.increment(delta)},
      SetOptions(merge: true),
    );
  }

  Future<void> setUserStatus(String uid, String status) async {
    await _db.collection('users').doc(uid).set(
      {'accountStatus': status},
      SetOptions(merge: true),
    );
  }

  /// Changes another user's role. Treated as highly privileged: the client
  /// gate is AuthService.isSuperAdmin, but firestore.rules is what actually
  /// blocks a normal user from ever writing their own or anyone else's
  /// `role` field — see that file.
  ///
  /// Promoting someone to 'super_admin' also wipes their points and removes
  /// them from the leaderboard, atomically in the same batch. addPoints()
  /// already blocks a super_admin from ever earning *new* points — this is
  /// the matching one-time cleanup for points they may have already earned
  /// as a visitor before the promotion, so "exhibitors and super admins
  /// never have points or appear on the leaderboard" holds from the moment
  /// they're promoted, not just going forward. Demoting away from
  /// super_admin does not restore anything — they simply start earning
  /// again as a visitor from 0.
  Future<void> setUserRole(String uid, String role) async {
    if (role == 'super_admin') {
      final batch = _db.batch();
      batch.set(
        _db.collection('users').doc(uid),
        {'role': role, 'points': 0},
        SetOptions(merge: true),
      );
      batch.delete(_db.collection('leaderboard').doc(uid));
      await batch.commit();
      return;
    }
    await _db.collection('users').doc(uid).set(
      {'role': role},
      SetOptions(merge: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EXHIBITOR BOOTH STATS — one-shot aggregate reads for the Exhibitor
  //  Dashboard. Client-side counting over bounded queries; fine at
  //  prototype/single-exhibition scale, same trade-off already made for the
  //  per-booth leaderboard elsewhere in this file.
  // ═══════════════════════════════════════════════════════════════════════
  Future<Map<String, int>> getBoothStats(String boothId) async {
    final checkIns = await _db
        .collection('booth_checkins')
        .where('boothId', isEqualTo: boothId)
        .get();
    final plays = await _db
        .collection('game_plays')
        .where('boothId', isEqualTo: boothId)
        .get();
    var totalPlays = 0;
    for (final doc in plays.docs) {
      final map = Map<String, dynamic>.from(doc.data()['plays'] ?? {});
      for (final v in map.values) {
        totalPlays += (v as num?)?.toInt() ?? 0;
      }
    }
    final sessions = await _db
        .collection('game_sessions')
        .where('exhibitorId', isEqualTo: boothId)
        .get();
    var pointsDistributed = 0;
    for (final doc in sessions.docs) {
      pointsDistributed += (doc.data()['points'] as num?)?.toInt() ?? 0;
    }
    return {
      'checkIns': checkIns.docs.length,
      'totalPlays': totalPlays,
      'pointsDistributed': pointsDistributed,
    };
  }
}

/// Result of a redemption attempt — [success] is null-safe to check first;
/// [redemptionId] is only set on success, [failureReason] only on failure.
class RedemptionOutcome {
  final bool success;
  final String? redemptionId;
  final String? failureReason;

  const RedemptionOutcome.success(this.redemptionId)
      : success = true,
        failureReason = null;
  const RedemptionOutcome.failure(this.failureReason)
      : success = false,
        redemptionId = null;
}

/// Result of [FirestoreService.registerDailyVisit].
class DailyVisitResult {
  final int streak;
  final bool isNewDay;
  const DailyVisitResult({required this.streak, required this.isNewDay});
}
