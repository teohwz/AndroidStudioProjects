import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reward_model.dart';
import '../../core/models/redemption_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../app/routes.dart';
import 'manage_rewards_screen.dart';

/// The Super Admin's home screen — a distinct, higher-privilege dashboard
/// from the existing organizer AdminDashboardScreen (Quiz/Lucky Draw/
/// Exhibitors), reached only when AuthService.isSuperAdmin is true (see
/// app.dart's routing gate).
class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Super Admin 👑',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              if (v == 'logout') {
                // Super Admin logout is now "sticky" too, symmetric with
                // Exhibitor — AuthService.logout() persists this so a
                // relaunch also lands back on Login, not a silent guest
                // session (see AuthService's lastKnownMode).
                await context.read<AuthService>().logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.getAllUsersAdmin(),
        builder: (context, usersSnap) {
          final users = usersSnap.data ?? [];

          return StreamBuilder<List<RewardModel>>(
            stream: fs.getAllRewardsAdmin(),
            builder: (context, rewardsSnap) {
              final rewards = rewardsSnap.data ?? [];

              return StreamBuilder<int>(
                stream: fs.getLowStockThreshold(),
                builder: (context, thresholdSnap) {
                  final threshold = thresholdSnap.data ??
                      FirestoreService.defaultLowStockThreshold;

                  return StreamBuilder<List<RedemptionModel>>(
                    stream: fs.getAllRedemptions(),
                    builder: (context, redemptionsSnap) {
                      final redemptions = redemptionsSnap.data ?? [];

                      final activeRewards =
                          rewards.where((r) => r.isActive).length;
                      final lowStock = rewards
                          .where((r) =>
                              r.isActive &&
                              r.stockLevel(threshold) == StockLevel.low)
                          .length;
                      final outOfStock = rewards
                          .where((r) =>
                              r.isActive &&
                              r.stockLevel(threshold) ==
                                  StockLevel.outOfStock)
                          .length;
                      final pendingDeliveries = redemptions
                          .where((r) =>
                              r.status == RedemptionStatus.pendingDelivery)
                          .length;
                      final totalPointsRedeemed = redemptions
                          .where((r) => r.status != RedemptionStatus.refunded)
                          .fold<int>(0, (sum, r) => sum + r.pointsSpent);

                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text('Overview',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.5,
                            children: [
                              _StatTile(
                                  label: 'Total Users',
                                  value: '${users.length}',
                                  emoji: '👥',
                                  color: AppColors.primary),
                              _StatTile(
                                  label: 'Total Rewards',
                                  value: '${rewards.length}',
                                  emoji: '🎁',
                                  color: AppColors.exhibitorColor),
                              _StatTile(
                                  label: 'Active Rewards',
                                  value: '$activeRewards',
                                  emoji: '✅',
                                  color: AppColors.success),
                              _StatTile(
                                  label: 'Total Redemptions',
                                  value: '${redemptions.length}',
                                  emoji: '🧾',
                                  color: AppColors.quizColor),
                              _StatTile(
                                  label: 'Pending Deliveries',
                                  value: '$pendingDeliveries',
                                  emoji: '📦',
                                  color: AppColors.warning),
                              _StatTile(
                                  label: 'Points Redeemed',
                                  value: '$totalPointsRedeemed',
                                  emoji: '💰',
                                  color: AppColors.leaderboardColor,
                                  dark: true),
                              _StatTile(
                                  label: 'Low Stock',
                                  value: '$lowStock',
                                  emoji: '⚠️',
                                  color: AppColors.warning),
                              _StatTile(
                                  label: 'Out of Stock',
                                  value: '$outOfStock',
                                  emoji: '🚫',
                                  color: AppColors.danger),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text('Quick Actions',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          _QuickAction(
                            icon: Icons.add_box_rounded,
                            label: 'Add Reward',
                            color: AppColors.success,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ManageRewardsScreen(
                                      openCreateOnLoad: true)),
                            ),
                          ),
                          _QuickAction(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Manage Rewards',
                            color: AppColors.primary,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.manageRewards),
                          ),
                          _QuickAction(
                            icon: Icons.inventory_2_rounded,
                            label: 'Manage Inventory',
                            color: AppColors.exhibitorColor,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.manageInventory),
                          ),
                          _QuickAction(
                            icon: Icons.receipt_long_rounded,
                            label: 'View Redemptions',
                            color: AppColors.quizColor,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.manageRedemptions),
                          ),
                          _QuickAction(
                            icon: Icons.people_alt_rounded,
                            label: 'Manage Users',
                            color: AppColors.luckyDrawColor,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.manageUsers),
                          ),
                          _QuickAction(
                            icon: Icons.store_rounded,
                            label: 'Manage Booths',
                            color: AppColors.exhibitorColor,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.manageBooths),
                          ),
                        ],
                      );
                    },
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
    this.dark = false,
  });

  final String label;
  final String value;
  final String emoji;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.85))),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
