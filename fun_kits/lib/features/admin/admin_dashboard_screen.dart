import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../app/routes.dart';
import '../../core/services/auth_service.dart';
import 'package:provider/provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Admin Dashboard 🛠',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.textDark,
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
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage your exhibition',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('Create & control games, draws, and exhibitors.',
                style: TextStyle(color: AppColors.textMedium)),
            const SizedBox(height: 28),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _AdminCard(
                    icon: Icons.quiz_rounded,
                    title: 'Manage Quizzes',
                    subtitle: 'Add/edit questions',
                    color: AppColors.quizColor,
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.manageQuiz),
                  ),
                  _AdminCard(
                    icon: Icons.casino_rounded,
                    title: 'Lucky Draws',
                    subtitle: 'Create & run draws',
                    color: AppColors.luckyDrawColor,
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.manageLuckyDraw),
                  ),
                  _AdminCard(
                    icon: Icons.store_rounded,
                    title: 'Exhibitors',
                    subtitle: 'Add booth profiles',
                    color: AppColors.exhibitorColor,
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.manageExhibitors),
                  ),
                  _AdminCard(
                    icon: Icons.leaderboard_rounded,
                    title: 'Leaderboard',
                    subtitle: 'View rankings',
                    color: AppColors.leaderboardColor,
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.leaderboard),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
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
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
