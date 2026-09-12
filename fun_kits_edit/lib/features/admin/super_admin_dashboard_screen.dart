import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/reward_model.dart';
import '../../core/models/redemption_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';
import '../../app/routes.dart';
import '../../shared/widgets/dashboard_tab_bar.dart';
import '../../shared/widgets/dense_menu_row.dart';
import 'manage_rewards_screen.dart';

/// The Super Admin's home screen — a distinct, higher-privilege dashboard
/// from the existing organizer AdminDashboardScreen (Quiz/Lucky Draw/
/// Exhibitors), reached only when AuthService.isSuperAdmin is true (see
/// app.dart's routing gate).
///
/// Laid out the same "quiet style" bottom tab bar as the Exhibitor
/// Dashboard — 4 icons, only 2 of which are real persistent tabs (Overview
/// and Commerce) that swap this screen's body content in place; the other
/// 2 (Users, Booths) are shortcut icons that just push their existing
/// standalone screens unchanged. See [DashboardTabItem.isRealTab].
class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState
    extends State<SuperAdminDashboardScreen> {
  // Only 2 of the bar's 4 icons are real tabs (index 0 = Overview, 3 =
  // Commerce) — this index only ever holds 0 or 3, since Users/Booths (1/2)
  // push a screen instead of changing which body is shown.
  int _tabIndex = 0;

  void _onNavTap(int index) {
    switch (index) {
      case 0:
      case 3:
        setState(() => _tabIndex = index);
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.manageUsers);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.manageBooths);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_tabIndex == 0)
              const _OverviewHeader()
            else
              const _PlainHeader(
                title: 'Commerce',
                subtitle: 'Rewards, stock and redemptions',
              ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex == 0 ? 0 : 1,
                children: const [
                  _OverviewBody(),
                  _CommerceBody(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DashboardTabBar(
        currentIndex: _tabIndex,
        items: const [
          DashboardTabItem(icon: Icons.grid_view_rounded),
          DashboardTabItem(icon: Icons.groups_rounded, isRealTab: false),
          DashboardTabItem(icon: Icons.store_rounded, isRealTab: false),
          DashboardTabItem(icon: Icons.receipt_long_rounded),
        ],
        onTap: _onNavTap,
      ),
    );
  }
}

/// Plain white header shared by every non-Overview tab — just a title and
/// subtitle, no account menu (the 3-dot menu lives only on Overview, same
/// convention as the Exhibitor Dashboard).
class _PlainHeader extends StatelessWidget {
  const _PlainHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: palette.textDark)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 11.5, color: palette.textMedium)),
        ],
      ),
    );
  }
}

/// Overview's header — fixed "Super Admin" title, plus the account menu
/// (Logout only — Super Admin has no "Switch Role"), restyled from the old
/// dark AppBar into the same plain white header row used everywhere else in
/// this redesign.
class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Super Admin',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.textDark)),
                const SizedBox(height: 2),
                Text('Manage users, booths & commerce',
                    style:
                        TextStyle(fontSize: 11.5, color: palette.textMedium)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: palette.textMedium),
            onSelected: (v) async {
              if (v == 'logout') {
                // Super Admin logout is "sticky" — AuthService.logout()
                // persists this so a relaunch also lands back on Login, not
                // a silent guest session (see AuthService's lastKnownMode).
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
    );
  }
}

/// Overview tab body — the same 8 stats as before, just restyled quieter
/// and wrapped across two dense rows of 4 instead of a bordered 2-column
/// card grid.
class _OverviewBody extends StatelessWidget {
  const _OverviewBody();

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return StreamBuilder<List<Map<String, dynamic>>>(
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
                            r.stockLevel(threshold) == StockLevel.outOfStock)
                        .length;
                    final pendingDeliveries = redemptions
                        .where((r) =>
                            r.status == RedemptionStatus.pendingDelivery)
                        .length;
                    final totalPointsRedeemed = redemptions
                        .where((r) => r.status != RedemptionStatus.refunded)
                        .fold<int>(0, (sum, r) => sum + r.pointsSpent);

                    return RefreshIndicator(
                      onRefresh: () async {},
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Row(
                            children: [
                              _StatTile(
                                  label: 'Total Users',
                                  value: '${users.length}',
                                  icon: Icons.groups_rounded,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              _StatTile(
                                  label: 'Total Rewards',
                                  value: '${rewards.length}',
                                  icon: Icons.card_giftcard_rounded,
                                  color: palette.exhibitorColor),
                              const SizedBox(width: 8),
                              _StatTile(
                                  label: 'Active Rewards',
                                  value: '$activeRewards',
                                  icon: Icons.check_circle_rounded,
                                  color: palette.success),
                              const SizedBox(width: 8),
                              _StatTile(
                                  label: 'Total Redemptions',
                                  value: '${redemptions.length}',
                                  icon: Icons.receipt_long_rounded,
                                  color: palette.quizColor),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _StatTile(
                                  label: 'Pending Deliveries',
                                  value: '$pendingDeliveries',
                                  icon: Icons.local_shipping_rounded,
                                  color: palette.warning),
                              const SizedBox(width: 8),
                              _StatTile(
                                  label: 'Points Redeemed',
                                  value: '$totalPointsRedeemed',
                                  icon: Icons.paid_rounded,
                                  color: palette.gold),
                              const SizedBox(width: 8),
                              _StatTile(
                                  label: 'Low Stock',
                                  value: '$lowStock',
                                  icon: Icons.warning_amber_rounded,
                                  color: palette.warning),
                              const SizedBox(width: 8),
                              _StatTile(
                                  label: 'Out of Stock',
                                  value: '$outOfStock',
                                  icon: Icons.remove_shopping_cart_rounded,
                                  color: palette.danger),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Commerce tab body — the 3 back-office screens as a dense list. "Manage
/// Rewards" carries an extra "+" tap-target that jumps straight to Add
/// Reward, while the rest of the row opens the full rewards list.
class _CommerceBody extends StatelessWidget {
  const _CommerceBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        DenseMenuRow(
          icon: Icons.card_giftcard_rounded,
          title: 'Manage Rewards',
          subtitle: 'Catalogue, pricing, active status',
          color: theme.colorScheme.primary,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.manageRewards),
          trailing: IconButton(
            icon: Icon(Icons.add_rounded,
                size: 18, color: theme.colorScheme.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: 'Add Reward',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      const ManageRewardsScreen(openCreateOnLoad: true)),
            ),
          ),
        ),
        DenseMenuRow(
          icon: Icons.inventory_2_rounded,
          title: 'Manage Inventory',
          subtitle: 'Stock levels, low-stock alerts',
          color: palette.exhibitorColor,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.manageInventory),
        ),
        DenseMenuRow(
          icon: Icons.receipt_long_rounded,
          title: 'Manage Redemptions',
          subtitle: 'Pending deliveries, refunds',
          color: palette.quizColor,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.manageRedemptions),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 1),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 9, color: palette.textMedium)),
          ],
        ),
      ),
    );
  }
}
