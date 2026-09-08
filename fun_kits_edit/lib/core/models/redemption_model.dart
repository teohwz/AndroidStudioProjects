// ─── REDEMPTION MODEL ────────────────────────────────────────────────────
// One record of a visitor spending points on a reward. Never stores an
// actual voucher code/PIN — this is a demo fulfillment flow (see
// FirestoreService.redeemReward) — a redemption starts life as
// 'pending_delivery' and a Super Admin advances it manually for now.

/// Machine-readable statuses (stored in Firestore). Keep in sync with
/// [redemptionStatusLabel] below whenever a new status is added.
class RedemptionStatus {
  static const pendingDelivery = 'pending_delivery';
  static const processing = 'processing';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';
  static const refunded = 'refunded';

  static const all = [
    pendingDelivery,
    processing,
    delivered,
    cancelled,
    refunded,
  ];
}

String redemptionStatusLabel(String status) {
  switch (status) {
    case RedemptionStatus.pendingDelivery:
      return 'Pending Delivery';
    case RedemptionStatus.processing:
      return 'Processing';
    case RedemptionStatus.delivered:
      return 'Delivered';
    case RedemptionStatus.cancelled:
      return 'Cancelled';
    case RedemptionStatus.refunded:
      return 'Refunded';
    default:
      return status;
  }
}

class RedemptionModel {
  final String id;
  final String userId;
  // The account email at the time of redemption (null for a visitor who
  // hasn't linked an email yet — see save_progress_screen.dart). Distinct
  // from [deliveryEmail], which is where the voucher is meant to go and can
  // be any address the visitor types in (e.g. redeeming for someone else).
  final String? accountEmail;
  final String rewardId;
  final String rewardName;
  final String brandName;
  final num voucherValue;
  final int pointsSpent;
  final String deliveryEmail;
  final String status;
  final bool refunded; // guards against a double refund on cancel
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RedemptionModel({
    required this.id,
    required this.userId,
    this.accountEmail,
    required this.rewardId,
    required this.rewardName,
    required this.brandName,
    required this.voucherValue,
    required this.pointsSpent,
    required this.deliveryEmail,
    this.status = RedemptionStatus.pendingDelivery,
    this.refunded = false,
    this.createdAt,
    this.updatedAt,
  });

  String get statusLabel => redemptionStatusLabel(status);

  factory RedemptionModel.fromMap(String id, Map<String, dynamic> map) {
    return RedemptionModel(
      id: id,
      userId: map['userId'] ?? '',
      accountEmail: map['accountEmail'] as String?,
      rewardId: map['rewardId'] ?? '',
      rewardName: map['rewardName'] ?? '',
      brandName: map['brandName'] ?? '',
      voucherValue: (map['voucherValue'] as num?) ?? 0,
      pointsSpent: (map['pointsSpent'] as num?)?.toInt() ?? 0,
      deliveryEmail: map['deliveryEmail'] ?? '',
      status: map['status'] ?? RedemptionStatus.pendingDelivery,
      refunded: map['refunded'] ?? false,
      createdAt: (map['createdAt'] as dynamic)?.toDate(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate(),
    );
  }
}
