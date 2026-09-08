import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../admin/manage_lucky_draw_screen.dart';
import '../admin/manage_quiz_screen.dart';
import '../auth/role_choice_screen.dart';
import 'exhibitor_analytics_screen.dart';
import 'exhibitor_booth_editor_screen.dart';
import 'exhibitor_game_config_screen.dart';
import 'exhibitor_prize_wins_screen.dart';
import 'exhibitor_qr_screen.dart';

/// Hub screen for an exhibitor's own booth. Everything reachable from here
/// is scoped to `AuthService.myBoothId` — there is no way to open another
/// exhibitor's booth from this UI, and firestore.rules refuses it server-side
/// regardless (see ExhibitorGuard in routes.dart for the route-level guard).
class ExhibitorDashboardScreen extends StatelessWidget {
  const ExhibitorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final boothId = auth.myBoothId;
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Booth 🏪',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.exhibitorColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              if (v == 'logout') {
                await context.read<AuthService>().logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                }
              } else if (v == 'switch_role') {
                // An exhibitor switching roles can only be switching TO
                // Visitor — hide the Exhibitor card on the screen they
                // land on (see RoleChoiceScreen.hideRole). The actual
                // logout-and-confirm happens when they tap the Visitor
                // card there, not here.
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const RoleChoiceScreen(hideRole: 'exhibitor')));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'switch_role', child: Text('Switch Role')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: boothId == null || boothId.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No booth is linked to this account yet. Contact the '
                  'event organiser.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMedium),
                ),
              ),
            )
          : StreamBuilder<ExhibitorModel?>(
              stream: fs.watchExhibitor(boothId),
              builder: (context, snap) {
                final booth = snap.data;
                return RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        booth?.name.isNotEmpty == true
                            ? booth!.name
                            : 'Set up your booth',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      Text('Booth #${booth?.boothNumber ?? '—'}',
                          style:
                              const TextStyle(color: AppColors.textMedium)),
                      const SizedBox(height: 20),
                      _StatsRow(fs: fs, boothId: boothId),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          _DashCard(
                            icon: Icons.palette_rounded,
                            title: 'Customize Booth',
                            subtitle: 'Name, logo, colors, message',
                            color: AppColors.primary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExhibitorBoothEditorScreen(
                                    boothId: boothId),
                              ),
                            ),
                          ),
                          _DashCard(
                            icon: Icons.videogame_asset_rounded,
                            title: 'Game Settings',
                            subtitle: 'Enable games & set points',
                            color: AppColors.puzzleColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExhibitorGameConfigScreen(
                                    boothId: boothId),
                              ),
                            ),
                          ),
                          _DashCard(
                            icon: Icons.quiz_rounded,
                            title: 'My Quizzes',
                            subtitle: 'Create & edit quizzes',
                            color: AppColors.quizColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ManageQuizScreen(boothId: boothId),
                              ),
                            ),
                          ),
                          _DashCard(
                            icon: Icons.casino_rounded,
                            title: 'My Lucky Draws',
                            subtitle: 'Create & run draws',
                            color: AppColors.luckyDrawColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ManageLuckyDrawScreen(boothId: boothId),
                              ),
                            ),
                          ),
                          _DashCard(
                            icon: Icons.bar_chart_rounded,
                            title: 'Analytics',
                            subtitle: 'Participants, popularity & trends',
                            color: AppColors.accent,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExhibitorAnalyticsScreen(boothId: boothId),
                              ),
                            ),
                          ),
                          _DashCard(
                            icon: Icons.qr_code_2_rounded,
                            title: 'My QR Code',
                            subtitle: 'View, style, save & print',
                            color: AppColors.success,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExhibitorQrScreen(boothId: boothId),
                              ),
                            ),
                          ),
                          _DashCard(
                            icon: Icons.card_giftcard_rounded,
                            title: 'Prize Wins',
                            subtitle: 'Hand-out checklist',
                            color: AppColors.spinWheelColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExhibitorPrizeWinsScreen(boothId: boothId),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.fs, required this.boothId});
  final FirestoreService fs;
  final String boothId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: fs.getBoothStats(boothId),
      builder: (context, snap) {
        final stats = snap.data ?? const {};
        return Row(
          children: [
            _StatTile(
                label: 'Check-ins',
                value: stats['checkIns'] ?? 0,
                color: AppColors.success),
            const SizedBox(width: 10),
            _StatTile(
                label: 'Plays',
                value: stats['totalPlays'] ?? 0,
                color: AppColors.primary),
            const SizedBox(width: 10),
            _StatTile(
                label: 'Points Given',
                value: stats['pointsDistributed'] ?? 0,
                color: AppColors.accent),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMedium)),
          ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: color, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
