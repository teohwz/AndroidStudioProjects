// ─── LUCKY DRAW MODEL ────────────────────────────────────────────────────────
class LuckyDrawModel {
  final String id;
  final String title;
  final String exhibitorId;
  final List<String> participants; // list of UIDs
  final String? winnerUid;
  final bool isActive;
  final String prize;
  final DateTime? endsAt; // countdown deadline

  // 'points' | 'physical' — same convention as PrizeSegment (Spin Wheel/
  // Scratch Card). Defaults preserve exactly how every draw behaved before
  // this field existed: a fixed 100-point award, so a pre-existing draw's
  // behavior doesn't change just because it predates this feature.
  final String prizeType;
  final int pointsValue; // used when prizeType == 'points'

  LuckyDrawModel({
    required this.id,
    required this.title,
    required this.exhibitorId,
    this.participants = const [],
    this.winnerUid,
    this.isActive = true,
    this.prize = '',
    this.endsAt,
    this.prizeType = 'points',
    this.pointsValue = 100,
  });

  bool get isPointsPrize => prizeType == 'points';
  bool get isPhysicalPrize => prizeType == 'physical';

  bool get hasEnded =>
      endsAt != null && DateTime.now().isAfter(endsAt!);

  Duration get remaining {
    if (endsAt == null) return Duration.zero;
    final diff = endsAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory LuckyDrawModel.fromMap(String id, Map<String, dynamic> map) =>
      LuckyDrawModel(
        id: id,
        title: map['title'] ?? '',
        exhibitorId: map['exhibitorId'] ?? '',
        participants: List<String>.from(map['participants'] ?? []),
        winnerUid: map['winnerUid'],
        isActive: map['isActive'] ?? true,
        prize: map['prize'] ?? '',
        endsAt: map['endsAt'] != null
            ? (map['endsAt'] as dynamic).toDate()
            : null,
        prizeType: map['prizeType'] ?? 'points',
        pointsValue: map['pointsValue'] ?? 100,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'exhibitorId': exhibitorId,
        'participants': participants,
        'winnerUid': winnerUid,
        'isActive': isActive,
        'prize': prize,
        'endsAt': endsAt,
        'prizeType': prizeType,
        'pointsValue': pointsValue,
      };
}
