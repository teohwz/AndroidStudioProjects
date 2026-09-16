// ─── GAME CONTENT MODELS ───────────────────────────────────────────────────
// Exhibitor-authored customization content for the "wow" mini-games (Spin
// Wheel, Scratch Card, Guess the Number, Memory Cards). Each booth's content
// for a given game lives in a single Firestore doc at
// `game_content/{boothId}_{gameType}` — one doc per booth per game, holding
// whatever fields that game needs. This mirrors the `game_plays/{uid}_{boothId}`
// doc-id convention already used for the per-booth play limiter.

/// One prize option in a Spin Wheel or Scratch Card prize pool.
///
/// A segment is independently either a flat points award (`type == 'points'`,
/// unlimited — every win of this segment pays out [pointsValue]) or a
/// limited-stock physical prize (`type == 'physical'`, capped at [stock] —
/// once [remainingStock] hits 0 the segment is excluded from future draws).
/// [weight] is the segment's relative probability weight; weights don't need
/// to sum to any particular total, they're normalized at draw time against
/// the currently-available segments only.
class PrizeSegment {
  final String id;
  final String label; // shown on the wheel / scratch card, e.g. "50 Points" or "Free T-Shirt"
  final String type; // 'points' | 'physical'
  final int pointsValue; // used when type == 'points'
  final int stock; // total stock set by the exhibitor, used when type == 'physical'
  final int remainingStock; // decremented on each win; when 0 the segment is drawn no more
  final double weight; // relative probability weight (> 0)
  final String colorHex; // optional per-segment wheel color, e.g. '#FF6B6B' ('' = auto-assigned)

  const PrizeSegment({
    required this.id,
    required this.label,
    required this.type,
    this.pointsValue = 0,
    this.stock = 0,
    this.remainingStock = 0,
    this.weight = 1,
    this.colorHex = '',
  });

  bool get isPoints => type == 'points';
  bool get isPhysical => type == 'physical';

  /// Whether this segment can still be won — points segments are always
  /// available, physical segments only while stock remains.
  bool get isAvailable => isPoints || remainingStock > 0;

  factory PrizeSegment.fromMap(Map<String, dynamic> map) => PrizeSegment(
        id: map['id'] ?? '',
        label: map['label'] ?? '',
        type: map['type'] ?? 'points',
        pointsValue: map['pointsValue'] ?? 0,
        stock: map['stock'] ?? 0,
        remainingStock: map['remainingStock'] ?? map['stock'] ?? 0,
        weight: (map['weight'] ?? 1).toDouble(),
        colorHex: map['colorHex'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'type': type,
        'pointsValue': pointsValue,
        'stock': stock,
        'remainingStock': remainingStock,
        'weight': weight,
        'colorHex': colorHex,
      };

  PrizeSegment copyWith({
    String? label,
    String? type,
    int? pointsValue,
    int? stock,
    int? remainingStock,
    double? weight,
    String? colorHex,
  }) =>
      PrizeSegment(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
        pointsValue: pointsValue ?? this.pointsValue,
        stock: stock ?? this.stock,
        remainingStock: remainingStock ?? this.remainingStock,
        weight: weight ?? this.weight,
        colorHex: colorHex ?? this.colorHex,
      );
}

/// Exhibitor-configured Spin Wheel content for one booth.
class SpinWheelConfig {
  final String boothId;
  final List<PrizeSegment> segments;
  final DateTime? updatedAt;

  const SpinWheelConfig({
    required this.boothId,
    this.segments = const [],
    this.updatedAt,
  });

  bool get hasContent => segments.isNotEmpty;
  bool get hasAvailablePrize => segments.any((s) => s.isAvailable);

  factory SpinWheelConfig.fromMap(String boothId, Map<String, dynamic> map) =>
      SpinWheelConfig(
        boothId: boothId,
        segments: (map['segments'] as List<dynamic>? ?? [])
            .map((s) => PrizeSegment.fromMap(Map<String, dynamic>.from(s)))
            .toList(),
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'gameType': 'spin_wheel',
        'boothId': boothId,
        'segments': segments.map((s) => s.toMap()).toList(),
        'updatedAt': updatedAt,
      };
}

/// Exhibitor-configured Scratch Card content for one booth. Uses the same
/// weighted prize-mix model as [SpinWheelConfig].
class ScratchCardConfig {
  final String boothId;
  final String cardImageUrl; // the image revealed underneath the scratch layer
  final String revealMessage; // shown alongside the prize once scratched off
  final List<PrizeSegment> segments;
  final DateTime? updatedAt;

