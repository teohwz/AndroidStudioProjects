import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/redemption_model.dart';
import '../../core/services/firestore_service.dart';

/// A visitor's own past redemptions — reachable from the Shop's app bar.
class RedemptionHistoryScreen extends StatelessWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Redemptions 🧾',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<RedemptionModel>>(
              stream: fs.getUserRedemptions(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final redemptions = snap.data ?? [];
                if (redemptions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🧾', style: TextStyle(fontSize: 56)),
                          SizedBox(height: 12),
                          Text("You haven't redeemed anything yet.",
                              style: TextStyle(color: AppColors.textMedium)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: redemptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RedemptionCard(r: redemptions[i]),
                );
              },
            ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({required this.r});
  final RedemptionModel r;

  Color get _statusColor {
    switch (r.status) {
      case RedemptionStatus.delivered:
        return AppColors.success;
      case RedemptionStatus.processing:
        return AppColors.warning;
      case RedemptionStatus.cancelled:
      case RedemptionStatus.refunded:
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.rewardName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(r.statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${r.brandName} · RM${r.voucherValue} · ${r.pointsSpent} pts',
              style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
          const SizedBox(height: 4),
          Text('To: ${r.deliveryEmail}',
              style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
          if (r.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '${r.createdAt!.day}/${r.createdAt!.month}/${r.createdAt!.year}',
              style: const TextStyle(color: AppColors.textMedium, fontSize: 11),
            ),
          ],
          const SizedBox(height: 4),
          Text('ID: ${r.id.length > 8 ? r.id.substring(0, 8).toUpperCase() : r.id.toUpperCase()}',
              style: const TextStyle(color: AppColors.textMedium, fontSize: 10)),
        ],
      ),
    );
  }
}
