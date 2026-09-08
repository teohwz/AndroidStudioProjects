// ─── INVENTORY LOG MODEL ─────────────────────────────────────────────────
// Audit trail entry for every Super Admin stock adjustment (requirement 9 /
// 17). Redemption's automatic -1 deduction does NOT write one of these —
// that's routine sales activity, not an adjustment — keeping this log
// focused on deliberate restocks/corrections a Super Admin makes.
class InventoryLogModel {
  final String id;
  final String rewardId;
  final String rewardName;
  final int previousStock;
  final int adjustment; // signed delta, e.g. +10 or -3
  final int newStock;
  final String reason;
  final String changedByUid;
  final String changedByLabel; // display name/email shown in the log
  final DateTime? createdAt;

  const InventoryLogModel({
    required this.id,
    required this.rewardId,
    required this.rewardName,
    required this.previousStock,
    required this.adjustment,
    required this.newStock,
    required this.reason,
    required this.changedByUid,
    required this.changedByLabel,
    this.createdAt,
  });

  factory InventoryLogModel.fromMap(String id, Map<String, dynamic> map) {
    return InventoryLogModel(
      id: id,
      rewardId: map['rewardId'] ?? '',
      rewardName: map['rewardName'] ?? '',
      previousStock: (map['previousStock'] as num?)?.toInt() ?? 0,
      adjustment: (map['adjustment'] as num?)?.toInt() ?? 0,
      newStock: (map['newStock'] as num?)?.toInt() ?? 0,
      reason: map['reason'] ?? '',
      changedByUid: map['changedByUid'] ?? '',
      changedByLabel: map['changedByLabel'] ?? 'Super Admin',
      createdAt: (map['createdAt'] as dynamic)?.toDate(),
    );
  }
}