  const ScratchCardConfig({
    required this.boothId,
    this.cardImageUrl = '',
    this.revealMessage = 'You won!',
    this.segments = const [],
    this.updatedAt,
  });

  bool get hasContent => segments.isNotEmpty;
  bool get hasAvailablePrize => segments.any((s) => s.isAvailable);
  bool get hasImage => cardImageUrl.isNotEmpty;

  factory ScratchCardConfig.fromMap(
          String boothId, Map<String, dynamic> map) =>
      ScratchCardConfig(
        boothId: boothId,
        cardImageUrl: map['cardImageUrl'] ?? '',
        revealMessage: map['revealMessage'] ?? 'You won!',
        segments: (map['segments'] as List<dynamic>? ?? [])
            .map((s) => PrizeSegment.fromMap(Map<String, dynamic>.from(s)))
            .toList(),
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'gameType': 'scratch_card',
        'boothId': boothId,
        'cardImageUrl': cardImageUrl,
        'revealMessage': revealMessage,
        'segments': segments.map((s) => s.toMap()).toList(),
        'updatedAt': updatedAt,
      };
}

/// Exhibitor-configured Guess the Number content for one booth.
///
/// [currentSecret] is the ONE shared answer every visitor at this booth is
/// currently trying to guess (null only if it hasn't been generated yet,
/// which saveGuessNumberConfig always fixes on save). It's whatever the
/// exhibitor last set it to, or the last auto-rolled value after a visitor
/// solved it — see FirestoreService.rerollGuessNumberSecret. A visitor's own
/// in-progress round snapshots this value once at Start, so it never shifts
/// under them mid-round even if someone else solves it or the exhibitor
/// edits it in the meantime.
class GuessNumberConfig {
  final String boothId;
  final int minValue;
  final int maxValue;
  final int rewardPoints;
  final String hint; // optional, exhibitor-written, revealable any time
  final int? currentSecret;
  final DateTime? updatedAt;

  const GuessNumberConfig({
    required this.boothId,
    this.minValue = 1,
    this.maxValue = 100,
    this.rewardPoints = 50,
    this.hint = '',
    this.currentSecret,
    this.updatedAt,
  });

  bool get hasContent => maxValue > minValue;
  bool get hasHint => hint.isNotEmpty;
  static const int maxAttempts = 10;

  factory GuessNumberConfig.fromMap(
          String boothId, Map<String, dynamic> map) =>
      GuessNumberConfig(
        boothId: boothId,
        minValue: map['minValue'] ?? 1,
        maxValue: map['maxValue'] ?? 100,
        rewardPoints: map['rewardPoints'] ?? 50,
        hint: map['hint'] ?? '',
        currentSecret: map['currentSecret'] as int?,
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'gameType': 'guess_number',
        'boothId': boothId,
        'minValue': minValue,
        'maxValue': maxValue,
        'rewardPoints': rewardPoints,
        'hint': hint,
        'currentSecret': currentSecret,
        'updatedAt': updatedAt,
      };

  GuessNumberConfig copyWith({int? currentSecret}) => GuessNumberConfig(
        boothId: boothId,
        minValue: minValue,
        maxValue: maxValue,
        rewardPoints: rewardPoints,
        hint: hint,
        currentSecret: currentSecret ?? this.currentSecret,
        updatedAt: updatedAt,
      );
}

/// Exhibitor-configured Code Breaker content for one booth — just the one
/// shared secret code every visitor is currently trying to crack (4 unique
/// digits 0-9), same "one shared answer, auto-rerolled on solve, exhibitor
/// can view or override any time" model as [GuessNumberConfig]. Unlike Guess
/// the Number, Code Breaker has no other exhibitor-set options (no range, no
/// hint) — this doc exists purely to hold the shared secret, and is seeded
/// automatically with a random code the first time the exhibitor opens
/// Game Settings or the Code Breaker customize screen (see
/// FirestoreService.ensureCodeBreakerSeeded), so booths that already had
/// Code Breaker turned on keep working with no action needed.
class CodeBreakerConfig {
  final String boothId;
  final List<int> currentSecret; // 4 unique digits 0-9
  final DateTime? updatedAt;

  const CodeBreakerConfig({
    required this.boothId,
    this.currentSecret = const [],
    this.updatedAt,
  });

  bool get hasContent => currentSecret.length == 4;

