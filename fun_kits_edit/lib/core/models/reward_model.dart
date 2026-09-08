// ─── REWARD (E-VOUCHER) MODEL ───────────────────────────────────────────────
// A reward the Points Shop sells. The catalogue is entirely Firestore-driven
// (`rewards/{rewardId}`) so the Super Admin can add/edit/retire brands and
// vouchers without a code change or app update — see manage_rewards_screen.

/// Low-stock banding for the Super Admin dashboard / shop card. The
/// THRESHOLD itself is configurable (see `RewardsConfig`), not hardcoded —
/// this enum just names the three bands once a threshold is known.
enum StockLevel { normal, low, outOfStock }

class RewardModel {
  final String id;
  final String name;
  final String brandName;
  // Empty string means "no image uploaded yet" — the UI renders a generated
  // placeholder tile (brand initial on a deterministic color) instead of a
  // broken image. Super Admin can upload a real logo/image at any time via
  // the edit form; nothing else in the app needs to change when they do.
  final String brandImageUrl;
  final String rewardImageUrl;
  final String description;
  final num voucherValue; // RM value, e.g. 5 or 10.5
  final int pointsRequired;
  final int stock;
  final String category;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RewardModel({
    required this.id,
    required this.name,
    required this.brandName,
    this.brandImageUrl = '',
    this.rewardImageUrl = '',
    this.description = '',
    required this.voucherValue,
    required this.pointsRequired,
    required this.stock,
    this.category = 'E-Voucher',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOutOfStock => stock <= 0;

  StockLevel stockLevel(int lowStockThreshold) {
    if (stock <= 0) return StockLevel.outOfStock;
    if (stock <= lowStockThreshold) return StockLevel.low;
    return StockLevel.normal;
  }

  factory RewardModel.fromMap(String id, Map<String, dynamic> map) {
    return RewardModel(
      id: id,
      name: map['name'] ?? '',
      brandName: map['brandName'] ?? '',
      brandImageUrl: map['brandImageUrl'] ?? '',
      rewardImageUrl: map['rewardImageUrl'] ?? '',
      description: map['description'] ?? '',
      voucherValue: (map['voucherValue'] as num?) ?? 0,
      pointsRequired: (map['pointsRequired'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      category: map['category'] ?? 'E-Voucher',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as dynamic)?.toDate(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'brandName': brandName,
        'brandImageUrl': brandImageUrl,
        'rewardImageUrl': rewardImageUrl,
        'description': description,
        'voucherValue': voucherValue,
        'pointsRequired': pointsRequired,
        'stock': stock,
        'category': category,
        'isActive': isActive,
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'brandName': brandName,
        'brandImageUrl': brandImageUrl,
        'rewardImageUrl': rewardImageUrl,
        'description': description,
        'voucherValue': voucherValue,
        'pointsRequired': pointsRequired,
        'category': category,
        'isActive': isActive,
        // NOTE: `stock` is deliberately absent here — normal reward edits
        // never touch inventory. Stock only ever changes through
        // FirestoreService.adjustStock() (Super Admin, logged) or
        // redeemReward() (visitor, transaction), never a blanket reward edit.
      };
}
