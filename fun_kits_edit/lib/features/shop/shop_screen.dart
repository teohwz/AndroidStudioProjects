import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/brand_styles.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/firestore_service.dart';
import '../../app/routes.dart';

/// Points Shop — a real e-voucher marketplace: visitors spend points earned
/// from games/booths on Malaysian brand e-vouchers. The catalogue is 100%
/// Firestore-driven (see FirestoreService.getActiveRewards) so a Super
/// Admin can add/retire brands without an app update. No physical prizes
/// live here — Lucky Draw remains the only path to a real prize — and no
/// real voucher codes are ever generated or stored (see redeemReward()).
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _fs = FirestoreService();
  bool _busy = false;

  Future<void> _onRedeemTapped(RewardModel reward, int points) async {
    if (reward.isOutOfStock || _busy) return;

    if (points < reward.pointsRequired) {
      final needed = reward.pointsRequired - points;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Not enough points'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You need ${reward.pointsRequired} points.'),
              const SizedBox(height: 4),
              Text('You currently have $points points.'),
              const SizedBox(height: 8),
              Text('You need $needed more points.',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final result = await showDialog<_RedeemDialogResult>(
      context: context,
      builder: (_) => _RedeemConfirmationDialog(
        reward: reward,
        currentPoints: points,
        prefillEmail: (!(user?.isAnonymous ?? true)) ? (user?.email) : null,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    final outcome = await _fs.redeemReward(
      uid: user!.uid,
      rewardId: reward.id,
      deliveryEmail: result.email,
      accountEmail: (!user.isAnonymous) ? user.email : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome.success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RedeemSuccessDialog(
          reward: reward,
          email: result.email,
          redemptionId: outcome.redemptionId!,
        ),
      );
    } else {
      final message = switch (outcome.failureReason) {
        'out_of_stock' =>
          'Sorry — the last one just went to someone else. Try another voucher.',
        'insufficient_points' => 'Not enough points anymore — try refreshing.',
        'inactive' => 'This voucher is no longer available.',
        _ => 'Something went wrong. Please try again.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Points Shop 🛍️',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'My Redemptions',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.redemptionHistory),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _fs.watchUserProfile(uid),
              builder: (context, userSnap) {
                final points =
                    (userSnap.data?.data()?['points'] as num?)?.toInt() ?? 0;

                return StreamBuilder<int>(
                  stream: _fs.getLowStockThreshold(),
                  builder: (context, thresholdSnap) {
                    final threshold = thresholdSnap.data ??
                        FirestoreService.defaultLowStockThreshold;

                    return StreamBuilder<List<RewardModel>>(
                      stream: _fs.getActiveRewards(),
                      builder: (context, rewardsSnap) {
                        if (rewardsSnap.connectionState ==
                                ConnectionState.waiting &&
                            !rewardsSnap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final rewards = rewardsSnap.data ?? [];

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            _PointsBanner(points: points),
                            const SizedBox(height: 14),
                            if (isAnonymous)
                              _SavePointsBanner(
                                onSave: () => Navigator.pushNamed(
                                    context, AppRoutes.saveProgress),
                              ),
                            const SizedBox(height: 20),
                            if (rewards.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    'No vouchers available right now — check back soon!',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: AppColors.textMedium),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: rewards.length,
                                itemBuilder: (_, i) {
                                  final reward = rewards[i];
                                  return _VoucherCard(
                                    reward: reward,
                                    stockLevel: reward.stockLevel(threshold),
                                    busy: _busy,
                                    onRedeem: () =>
                                        _onRedeemTapped(reward, points),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _PointsBanner extends StatelessWidget {
  const _PointsBanner({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$points',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
                const Text('points available',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavePointsBanner extends StatelessWidget {
  const _SavePointsBanner({required this.onSave});
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your points only live on this device.',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Uninstalling the app deletes them for good — add an email to keep them safe.',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save My Points',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Voucher card ────────────────────────────────────────────────────────
class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.reward,
    required this.stockLevel,
    required this.busy,
    required this.onRedeem,
  });

  final RewardModel reward;
  final StockLevel stockLevel;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final style = brandStyleFor(reward.brandName);
    final outOfStock = stockLevel == StockLevel.outOfStock;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero image (reward image, or a brand-colored placeholder) with
          // the brand logo badge overlaid in the corner.
          AspectRatio(
            aspectRatio: 1.4,
            child: Stack(
              children: [
                Positioned.fill(
                  child: reward.rewardImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: reward.rewardImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _placeholderHero(style),
                        )
                      : _placeholderHero(style),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _BrandBadge(brandName: reward.brandName),
                ),
                if (outOfStock)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.45),
                      alignment: Alignment.center,
                      child: const Text('OUT OF STOCK',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text('RM${reward.voucherValue} Voucher',
                    style: const TextStyle(
                        color: AppColors.textMedium, fontSize: 11)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text('${reward.pointsRequired} pts',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    Text(
                      outOfStock ? 'Out of Stock' : '${reward.stock} left',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: outOfStock
                            ? AppColors.danger
                            : stockLevel == StockLevel.low
                                ? AppColors.warning
                                : AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: (outOfStock || busy) ? null : onRedeem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          outOfStock ? Colors.grey.shade300 : AppColors.primary,
                      foregroundColor:
                          outOfStock ? AppColors.textMedium : Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(outOfStock ? 'Out of Stock' : 'Redeem',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderHero(BrandStyle style) {
    return Container(
      color: style.color.withOpacity(0.18),
      alignment: Alignment.center,
      child: Text(style.emoji, style: const TextStyle(fontSize: 40)),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.brandName});
  final String brandName;

  @override
  Widget build(BuildContext context) {
    final style = brandStyleFor(brandName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4),
        ],
      ),
      child: Text(brandName,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: style.color)),
    );
  }
}

// ── Redemption confirmation dialog ─────────────────────────────────────
class _RedeemDialogResult {
  final String email;
  const _RedeemDialogResult(this.email);
}

class _RedeemConfirmationDialog extends StatefulWidget {
  const _RedeemConfirmationDialog({
    required this.reward,
    required this.currentPoints,
    this.prefillEmail,
  });

  final RewardModel reward;
  final int currentPoints;
  final String? prefillEmail;

  @override
  State<_RedeemConfirmationDialog> createState() =>
      _RedeemConfirmationDialogState();
}

class _RedeemConfirmationDialogState
    extends State<_RedeemConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;

  static final _emailRegex =
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    return AlertDialog(
      title: Text('Redeem ${reward.name}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Brand', reward.brandName),
              _row('Voucher Value', 'RM${reward.voucherValue}'),
              _row('Cost', '${reward.pointsRequired} points'),
              _row('Your Points', '${widget.currentPoints}'),
              _row('Available', '${reward.stock}'),
              const SizedBox(height: 14),
              const Text('Delivery Email',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'user@example.com',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Email is required';
                  if (!_emailRegex.hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'This is a demo — no real voucher code is issued. Your '
                'e-voucher will show as "Pending Delivery" after redemption.',
                style: TextStyle(fontSize: 11, color: AppColors.textMedium),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
                context, _RedeemDialogResult(_email.text.trim()));
          },
          child: const Text('Confirm Redemption'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMedium, fontSize: 12)),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );
}

// ── Success dialog ───────────────────────────────────────────────────────
class _RedeemSuccessDialog extends StatelessWidget {
  const _RedeemSuccessDialog({
    required this.reward,
    required this.email,
    required this.redemptionId,
  });

  final RewardModel reward;
  final String email;
  final String redemptionId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          const Text('Redemption Successful',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Your ${reward.brandName} ${reward.name} has been reserved.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMedium),
          ),
          const SizedBox(height: 16),
          _detailRow('Delivery email', email),
          _detailRow('Expected delivery', 'Within 2–3 working days'),
          _detailRow('Status', 'Pending Delivery'),
          _detailRow('Redemption ID',
              redemptionId.length > 8
                  ? redemptionId.substring(0, 8).toUpperCase()
                  : redemptionId.toUpperCase()),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMedium, fontSize: 11)),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      );
}
