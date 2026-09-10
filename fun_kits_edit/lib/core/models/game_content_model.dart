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
class GuessNumberConfig {
  final String boothId;
  final int minValue;
  final int maxValue;
  final int rewardPoints;
  final String hint; // optional, exhibitor-written, revealable any time
  final DateTime? updatedAt;

  const GuessNumberConfig({
    required this.boothId,
    this.minValue = 1,
    this.maxValue = 100,
    this.rewardPoints = 50,
    this.hint = '',
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
        'updatedAt': updatedAt,
      };
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

/// A logged physical-prize win, for the exhibitor's in-person hand-out
/// tracking. Points-type wins are paid out immediately via addPoints() and
/// are NOT logged here — only physical prizes need a "collected" checklist.
/// Also powers the shared "Recent Winners" list on the Lucky Draw/Spin
/// Wheel/Scratch Card screens (see FirestoreService.getRecentPrizeWins).
class PrizeWinModel {
  final String id;
  final String uid;
  final String userName;
  final String boothId;
  final String gameType; // 'spin_wheel' | 'scratch_card' | 'lucky_draw'
  final String prizeLabel;
  final bool collected;
  final DateTime? createdAt;

  const PrizeWinModel({
    required this.id,
    required this.uid,
    required this.userName,
    required this.boothId,
    required this.gameType,
    required this.prizeLabel,
    this.collected = false,
    this.createdAt,
  });

  factory PrizeWinModel.fromMap(String id, Map<String, dynamic> map) =>
      PrizeWinModel(
        id: id,
        uid: map['uid'] ?? '',
        userName: map['userName'] ?? 'Player',
        boothId: map['boothId'] ?? '',
        gameType: map['gameType'] ?? '',
        prizeLabel: map['prizeLabel'] ?? '',
        collected: map['collected'] ?? false,
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
        'collected': collected,
        'createdAt': createdAt,
      };
}