  factory CodeBreakerConfig.fromMap(
          String boothId, Map<String, dynamic> map) =>
      CodeBreakerConfig(
        boothId: boothId,
        currentSecret: List<int>.from(map['currentSecret'] ?? const []),
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'gameType': 'code_breaker',
        'boothId': boothId,
        'currentSecret': currentSecret,
        'updatedAt': updatedAt,
      };

  CodeBreakerConfig copyWith({List<int>? currentSecret}) => CodeBreakerConfig(
        boothId: boothId,
        currentSecret: currentSecret ?? this.currentSecret,
        updatedAt: updatedAt,
      );
}

/// Exhibitor-uploaded pair images for the (reworked) Memory Matrix
/// flip-and-match game. Points reward stays on the existing
/// `BoothGameConfig` (enabled/points) — this doc only holds the images.
class MemoryPairsConfig {
  final String boothId;
  final List<String> pairImageUrls; // one URL per distinct pair (4, 6, or 8 entries)
  final DateTime? updatedAt;

  const MemoryPairsConfig({
    required this.boothId,
    this.pairImageUrls = const [],
    this.updatedAt,
  });

  /// Whether the exhibitor has uploaded enough images for a valid board
  /// (4, 6, or 8 pairs).
  bool get hasContent =>
      pairImageUrls.length == 4 ||
      pairImageUrls.length == 6 ||
      pairImageUrls.length == 8;

  int get pairCount => pairImageUrls.length;

  factory MemoryPairsConfig.fromMap(
          String boothId, Map<String, dynamic> map) =>
      MemoryPairsConfig(
        boothId: boothId,
        pairImageUrls: List<String>.from(map['pairImageUrls'] ?? []),
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'gameType': 'memory_matrix',
        'boothId': boothId,
        'pairImageUrls': pairImageUrls,
        'updatedAt': updatedAt,
      };
}

/// A logged prize win. Historically ALWAYS physical (Spin Wheel/Scratch
/// Card points-type wins are paid out immediately via addPoints() and were
/// never logged here at all — only physical prizes need a "collected"
/// checklist), so [prizeType] defaults to 'physical' for any pre-existing
/// doc that predates this field. Lucky Draw is the one exception: it now
/// logs BOTH points and physical wins here (see
/// FirestoreService.recordLuckyDrawPrizeWin) — points ones purely so the
/// winner's claim is idempotent and the exhibitor's admin card can show who
/// won, with `collected` auto-true (nothing to hand out) and [isPointsPrize]
/// used to keep them off the physical hand-out checklist (see
/// ExhibitorPrizeWinsScreen). Also powers the shared "Recent Winners" list
/// on the Lucky Draw/Spin Wheel/Scratch Card screens (see
/// FirestoreService.getRecentPrizeWins).
///
/// [redemptionCode] is the short code the winning visitor shows (as a QR or
/// as plain digits, see MyPrizesScreen) to prove a physical win is really
/// theirs before an exhibitor marks it collected — see
/// FirestoreService.redeemPrizeCode. Empty for points-type wins (nothing to
/// redeem in person) and for any doc that predates this field.
class PrizeWinModel {
  final String id;
  final String uid;
  final String userName;
  final String boothId;
  final String gameType; // 'spin_wheel' | 'scratch_card' | 'lucky_draw'
  final String prizeLabel;
  final String prizeType; // 'points' | 'physical'
  final bool collected;
  final String redemptionCode;
  final DateTime? createdAt;

  const PrizeWinModel({
    required this.id,
    required this.uid,
    required this.userName,
    required this.boothId,
    required this.gameType,
    required this.prizeLabel,
    this.prizeType = 'physical',
    this.collected = false,
    this.redemptionCode = '',
    this.createdAt,
  });

  bool get isPointsPrize => prizeType == 'points';

  factory PrizeWinModel.fromMap(String id, Map<String, dynamic> map) =>
      PrizeWinModel(
        id: id,
        uid: map['uid'] ?? '',
        userName: map['userName'] ?? 'Player',
        boothId: map['boothId'] ?? '',
        gameType: map['gameType'] ?? '',
        prizeLabel: map['prizeLabel'] ?? '',
        prizeType: map['prizeType'] ?? 'physical',
        collected: map['collected'] ?? false,
        redemptionCode: map['redemptionCode'] ?? '',
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'boothId': boothId,
        'gameType': gameType,
        'prizeLabel': prizeLabel,
        'prizeType': prizeType,
        'collected': collected,
        'redemptionCode': redemptionCode,
        'createdAt': createdAt,
      };
}
